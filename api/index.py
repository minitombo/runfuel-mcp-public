"""RunFuel MCP: authenticated, read-only Garmin + MyFitnessPal MCP gateway.

This reuses the published upstream tools and deliberately registers only
read-only MyFitnessPal operations. It is configured for stateless HTTP because
Vercel functions may not retain process/session state between requests.
"""
from __future__ import annotations

import asyncio
import functools
import hmac
import inspect
import os
import re
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# Vercel's function filesystem is read-only outside /tmp. The upstream Garmin
# and MyFitnessPal clients use platformdirs for token/config/cache files, so
# redirect their writable locations before importing either package.
os.environ["HOME"] = "/tmp"
os.environ["XDG_CONFIG_HOME"] = "/tmp/.config"
os.environ["XDG_DATA_HOME"] = "/tmp/.local/share"
os.environ["XDG_CACHE_HOME"] = "/tmp/.cache"
os.environ.setdefault("MFP_MCP_DATA_DIR", "/tmp/runfuel-mfp")
Path("/tmp/.config").mkdir(parents=True, exist_ok=True)
Path("/tmp/.local/share").mkdir(parents=True, exist_ok=True)
Path("/tmp/.cache").mkdir(parents=True, exist_ok=True)
Path(os.environ["MFP_MCP_DATA_DIR"]).mkdir(parents=True, exist_ok=True)
from contextlib import asynccontextmanager

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from api import oauth_auth, token_manager
from api.nutrition_metrics import fitness_get_nutrition_details
from api.mfp_compat import mfp_get_goals, mfp_get_measurements
from api.mfp_diagnostics import fitness_check_connection
from api.garmin_metrics import garmin_get_running_summary
from api.garmin_track import READ_ONLY as TRACK_READ_ONLY, garmin_get_activity_track
from mcp.types import ToolAnnotations
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Mount, Route
from starlette.types import ASGIApp, Receive, Scope, Send

from garmin_personal_mcp import server as garmin_server
from myfitnesspal_mcp import server as mfp_server, mfp_client

GARMIN_READ_TOOLS = (
    "garmin_get_day", "garmin_get_daily_summary", "garmin_get_daily_summaries",
    "garmin_get_steps", "garmin_get_stress", "garmin_get_hydration",
    "garmin_get_body_battery", "garmin_get_heart_rate", "garmin_get_spo2",
    "garmin_get_wellness_activities", "garmin_get_sleep", "garmin_get_sleep_summaries",
    "garmin_get_hrv", "garmin_get_hrv_summaries", "garmin_get_weight",
    "garmin_get_weight_goals", "garmin_get_food_log", "garmin_search_activities",
    "garmin_get_activity", "garmin_get_activity_workouts",
    "garmin_get_heart_rate_zones", "garmin_get_fitness_age",
    "garmin_get_menstrual_cycle", "garmin_get_menstrual_day",
)
MFP_READ_TOOLS = (
    "fitness_get_day", "fitness_search_food", "fitness_get_note", "fitness_get_trends",
    "fitness_bulk_export", "fitness_list_food_pins",
)
BLOCKED_MFP_TOOLS = (
    "fitness_draft_food", "fitness_log_food", "fitness_delete_food",
    "fitness_modify_food", "fitness_log_weight", "fitness_log_water",
    "fitness_delete_exercise", "fitness_log_note", "fitness_log_feel",
    "fitness_clear_food_pin",
)
READ_ONLY = ToolAnnotations(readOnlyHint=True, destructiveHint=False, openWorldHint=True)

# Apply the same recursive privacy boundary to every exposed Garmin response.
# The name is retained for compatibility with existing regression tests.
PRIVACY_FILTERED_GARMIN_TOOLS = frozenset(GARMIN_READ_TOOLS)

_PRIVATE_EXACT_KEYS = frozenset({
    "owner", "ownerinfo", "ownerprofile", "ownerfullname",
    "ownerdisplayname", "ownerid", "owneravatar", "owneravatarurl",
    "ownerimage", "ownerimageurl", "ownerprofileimage",
    "ownerprofileimageurl", "ownerprofilepicture", "ownerprofilepictureurl",
    "ownerprofilephoto", "ownerprofilephotourl", "profile", "profileimage",
    "profileimageurl", "profilepicture", "profilepictureurl",
    "profilephoto", "profilephotourl", "avatar", "avatarurl",
    "userprofile", "userprofileid", "userinfodto", "displayname", "fullname",
    "userdailysummaryid", "userid", "accountid", "deviceid", "username",
    "email", "emailaddress", "firstname", "lastname", "profileid",
    "useravatar", "useravatarurl", "userimage", "userimageurl",
    "userphoto", "userphotourl", "profileurl",
})


