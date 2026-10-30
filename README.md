# RunFuel MCP

**One self-hosted Model Context Protocol (MCP) server for selected Garmin and MyFitnessPal read-only data.** Connect an MCP client such as Claude to your own RunFuel deployment instead of configuring two separate integrations.

> **Self-hosting only:** RunFuel handles fitness, nutrition, account credentials, and potentially precise GPS data. Deploy your own copy and use your own accounts, Vercel project, and Upstash Redis database. Do not use or connect a fork to somebody else's credentials or database.

## Features

- Combines selected Garmin and MyFitnessPal tools behind one authenticated MCP endpoint.
- Uses OAuth for MCP clients that support remote MCP OAuth.
- Uses Upstash Redis for OAuth state/tokens, rate limiting, and encrypted managed credentials.
- Includes a mobile-friendly `/settings` page for securely storing or updating upstream credentials.
- Keeps MyFitnessPal diary access read-only; diary write, edit, and delete tools are not exposed.
- Uses Garmin as the source of truth for activity and step data; MyFitnessPal exercise tools are excluded.
- Removes unnecessary identity fields from tool responses while preserving useful training metrics. GPS track data is deliberately retained for route and run analysis.

## Start here

- **[Self-hosting guide](docs/SELF_HOSTING.md)** — step-by-step setup for GitHub, Vercel, Upstash Redis, credentials, and Claude.
- [Privacy and data minimization](PRIVACY.md)
- [Security policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [MIT License](LICENSE)

## Architecture at a glance

```text
Claude (or another remote MCP client)
              |
        HTTPS + OAuth
              |
     Your Vercel deployment
              |
       RunFuel MCP server
          /         \
       Garmin     MyFitnessPal
              |
       Your Upstash Redis
```

Every operator must supply their own credentials. A fork should never point at the original maintainer's deployment, Redis database, or upstream account sessions.

## Endpoints

Replace `YOUR-DOMAIN` with the stable HTTPS domain of your own deployment:

- MCP endpoint: `https://YOUR-DOMAIN/mcp`
- Health check: `https://YOUR-DOMAIN/health`
- Credential manager: `https://YOUR-DOMAIN/settings`

The health endpoint is a deployment check, not a guarantee that Garmin or MyFitnessPal credentials are valid.

## Security essentials

- Never commit `.env`, API keys, MyFitnessPal cookies, OAuth passwords, Redis tokens, access tokens, or real user data.
- Store deployment secrets in your own Vercel Environment Variables. Keep the repository's `.env.example` placeholders only.
- Treat the MyFitnessPal session cookie as a password; it can grant access to your account.
- Keep `RUNFUEL_OAUTH_PASSWORD` and `UPSTASH_REDIS_REST_TOKEN` stable while managed credentials are stored. The default encryption key is derived from these values. If either changes, you may need to re-enter stored credentials; see the setup guide before rotating them.
- GPS coordinates can reveal sensitive locations. Only connect accounts you own and review [PRIVACY.md](PRIVACY.md).
- RunFuel sanitizes known identity fields, but key-based filtering cannot guarantee anonymity if upstream APIs change. Review responses and dependencies after updates.

## Upstream projects and attribution

RunFuel builds on the following projects by **Mason-Levyy**:

- [Garmin Personal MCP](https://github.com/Mason-Levyy/garmin-personal-mcp)
- [MyFitnessPal MCP](https://github.com/Mason-Levyy/myfitnesspal-mcp)

Thanks to Mason-Levyy for the upstream work. RunFuel is a separate integration project and does not claim authorship of those projects. Preserve their licence notices when redistributing. RunFuel's own contributions are licensed under the MIT License; see [LICENSE](LICENSE).

## Development and tests

Python 3.12 is required by the Garmin dependency. To run the automated tests locally:

```bash
python -m venv .venv
# Activate the virtual environment, then:
pip install -r requirements.txt
python -m unittest discover -s tests -v
```

For deployment setup, required environment variables, MyFitnessPal cookie troubleshooting, and Claude connection steps, follow the [self-hosting guide](docs/SELF_HOSTING.md).
