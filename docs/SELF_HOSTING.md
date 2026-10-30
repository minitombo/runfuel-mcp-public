# Self-hosting RunFuel

This guide is intended for people deploying their own fork. It covers GitHub, Vercel, Upstash Redis, and Claude. Menu names can change slightly as these services update.

## Before you start

You need accounts for:

- [GitHub](https://github.com/) — to fork and own the source repository.
- [Vercel](https://vercel.com/) — to host the server.
- [Upstash](https://upstash.com/) — to provide a dedicated Redis database.
- [Garmin](https://connect.garmin.com/) and [MyFitnessPal](https://www.myfitnesspal.com/) — your own accounts.
- [Claude](https://claude.ai/) or another client that supports remote MCP servers and OAuth.

RunFuel is not a hosted service. Each operator is responsible for their own deployment, credentials, database, access controls, and data.

## 1. Fork the GitHub repository

1. Open the RunFuel repository on GitHub.
2. Select **Fork**, and create the fork under your own GitHub account or organisation.
3. Keep your fork's default branch as `main`, unless you intentionally configure a different production branch.
4. Do not add credentials to repository files, commit messages, issues, pull requests, or screenshots.

When you update your fork later, review upstream changes before merging them. Do not blindly overwrite your own configuration or code.

## 2. Create your Vercel project

1. Sign in to [Vercel](https://vercel.com/).
2. Choose **Add New → Project** (or the current equivalent).
3. Import **your fork**, not another person's fork or deployment.
4. Keep the repository root as the project root. Use the default detected configuration unless you have a specific reason to change it.
5. Deploy once. The first deployment may use Vercel's deployment host for its initial host validation.
6. After a stable production domain is assigned, add `RUNFUEL_BASE_URL` with the exact canonical HTTPS origin you intend to use, for example `https://your-project.vercel.app` (no trailing slash). Redeploy after adding or changing environment variables.

Vercel builds deployments from Git branches. Pushes to the configured production branch generally create production deployments; other branches can create preview deployments. Keep secrets scoped to **Production** unless you intentionally need separate Preview credentials.

Official reference: [Deploying Git repositories with Vercel](https://vercel.com/docs/git).

## 3. Create your own Upstash Redis database

RunFuel needs its own Redis database for OAuth state and token records, rate limiting, and encrypted managed credentials. Do not use the maintainer's database.

1. Open the [Upstash Console](https://console.upstash.com/) or use the Upstash integration from your Vercel dashboard.
2. Create a new **Redis** database for your RunFuel instance. Choose a region suitable for your deployment and your own needs.
3. In the database details, find the REST URL and REST token.
4. Add these to your own Vercel project as environment variables:
   - `UPSTASH_REDIS_REST_URL`
   - `UPSTASH_REDIS_REST_TOKEN`
5. Save the variables and redeploy.

If you use Vercel's Upstash integration, confirm that the variables created by the integration use the exact names RunFuel expects. Never publish the REST token.

Official reference: [Upstash's Vercel integration guide](https://upstash.com/docs/redis/howto/vercelintegration).

## 4. Configure environment variables in Vercel

Open your Vercel project → **Settings → Environment Variables**. Add the variables below using values from your own accounts and services. Select **Production** for the live deployment. Save changes and redeploy.

| Variable | Required? | What it is |
| --- | --- | --- |
| `RUNFUEL_BASE_URL` | Yes for a stable production setup | Canonical HTTPS origin of your own deployment, without a trailing slash |
| `RUNFUEL_OAUTH_PASSWORD` | Yes | Strong, unique server-side password used for RunFuel's OAuth sign-in and Token Manager Basic Auth |
| `UPSTASH_REDIS_REST_URL` | Yes | Your own Upstash Redis REST URL |
| `UPSTASH_REDIS_REST_TOKEN` | Yes | Your own Upstash Redis REST token |
| `GARMIN_PERSONAL_API_KEY` | Yes unless supplied in Token Manager | Your own Garmin Personal API key |
| `MFP_COOKIE` | Yes unless supplied in Token Manager | Your current MyFitnessPal session cookie |
| `MFP_USERNAME` | Strongly recommended | Your MyFitnessPal username, not your email address |
| `MFP_MCP_DATA_DIR` | Optional | Local cache directory; for Vercel use `/tmp/runfuel-mfp` |
| `RUNFUEL_SECRET_ENCRYPTION_KEY` | Optional | Dedicated Fernet key override for stored managed credentials |
| `RUNFUEL_ACCESS_TOKEN` | Optional legacy fallback | Static bearer token for clients that specifically require it; prefer OAuth |

RunFuel normally derives the managed-credential encryption key from `RUNFUEL_OAUTH_PASSWORD` and `UPSTASH_REDIS_REST_TOKEN`; you do not need to generate a separate key. Keep both values stable while encrypted credentials are stored. If either must change, plan to re-enter the managed credentials after the change, or configure and migrate to a dedicated encryption key first.

Do not copy values from another RunFuel installation. Never put secrets in `.env.example`, GitHub, or client-side code.

## 5. Deploy and check the service

1. Confirm that the latest production deployment is **Ready** in Vercel.
2. Open `https://YOUR-DOMAIN/health`. A successful response confirms the health route responds; it does not validate your upstream accounts.
3. Open `https://YOUR-DOMAIN/settings` on your own device.
4. Sign in with username `admin` and the `RUNFUEL_OAUTH_PASSWORD` you configured.
5. Enter or update your own `MFP_COOKIE`, `MFP_USERNAME`, and `GARMIN_PERSONAL_API_KEY`, then select **Save credentials securely**.

The Token Manager stores credentials encrypted in your own Upstash Redis database and does not display saved values. Blank fields leave existing stored values unchanged. OAuth access and refresh tokens used by Claude are managed separately and are not displayed by this page.

## 6. Connect Claude

The exact Claude menu may vary by plan and app version, but the flow is:

1. Open Claude's settings and find **Connectors** (or the custom integrations/MCP section).
2. Add a custom remote MCP connector/server.
3. Enter your own endpoint: `https://YOUR-DOMAIN/mcp`.
4. Save and complete the OAuth sign-in/authorization flow in the browser when prompted. Use your own RunFuel OAuth password.
5. Confirm that Claude shows RunFuel as connected.
6. Test one harmless read-only Garmin tool and one harmless read-only MyFitnessPal tool using your own data.

With OAuth, you do not need to paste a static bearer token into Claude. `RUNFUEL_ACCESS_TOKEN` is a legacy fallback for clients that explicitly require one. Never share your OAuth password, access token, refresh token, or MyFitnessPal cookie.

## 7. MyFitnessPal cookie troubleshooting (phone-friendly)

MyFitnessPal authentication relies on website session behaviour and can change. RunFuel does not promise automatic cookie renewal. Refresh the cookie only when MyFitnessPal requests begin failing with a session/authentication error.

On Android, one documented approach is to use Firefox and the official [Cookie-Editor add-on](https://addons.mozilla.org/en-US/firefox/addon/cookie-editor/):

1. Open MyFitnessPal in Firefox and sign in normally. Complete any verification the site requests.
2. Open Cookie-Editor for the MyFitnessPal tab and look for `__Secure-next-auth.session-token`.
3. Copy the cookie's **value only**.
4. Open your own `/settings` page, sign in as `admin`, paste the value into the MyFitnessPal cookie field, and save.
5. Retry a harmless read-only tool such as `fitness_check_connection` or `fitness_get_day`.

The cookie grants access to your account. Never send it in chat, screenshots, issues, or logs. Do not use tools that attempt to bypass MyFitnessPal verification or anti-bot controls. If the cookie name or sign-in flow has changed, consult the current upstream instructions: [MyFitnessPal MCP](https://github.com/Mason-Levyy/myfitnesspal-mcp).

## 8. Data, privacy, and serverless notes

- RunFuel filters known account-identity fields from exposed tool results, but sanitization is not a guarantee of anonymity. Upstream schemas can change.
- GPS coordinates are preserved when available because they are useful for route and run analysis. Treat GPS and fitness/nutrition data as sensitive.
- MyFitnessPal diary tools exposed by RunFuel are read-only. Exercise tools are intentionally excluded; Garmin is the activity source of truth.
- Vercel's local filesystem is not durable. Some upstream MyFitnessPal cache/session state may disappear between cold starts or separate function instances. RunFuel does not promise automatic cookie renewal.
- Only connect accounts you own or have explicit permission to access. Read [PRIVACY.md](../PRIVACY.md) and [SECURITY.md](../SECURITY.md).

## 9. Updating your fork

1. Review new commits in the original repository and read the changelog/PR descriptions.
2. Bring changes into your fork using GitHub's sync-fork function or a reviewed pull request.
3. Check the Vercel preview deployment and relevant automated tests before merging to your production branch.
4. Review environment-variable changes before redeploying. Do not copy the original maintainer's secrets or database configuration.

## Local tests

Python 3.12 is required by the Garmin dependency.

```bash
python -m venv .venv
# Activate the environment, then:
pip install -r requirements.txt
python -m unittest discover -s tests -v
```