def _is_private_activity_metadata_key(key: object) -> bool:
    """Recognize owner identifiers and profile/avatar image fields by key."""
    normalized = re.sub(r"[^a-z0-9]", "", str(key).casefold())
    if normalized in _PRIVATE_EXACT_KEYS:
        return True
    # Garmin detail payloads use these variants instead of owner* fields.
    # IDs tied to an account/profile/device are not required for coaching.
    # Preserve activityId, foodId, and other domain-specific record identifiers.
    if (normalized.startswith("user") and normalized.endswith("id")) or (
        normalized.startswith("account") and normalized.endswith("id")
    ):
        return True
    if normalized.startswith("device") and normalized.endswith("id"):
        return True
    if normalized.startswith("userprofile") or normalized in {"displayname", "fullname"}:
        return True
    if "owner" in normalized and any(
        part in normalized for part in ("name", "id", "avatar", "image", "photo", "picture", "profile")
    ):
        return True
    if "profile" in normalized and any(
        part in normalized for part in ("image", "avatar", "photo", "picture", "url")
    ):
        return True
    return False


def _sanitize_activity_payload(value):
    """Recursively remove Garmin account-owner and profile-image metadata."""
    if isinstance(value, dict):
        return {
            key: _sanitize_activity_payload(item)
            for key, item in value.items()
            if not _is_private_activity_metadata_key(key)
        }
    if isinstance(value, list):
        return [_sanitize_activity_payload(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_sanitize_activity_payload(item) for item in value)
    return value


def _privacy_filtered_tool(fn):
    """Wrap an upstream activity tool without changing its exposed signature."""
    @functools.wraps(fn)
    async def wrapper(*args, **kwargs):
        result = fn(*args, **kwargs)
        if inspect.isawaitable(result):
            result = await result
        return _sanitize_activity_payload(result)
    return wrapper

# Derive the allowed host from the canonical deployment URL. This supports
# self-hosters while retaining FastMCP's DNS-rebinding protection.
_BASE_HOST = urlparse(oauth_auth.BASE_URL).hostname
if not _BASE_HOST:
    raise RuntimeError("RUNFUEL_BASE_URL must contain a valid hostname")
mcp = FastMCP(
    "runfuel",
    stateless_http=True,
    transport_security=TransportSecuritySettings(
        allowed_hosts=[_BASE_HOST, f"{_BASE_HOST}:*"],
    ),
)


def register_upstream_tools() -> None:
    """Register the explicitly allowlisted functions with read-only annotations."""
    for name in GARMIN_READ_TOOLS:
        fn = getattr(garmin_server, name, None)
        if fn is None:
            raise RuntimeError(f"Expected Garmin upstream tool is missing: {name}")
        fn = _privacy_filtered_tool(fn)
        mcp.add_tool(fn, name=name, annotations=READ_ONLY)
    for name in MFP_READ_TOOLS:
        fn = getattr(mfp_server, name, None)
        if fn is None:
            raise RuntimeError(f"Expected MyFitnessPal upstream tool is missing: {name}")
        fn = _privacy_filtered_tool(fn)
        mcp.add_tool(fn, name=name, annotations=READ_ONLY)


register_upstream_tools()
mcp.add_tool(
    _privacy_filtered_tool(fitness_check_connection),
    name="fitness_check_connection",
    annotations=READ_ONLY,
)
mcp.add_tool(
    _privacy_filtered_tool(fitness_get_nutrition_details),
    name="fitness_get_nutrition_details",
    annotations=READ_ONLY,
)
mcp.add_tool(
    _privacy_filtered_tool(garmin_get_running_summary),
    name="garmin_get_running_summary",
    annotations=READ_ONLY,
)
mcp.add_tool(
    _privacy_filtered_tool(garmin_get_activity_track),
    name="garmin_get_activity_track",
    annotations=TRACK_READ_ONLY,
)

# Familiar aliases for common read-only MyFitnessPal actions. These reuse the
# same upstream client/session and do not add any write-capable functions.
mcp.add_tool(_privacy_filtered_tool(mfp_server.fitness_get_day), name="mfp_get_diary", annotations=READ_ONLY)
mcp.add_tool(_privacy_filtered_tool(mfp_server.fitness_search_food), name="mfp_search_food", annotations=READ_ONLY)
mcp.add_tool(_privacy_filtered_tool(mfp_server.fitness_bulk_export), name="mfp_get_report", annotations=READ_ONLY)
mcp.add_tool(_privacy_filtered_tool(mfp_get_goals), name="mfp_get_goals", annotations=READ_ONLY)
mcp.add_tool(_privacy_filtered_tool(mfp_get_measurements), name="mfp_get_measurements", annotations=READ_ONLY)


async def apply_managed_credentials() -> None:
    """Load encrypted credentials per request; never persist them to local disk."""
    for name in token_manager.SECRET_NAMES:
        try:
            value = await token_manager.get_credential(name)
        except Exception:
            # Preserve env-based operation if managed storage is unavailable.
            value = os.environ.get(name)
        if value:
            os.environ[name] = value
        else:
            os.environ.pop(name, None)
    # The upstream client caches credentials; force it to reload the new cookie.
    mfp_client.reset()


def authorized(headers: list[tuple[bytes, bytes]], expected_token: str | None) -> bool:
    """Constant-time bearer-token comparison; missing configuration fails closed."""
    if not expected_token:
        return False
    header_value = next(
        (value.decode("latin-1") for key, value in headers if key.lower() == b"authorization"),
        "",
    )
    scheme, _, supplied = header_value.partition(" ")
    return scheme.lower() == "bearer" and bool(supplied) and hmac.compare_digest(supplied, expected_token)


async def health(_: Request) -> JSONResponse:
    return JSONResponse({"ok": True, "service": "runfuel-mcp"})


mcp_asgi = mcp.streamable_http_app()


class BearerAuth:
    """ASGI wrapper protecting all MCP protocol requests."""
    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        self._credential_lock = asyncio.Lock()

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        original_path = scope.get("path", "")
        query = parse_qs(scope.get("query_string", b"").decode("latin-1"))
        requested_path = query.get("__runfuel_path", [original_path])[0]
        path = "/health" if requested_path.endswith("/health") else (
            "/mcp" if requested_path.endswith("/mcp") else requested_path
        )
        normalized_scope = dict(scope)
        normalized_scope["path"] = path
        if path != "/mcp":
            await self.app(normalized_scope, receive, send)
            return

        headers = scope.get("headers", [])
        header_value = next(
            (value.decode("latin-1") for key, value in headers if key.lower() == b"authorization"),
            "",
        )
        scheme, _, supplied = header_value.partition(" ")
        oauth_configured = bool(
            os.environ.get("UPSTASH_REDIS_REST_URL") and os.environ.get("UPSTASH_REDIS_REST_TOKEN")
        )
        oauth_valid = False
        if scheme.lower() == "bearer" and supplied and oauth_configured:
            try:
                oauth_valid = await oauth_auth.validate_access_token(supplied)
            except Exception:
                oauth_valid = False
        legacy_valid = authorized(headers, os.environ.get("RUNFUEL_ACCESS_TOKEN"))
        if not (oauth_valid or legacy_valid) and scheme.lower() == "bearer" and supplied:
            # A managed legacy token is stored encrypted in Redis, not in source/env.
            try:
                managed_legacy = await token_manager.get_credential("RUNFUEL_ACCESS_TOKEN")
                legacy_valid = authorized(headers, managed_legacy)
            except Exception:
                legacy_valid = False
        if not (oauth_valid or legacy_valid):
            metadata_url = f"{oauth_auth.BASE_URL}/.well-known/oauth-protected-resource"
            response = JSONResponse(
                {"error": "Unauthorized"}, status_code=401,
                headers={"WWW-Authenticate": f'Bearer resource_metadata="{metadata_url}"'},
            )
            await response(scope, receive, send)
            return
        # Avoid two simultaneous requests swapping process-wide credentials mid-call.
        async with self._credential_lock:
            await apply_managed_credentials()
            await self.app(normalized_scope, receive, send)


async def not_found(_: Request) -> JSONResponse:
    return JSONResponse({"error": "Not found"}, status_code=404)


from starlette.applications import Starlette


@asynccontextmanager
async def mcp_lifespan(_app: Starlette):
    """Start the MCP Streamable HTTP session manager for the app lifetime."""
    async with mcp.session_manager.run():
        yield


inner_app = Starlette(
    lifespan=mcp_lifespan,
    routes=[
        Route("/health", health, methods=["GET"]),
        Route("/settings", token_manager.settings_page, methods=["GET"]),
        Route("/settings", token_manager.save_settings, methods=["POST"]),
        Route("/.well-known/oauth-authorization-server", oauth_auth.metadata, methods=["GET"]),
        Route("/.well-known/oauth-protected-resource", oauth_auth.protected_resource, methods=["GET"]),
        Route("/.well-known/oauth-protected-resource/mcp", oauth_auth.protected_resource, methods=["GET"]),
        Route("/register", oauth_auth.register, methods=["POST"]),
        Route("/authorize", oauth_auth.authorize, methods=["GET"]),
        Route("/login", oauth_auth.login, methods=["POST"]),
        Route("/token", oauth_auth.token, methods=["POST"]),
        Mount("/", app=mcp_asgi),
        Route("/{path:path}", not_found, methods=["GET", "POST", "PUT", "PATCH", "DELETE"]),
    ],
)
app = BearerAuth(inner_app)
