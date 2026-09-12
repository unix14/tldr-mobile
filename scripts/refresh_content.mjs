#!/usr/bin/env node
// Refresh tldr's feed from NewsAPI (English) + curated Hebrew RSS.
//
// Reads NEWSAPI_KEY from env, fetches, normalizes into ContentCard, writes
// assets/content/cards.json.
//
// Two sources:
//   1. NewsAPI — English coverage across tech, markets, science, world, AI.
//      Free-tier friendly (~72 requests/day).
//   2. Curated Hebrew RSS — the leading Israeli outlets that publish real
//      Hebrew (not English wire copy on the country=il route). Verified
//      alive as of Sep 2026: Ynet, Globes, Walla, Israel Hayom, Haaretz.
//
// The output shape matches lib/models/card.dart#ContentCard.fromJson().

import { writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import Parser from 'rss-parser';

// ── NewsAPI queries ────────────────────────────────────────────────
const NEWSAPI = 'https://newsapi.org/v2';
const KEY = process.env.NEWSAPI_KEY;

const NEWSAPI_QUERIES = [
  { topic: 'tech',    endpoint: 'top-headlines', params: { country: 'us', category: 'technology', pageSize: 15 } },
  { topic: 'markets', endpoint: 'top-headlines', params: { country: 'us', category: 'business',   pageSize: 12 } },
  { topic: 'science', endpoint: 'top-headlines', params: { country: 'us', category: 'science',    pageSize: 10 } },
  { topic: 'world',   endpoint: 'top-headlines', params: { country: 'us', category: 'general',    pageSize: 15 } },
  { topic: 'ai',      endpoint: 'everything',    params: { q: '"artificial intelligence" OR "machine learning"', language: 'en', sortBy: 'publishedAt', pageSize: 10 } },
];

// ── Hebrew RSS feeds ───────────────────────────────────────────────
// Kept minimal + verified. Each entry contributes ~10 items after cap.
const RSS_FEEDS = [
  {
    url: 'https://www.ynet.co.il/Integration/StoryRss2.xml',
    publisher: 'Ynet',
    topics: ['israel', 'world'],
    max: 10,
  },
  {
    url: 'https://www.globes.co.il/webservice/rss/rssfeeder.asmx/FeederNode?iID=2',
    publisher: 'Globes',
    topics: ['markets', 'israel'],
    max: 10,
  },
  {
    url: 'https://rss.walla.co.il/feed/1',
    publisher: 'Walla',
    topics: ['israel', 'world'],
    max: 8,
  },
  {
    url: 'https://www.israelhayom.co.il/rss.xml',
    publisher: 'Israel Hayom',
    topics: ['israel'],
    max: 8,
  },
  {
    url: 'https://www.haaretz.co.il/cmlink/1.1470869',
    publisher: 'Haaretz',
    topics: ['israel', 'world'],
    max: 10,
  },
];

// Additional topic tags that get bolted on based on the primary topic —
// keeps every card findable under adjacent interests.
const SECONDARY_TAGS = {
  tech:     ['ai'],
  ai:       ['tech'],
  markets:  ['world'],
  science:  [],
  world:    ['geopolitics'],
  israel:   ['world', 'geopolitics'],
};

// ── Utilities ──────────────────────────────────────────────────────

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

function stripHtml(s) {
  return (s ?? '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    // Common list-item markup → sentence break so lists survive as text.
    .replace(/<\/li>\s*<li[^>]*>/gi, '. ')
    .replace(/<li[^>]*>/gi, '')
    .replace(/<\/li>/gi, '. ')
    // All other tags → space so words don't run together.
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&hellip;/g, '…')
    // Numeric entities (&#8217; etc.) → best-effort decode.
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    // Collapse whitespace + trim.
    .replace(/\s+/g, ' ')
    .trim();
}

// Boilerplate patterns that show up in publisher descriptions and add no
// value on a card. Applied AFTER html stripping.
const BOILERPLATE = [
  /continue reading\.{0,3}$/i,
  /read (the|full) (article|story)\.?$/i,
  /the post .+ appeared first on .+\.?$/i,
  /this article was originally published on .+\.?$/i,
  /credit: .+$/i,
  /photo(?:s)?: .+$/i,
  /\[…?\]$/,
  /…$/,       // Trailing ellipsis
  /\.{2,}$/,  // Trailing dots run
];

function cleanBullet(s) {
  let out = stripHtml(s);
  for (const re of BOILERPLATE) out = out.replace(re, '').trim();
  // Fix "Wrong mindset.Treating AI" → "Wrong mindset. Treating AI"
  out = out.replace(/([.!?])([A-Z֐-׿])/g, '$1 $2');
  // Collapse runs of periods that HTML-list conversion sometimes leaves.
  out = out.replace(/(\s*\.\s*){2,}/g, '. ');
  return out.trim();
}

function estimateSeconds(text) {
  const words = (text ?? '').split(/\s+/).filter(Boolean).length;
  return Math.max(20, Math.min(120, Math.round(words / 3)));
}

function idFor(seed) {
  return 'c_' + createHash('sha1').update(seed).digest('hex').slice(0, 10);
}

// ── NewsAPI fetch ──────────────────────────────────────────────────

async function fetchNewsApi({ endpoint, params }) {
  if (!KEY) throw new Error('NEWSAPI_KEY not set');
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

function buildBulletsFromNewsApi(article) {
  const out = [];
  const desc = cleanBullet(article.description ?? '');
  if (desc && desc.length >= 20) out.push(desc);
  const content = cleanBullet(
    (article.content ?? '').replace(/\[\+\d+ chars\]$/, ''),
  );
  if (content && content !== desc) {
    const sentences = content
      .split(/(?<=[.!?])\s+/)
      .map(cleanBullet)
      .filter(s => s.length >= 20 && s !== desc);
    for (const s of sentences.slice(0, 2)) out.push(s);
  }
  return out.slice(0, 3);
}

function newsApiToCard(article, topic) {
  const bullets = buildBulletsFromNewsApi(article);
  const publisher = article.source?.name ?? 'Unknown';
  const url = article.url ?? '';
  return {
    id: idFor(url || article.title || ''),
    kind: 'news',
    language: isHebrew(`${article.title ?? ''} ${article.description ?? ''}`) ? 'he' : 'en',
    topicTags: [topic, ...(SECONDARY_TAGS[topic] ?? [])],
    headline: stripHtml((article.title ?? '').replace(/\s+-\s+[^-]+$/, '')),
    bullets,
    whyItMatters: null,
    confidence: 'confirmed',
    risk: 'standard',
    estimatedSeconds: estimateSeconds(bullets.join(' ')),
    publishedAt: article.publishedAt ?? new Date().toISOString(),
    sources: url
      ? [{ publisher, url, tier: 1, publishedAt: article.publishedAt ?? new Date().toISOString() }]
      : [],
    disagreement: null,
    youtubeId: null,
    channel: null,
    imageUrl: article.urlToImage ?? null,
  };
}

// ── RSS fetch ──────────────────────────────────────────────────────

const rssParser = new Parser({
  timeout: 12_000,
  headers: {
    // Some Israeli sites 403 non-browser UAs.
    'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 tldr-content-refresh/1.0',
    Accept: 'application/rss+xml, application/xml, text/xml, */*',
  },
});

function buildBulletsFromRss(item) {
  const raw = cleanBullet(
    item.contentSnippet ||
      item['content:encoded'] ||
      item.content ||
      item.summary ||
      '',
  );
  if (!raw) return [];
  const sentences = raw
    .split(/(?<=[.!?׃…])\s+/)
    .map(cleanBullet)
    .filter(s => s.length >= 12);
  if (sentences.length === 0) return [raw.slice(0, 280)];
  return sentences.slice(0, 3);
}

function rssToCard(item, feed) {
  const headline = stripHtml(item.title || '').trim();
  if (!headline) return null;
  const url = item.link || item.guid || '';
  if (!url) return null;
  const bullets = buildBulletsFromRss(item);
  const publishedAt = item.isoDate || item.pubDate || new Date().toISOString();
  const primaryTopic = feed.topics[0];
  const tags = new Set([...feed.topics, ...(SECONDARY_TAGS[primaryTopic] ?? [])]);
  return {
    id: idFor(url),
    kind: 'news',
    language: 'he',
    topicTags: [...tags],
    headline,
    bullets,
    whyItMatters: null,
    confidence: 'confirmed',
    risk: 'standard',
    estimatedSeconds: estimateSeconds(bullets.join(' ')),
    publishedAt: new Date(publishedAt).toISOString(),
    sources: [
      {
        publisher: feed.publisher,
        url,
        tier: 1,
        publishedAt: new Date(publishedAt).toISOString(),
      },
    ],
    disagreement: null,
    youtubeId: null,
    channel: null,
    imageUrl: item.enclosure?.url ?? null,
  };
}

async function fetchRss(feed) {
  const parsed = await rssParser.parseURL(feed.url);
  const items = (parsed.items ?? []).slice(0, feed.max);
  const cards = [];
  for (const it of items) {
    const c = rssToCard(it, feed);
    if (c) cards.push(c);
  }
  return cards;
}

// ── Main ───────────────────────────────────────────────────────────

async function main() {
  const all = [];

  // NewsAPI (English).
  if (KEY) {
    for (const q of NEWSAPI_QUERIES) {
      try {
        console.log(`[newsapi] ${q.topic}`);
        const articles = await fetchNewsApi(q);
        console.log(`   → ${articles.length} articles`);
        for (const a of articles) {
          if ((a.title ?? '').startsWith('[Removed]')) continue;
          if (!a.title || !a.url) continue;
          all.push(newsApiToCard(a, q.topic));
        }
      } catch (e) {
        console.error(`   ✗ newsapi ${q.topic}: ${e.message}`);
      }
    }
  } else {
    console.warn('[newsapi] NEWSAPI_KEY not set — skipping NewsAPI fetches.');
  }

  // Hebrew RSS.
  for (const feed of RSS_FEEDS) {
    try {
      console.log(`[rss] ${feed.publisher}`);
      const cards = await fetchRss(feed);
      console.log(`   → ${cards.length} items`);
      all.push(...cards);
    } catch (e) {
      console.error(`   ✗ rss ${feed.publisher}: ${e.message}`);
    }
  }

  // Deduplicate by URL + normalized-title.
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

  // Sort newest first.
  dedup.sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''));

  // Cap.
  const capped = dedup.slice(0, 100);

  const outPath = path.resolve(process.cwd(), 'assets', 'content', 'cards.json');
  await mkdir(path.dirname(outPath), { recursive: true });
  await writeFile(outPath, JSON.stringify(capped, null, 2) + '\n', 'utf8');

  const byLang = capped.reduce((acc, c) => {
    acc[c.language] = (acc[c.language] ?? 0) + 1;
    return acc;
  }, {});
  console.log(`\n[done] wrote ${capped.length} cards → ${outPath}`);
  console.log(`       breakdown: ${JSON.stringify(byLang)}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
