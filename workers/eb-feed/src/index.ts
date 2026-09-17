import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
import { MARKETS, contentHash, normalize, type Market } from "./normalize.ts";
import { fetchSources } from "./upstream.ts";

const log = (msg: object) => console.log(JSON.stringify(msg));

const RETRY = {
  retries: { limit: 3, delay: "30 seconds", backoff: "exponential" },
  timeout: "2 minutes",
} as const;

// Edge and clients revalidate hourly; with a nightly job that's at most 1h stale,
// so no purge (and no API token) is needed.
const CACHE_CONTROL = "public, max-age=3600";

/** Refuse to publish if a market shrinks more than this vs the live file. */
const MAX_DROP = 0.5;

export class FeedWorkflow extends WorkflowEntrypoint<Env> {
  async run(_event: WorkflowEvent<unknown>, step: WorkflowStep) {
    const failed: Market[] = [];
    for (const market of Object.keys(MARKETS) as Market[]) {
      try {
        await this.publishMarket(market, step);
      } catch (error) {
        // One market failing must not block the others.
        log({ event: "market_failed", market, error: String(error) });
        failed.push(market);
      }
    }
    if (failed.length) throw new Error(`Failed markets: ${failed.join(", ")}`);
  }

  private async publishMarket(market: Market, step: WorkflowStep) {
    const key = `${market}.json`;

    const next = await step.do(`fetch ${market}`, RETRY, async () => {
      const { list, shops } = await fetchSources(market);
      const feed = normalize(market, list, shops, new Date().toISOString(), log);
      return {
        body: JSON.stringify(feed),
        sha256: await contentHash(feed),
        count: Object.keys(feed.data).length,
      };
    });

    const live = await step.do(`head ${market}`, RETRY, async () => {
      const head = await this.env.FEED_BUCKET.head(key);
      return head
        ? {
            sha256: head.customMetadata?.sha256 ?? "",
            count: Number(head.customMetadata?.count ?? 0),
          }
        : null;
    });

    if (live?.sha256 === next.sha256) {
      log({ event: "unchanged", market, count: next.count });
      return;
    }
    if (next.count === 0 || (live && next.count < live.count * (1 - MAX_DROP))) {
      log({ event: "guard_skipped", market, count: next.count, liveCount: live?.count ?? null });
      return;
    }

    await step.do(`publish ${market}`, RETRY, async () => {
      await this.env.FEED_BUCKET.put(key, next.body, {
        httpMetadata: {
          contentType: "application/json; charset=utf-8",
          cacheControl: CACHE_CONTROL,
        },
        customMetadata: { sha256: next.sha256, count: String(next.count) },
      });
    });

    log({ event: "published", market, count: next.count, previousCount: live?.count ?? null });
  }
}

export default {
  // ponytail: no HTTP surface; the Workflow runs on its cron schedule.
  fetch: () => new Response(null, { status: 404 }),
} satisfies ExportedHandler<Env>;
