# eb-feed

Builds the partner feed the EuroBonus Finder extension reads — one JSON file per
EuroBonus market (`se`, `no`, `dk`, `fi`).

A Cloudflare Workflow runs nightly (03:00 UTC). For each market it:

1. **fetch** — downloads SAS's public partner data (the browser-extension
   domain list + the shops list from `onlineshopping.loyaltykey.com`) and
   normalizes it (`src/normalize.ts`).
2. **head** — reads the hash of the currently published file. Unchanged → stop.
3. **guard** — skips publishing if the market is empty or shrank by more than half.
4. **publish** — uploads `<market>.json` to the bucket behind the deployed app.

Each step retries on its own; a failing market doesn't block the others.

## Feed format

```jsonc
{
  "schema": 1,
  "market": "se", // ISO 3166-1 alpha-2
  "locale": "sv-SE", // upstream locale the data was fetched with
  "currency": "SEK",
  "generatedAt": "2026-09-17T03:00:12Z",
  "data": {
    // Key: host without www., plus a first path segment only when two shops share a host.
    "bjornborg.com": {
      "id": "…",
      "name": "Björn Borg",
      "type": "variable", // "variable" = points per 100 of the currency, "fixed" = per new customer
      "points": 25,
      "campaign": true,
      "campaignPoints": 50,
      "campaignEnds": "2026-09-20",
      "url": "https://onlineshopping.flysas.com/sv-SE/butiker/bjorn-borg/…",
    },
  },
}
```

Lookup: try `host/firstPathSegment`, then `host`.

## Develop

```sh
vp install
vpr build:local   # fetch + normalize every market into ./out (no upload)
vpr test          # vp test
vpr lint          # vp lint
vpr fmt           # vp fmt
vpr check         # vp check: format, lint, typecheck
vpr build         # vp build (Cloudflare Vite plugin) → dist/
```

## Run your own

The published app reads from the maintainers' own deployment. To host the feed
yourself you need a Cloudflare
account with R2 enabled and a domain on Cloudflare to serve the files from. The steps below use `feed.example.com` and
the default bucket name `eb-feed`; replace both with your own.

1. **Authenticate.** Either run `vp exec wrangler login`, or export an
   [API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
   with Workers Scripts, Workers R2 Storage and Zone (for the custom domain)
   permissions. Keep IDs and tokens in your shell environment; never commit
   them.

   ```sh
   export CLOUDFLARE_ACCOUNT_ID=<your account id>
   export CLOUDFLARE_API_TOKEN=<your token>   # skip if you used wrangler login
   ```

2. **Create the bucket.** `wrangler.jsonc` expects an EU-jurisdiction bucket
   named `eb-feed`. If you pick another name or jurisdiction, update
   `r2_buckets` in `wrangler.jsonc` to match.

   ```sh
   vp exec wrangler r2 bucket create eb-feed --jurisdiction eu
   ```

3. **Deploy and run it once.** The workflow then runs nightly at 03:00 UTC.

   ```sh
   vpr deploy                                   # vp build && wrangler deploy
   vp exec wrangler workflows trigger eb-feed   # publish now
   ```

   To deploy on every push instead, connect the repo under the Worker's
   **Settings → Builds** with root directory `/workers/eb-feed`, deploy command
   `pnpm exec wrangler deploy` (`npx` fails: the package pins pnpm) and build
   watch path `workers/eb-feed/*` (watch paths are relative to the repo root).

4. **Serve the bucket.** Connect a custom domain (the zone ID is on the domain's
   Overview page in the dashboard) and allow cross-origin `GET`s so the
   extension can fetch the files:

   ```sh
   vp exec wrangler r2 bucket domain add eb-feed --jurisdiction eu \
     --domain feed.example.com --zone-id <your zone id>

   echo '{"rules":[{"allowed":{"origins":["*"],"methods":["GET"]}}]}' > cors.json
   vp exec wrangler r2 bucket cors set eb-feed --jurisdiction eu --file cors.json
   ```

   Then, in the dashboard, add a Cache Rule for the zone (Caching → Cache Rules)
   matching `Hostname equals feed.example.com` with **Eligible for cache**.
   Check it works: `curl -I https://feed.example.com/se.json`.

5. **Point the app at it.** The feed host isn't committed; the build injects it
   from the `FEED_HOST` build setting into the extension (`manifest.json`,
   `feed.js`) and the app. Set it in the git-ignored
   `EuroBonus Finder/Config/Feed.local.xcconfig`, then rebuild:

   ```
   FEED_HOST = feed.example.com
   ```

   On Xcode Cloud, set a `FEED_HOST` environment variable on the workflow
   instead; `ci_scripts/ci_post_clone.sh` writes the file. The build fails if
   it's missing.

## Caching

Objects are sent with `Cache-Control: public, max-age=3600`, so the edge and
clients pick up a new nightly file within an hour — no cache purge needed.

After a manual `workflows trigger`, the edge can keep the previous file for up
to an hour. To serve the new one immediately, purge the URLs in the Cloudflare
dashboard (the feed's zone → Caching → Configuration → Custom Purge) or via the
[purge API](https://developers.cloudflare.com/api/resources/cache/methods/purge/)
with a token that has Zone → Cache Purge. Installed extensions also keep their
own copy for up to an hour.
