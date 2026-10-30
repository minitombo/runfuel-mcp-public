# RunFuel data-minimization policy

RunFuel is intended to retain the information needed for useful coaching while avoiding unnecessary personal identity data.

## Keep for coaching and analysis

- Garmin activity records and activity-detail fields returned by Garmin, including GPS coordinates when the source provides them.
- Distance, duration, pace, splits, elevation, heart rate, cadence, timestamps, and other training fields when available from the source.
- Daily wellness, sleep, heart-rate, steps, weight, and nutrition data required for the user's coaching goals.
- Activity identifiers where needed to match or compare the same activity across reads.

GPS coordinates should be **preserved whenever the Garmin source provides them**; RunFuel must not remove them as part of privacy minimisation. They can support route mapping, hill and elevation analysis, turn/segment comparisons, and pace analysis. The upstream `garmin_get_activity` tool itself does not guarantee a GPS track, so RunFuel adds `garmin_get_activity_track`: it retrieves the activity archive and parses FIT records in memory, without exposing the upstream tool that writes files to disk. It returns coordinate points, timestamps, and altitude where present, evenly sampled to a configurable maximum of 2,000 points. If the activity file has no GPS records, the tool reports that instead of inventing a track. Route-level analysis still requires a successful call with actual coordinate points.

## Minimize identity data

- The Garmin profile tool is not exposed through RunFuel's public MCP allowlist.
- Apply recursive key-based sanitization to every exposed Garmin and MyFitnessPal response, including nested objects, lists, derived metrics, diagnostics, aliases, and GPS-track results.
- Remove account/profile/device identifiers (including alternate names such as `userDailySummaryId`), account names, email/name fields, avatar/profile URLs, and owner metadata wherever they appear.
- Preserve activity IDs, food/meal names, dates, nutrition values, training metrics, and GPS coordinates needed for coaching. Sanitization must never remove the `lat`/`lon` GPS points from the dedicated track tool.
- Do not log credentials, session cookies, OAuth tokens, or full raw payloads containing personal data.
- Keep MyFitnessPal exercise entries excluded because Garmin is the exercise source of truth.

## Deployment and data handling

RunFuel is not a hosted multi-user service by default. Each operator should deploy their own copy and connect only their own accounts. Production operators should set an explicit `RUNFUEL_BASE_URL`; Vercel preview deployments can use their Vercel-provided deployment host when it is absent. The server never silently uses the maintainer's hosted endpoint. The operator's hosting provider, Redis provider, and connected services process the data needed to fulfil requests. Depending on the deployment and upstream behaviour, activity, wellness, nutrition, and GPS data may pass through the RunFuel server in memory; managed credentials are encrypted before being stored in Redis. Do not assume that the source data is anonymous merely because profile identifiers are filtered from tool responses.

Operators should restrict access to their deployment, use HTTPS, keep Vercel and Redis credentials private, review provider retention and access settings, and avoid logging raw payloads. GPS tracks can reveal home, work, and personal routines; expose them only to trusted clients and consider whether full route data is needed for each analysis.

RunFuel's sanitization reduces identity fields in tool responses but is not a guarantee of anonymity or a substitute for securing the server, OAuth credentials, or upstream accounts. Upstream schemas can change, so review and test responses after dependency updates.

## Read-only boundary

RunFuel remains read-only for MyFitnessPal diary data. The privacy changes do not add any diary-writing, editing, or deletion capability.

## Important distinction

Removing the profile tool from the allowlist prevents clients from directly requesting that profile operation through RunFuel. It does not guarantee that every upstream activity response is free of identity fields. Response sanitization is implemented across all exposed data pools and is covered by regression tests for nested, case-varied, and alternate identifier keys. Because filtering is key-based, new upstream response fields should still be reviewed and added to the tests when they are introduced.
