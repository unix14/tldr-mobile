#!/usr/bin/env node
// Refresh tldr's mock feed with real headlines from NewsAPI.
//
// Runs from GitHub Actions (see .github/workflows/refresh-content.yml).
// Reads NEWSAPI_KEY from env. Writes assets/content/cards.json.
//
// Design notes:
//   * The output schema matches the app's ContentCard.fromJson(). Any change
//     to lib/models/card.dart must be mirrored here.
//   * Free-tier NewsAPI restrictions we respect:
//       - no more than ~100 requests/day (this cron fires 12x/day, ~6 req each
//         = 72/day headroom for reruns).
//       - server-side only (this runs in CI, so CORS is irrelevant).
//   * v1 has NO LLM summarization — we use the article title + description
//     as-is. Adding Claude/GPT summarization is a v1.5 concern; the shape
//     already supports richer bullets + why-it-matters.
//   * We deduplicate on URL AND on a normalized-title hash so wire-service
//     re-runs of the same story don't flood the feed.

import { writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

const NEWSAPI = 'https://newsapi.org/v2';
const KEY = process.env.NEWSAPI_KEY;
if (!KEY) {
  console.error('NEWSAPI_KEY env var is required.');
  process.exit(1);
}

// ── What we pull ───────────────────────────────────────────────────
// Each entry becomes one API call. Keep total under 90/day (12 runs × <=8).
const QUERIES = [
  { topic: 'tech',        endpoint: 'top-headlines', params: { country: 'us', category: 'technology', pageSize: 15 } },
  { topic: 'markets',     endpoint: 'top-headlines', params: { country: 'us', category: 'business',   pageSize: 12 } },
  { topic: 'science',     endpoint: 'top-headlines', params: { country: 'us', category: 'science',    pageSize: 10 } },
  { topic: 'world',       endpoint: 'top-headlines', params: { country: 'us', category: 'general',    pageSize: 15 } },
  { topic: 'israel',      endpoint: 'top-headlines', params: { country: 'il',                          pageSize: 15 } },
  { topic: 'ai',          endpoint: 'everything',    params: { q: '"artificial intelligence" OR "machine learning"', language: 'en', sortBy: 'publishedAt', pageSize: 10 } },
];

// Simple map from article topic → additional secondary topics we tag on the
// card. Keeps cards.json queryable by multiple interests without exploding
// the number of API calls.
const SECONDARY_TAGS = {
  tech:     ['ai'],
  ai:       ['tech'],
  markets:  ['world'],
  science:  [],
  world:    ['geopolitics'],
  israel:   ['world', 'geopolitics'],
};

async function fetchQuery({ endpoint, params }) {
  const url = new URL(`${NEWSAPI}/${endpoint}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  const res = await fetch(url, {
    headers: { 'X-Api-Key': KEY, 'User-Agent': 'tldr-content-refresh/1.0' },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`NewsAPI ${endpoint} → ${res.status}: ${body.slice(0, 200)}`);
  }
  const j = await res.json();
  return j.articles ?? [];
}

function normalizeTitle(s) {
  return (s ?? '')
    .toLowerCase()
    .replace(/\[.*?\]/g, '')
    .replace(/[^a-z0-9֐-׿ ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function isHebrew(s) {
  return /[֐-׿]/.test(s ?? '');
}

function detectLanguage(article) {
  const t = `${article.title ?? ''} ${article.description ?? ''}`;
  return isHebrew(t) ? 'he' : 'en';
}

function estimateSeconds(text) {
  const words = (text ?? '').split(/\s+/).filter(Boolean).length;
  // 3 words per second read speed, clamped to 20–120s.
  return Math.max(20, Math.min(120, Math.round(words / 3)));
}

function buildBullets(article) {
  const out = [];
  const desc = (article.description ?? '').trim();
  if (desc) out.push(desc);
  const content = (article.content ?? '').replace(/\[\+\d+ chars\]$/, '').trim();
  // NewsAPI's `content` is a snippet; split on sentence-ish boundaries.
  if (content) {
    const extra = content.split(/(?<=[.!?])\s+/).filter(s => s.length > 20);
    for (const s of extra.slice(0, 2)) out.push(s);
  }
  // Cap at 4 bullets so the card stays lightweight.
  return out.slice(0, 4);
}

function idFor(article) {
  return 'na_' + createHash('sha1').update(article.url ?? article.title ?? '').digest('hex').slice(0, 10);
}

function toCard(article, topic) {
  const language = detectLanguage(article);
  const bullets = buildBullets(article);
  const source = article.source ?? {};
  const publisher = source.name ?? 'Unknown';
  const url = article.url ?? '';
  return {
    id: idFor(article),
    kind: 'news',
    language,
    topicTags: [topic, ...(SECONDARY_TAGS[topic] ?? [])],
    headline: (article.title ?? '').replace(/\s+-\s+[^-]+$/, '').trim(),
    bullets,
    // Without an LLM we can't safely write "why it matters" from thin air.
    // Leave it null so the card just doesn't render that section.
    whyItMatters: null,
    confidence: 'confirmed',
    risk: 'standard',
    estimatedSeconds: estimateSeconds(bullets.join(' ')),
    publishedAt: article.publishedAt ?? new Date().toISOString(),
    sources: url
      ? [{
          publisher,
          url,
          tier: 1,
          publishedAt: article.publishedAt ?? new Date().toISOString(),
        }]
      : [],
    disagreement: null,
    youtubeId: null,
    channel: null,
    imageUrl: article.urlToImage ?? null,
  };
}

async function main() {
  const all = [];
  for (const q of QUERIES) {
    try {
      console.log(`[fetch] ${q.topic}`);
      const articles = await fetchQuery(q);
      console.log(`   → ${articles.length} articles`);
      for (const a of articles) {
        // Skip articles NewsAPI returns as `[Removed]` — dead placeholders.
        if ((a.title ?? '').startsWith('[Removed]')) continue;
        // Skip empty ones.
        if (!a.title || !a.url) continue;
        all.push(toCard(a, q.topic));
      }
    } catch (e) {
      console.error(`   ✗ ${q.topic}: ${e.message}`);
      // Keep going — one failed topic shouldn't kill the whole refresh.
    }
  }

  // Deduplicate: prefer earlier entries (higher-priority topic queries first).
  const seenUrl = new Set();
  const seenTitle = new Set();
  const dedup = [];
  for (const c of all) {
    const url = c.sources?.[0]?.url ?? c.id;
    const titleKey = normalizeTitle(c.headline);
    if (seenUrl.has(url) || seenTitle.has(titleKey)) continue;
    seenUrl.add(url);
    seenTitle.add(titleKey);
    dedup.push(c);
  }

  // Sort newest first so the feed opens on the freshest story.
  dedup.sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''));

  // Cap to keep the JSON file small on the wire.
  const capped = dedup.slice(0, 80);

  const outPath = path.resolve(process.cwd(), 'assets', 'content', 'cards.json');
  await mkdir(path.dirname(outPath), { recursive: true });
  await writeFile(outPath, JSON.stringify(capped, null, 2) + '\n', 'utf8');

  console.log(`\n[done] wrote ${capped.length} cards → ${outPath}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
