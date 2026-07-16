# Daily Research Playbook

## Objective

Produce one high-signal AI daily brief per run. Favor substance over volume. A shorter report with genuinely important items is better than a longer report padded with weak papers or recycled company news.


## Language requirement

All output files MUST be written in Chinese (Simplified Chinese, zh-CN):

- eports/daily/YYYY-MM-DD.md — full daily report in Chinese
- eports/daily/YYYY-MM-DD.email.md — email digest in Chinese
- eports/weekly/YYYY-MM-DD.md — weekly roundup in Chinese

Only paper titles, company names, product names, benchmark names, and technical terms that have no standard Chinese translation may remain in English. Everything else — summaries, analysis, takeaways, company news descriptions — must be in Chinese.


## Coverage window

- Use Asia/Shanghai as the source of truth for dates.
- Treat the run date as the report date.
- Prefer content published or materially updated within the previous calendar day (yesterday, Asia/Shanghai time).
- If an item is slightly older but newly important, include it and explain why.

## Required inputs

Read these files before drafting the report:

- `config/research_scope.json`
- `config/company_watchlist.json`

---

## Paper pipeline: Collect -> Deep-read -> Aggregate

### Phase 1: Candidate collection (Main Agent)

The main agent scans these sources for candidate papers:

- [arXiv](https://arxiv.org) new submissions and cross-lists (cs.CL, cs.CV, cs.AI, cs.LG, stat.ML, etc.)
- [HuggingFace Daily Papers](https://huggingface.co/papers) community-voted highlights

Screen by title and abstract only. Target 10-15 candidates. Filter out: obvious padding, pure prompt wrappers, micro-variants of known recipes.

### Phase 2: Parallel deep reading (Sub-Agents)

Each candidate paper gets its own sub-agent. The sub-agent must:

1. Open the paper (arXiv HTML / PDF)
2. Extract structured content and return to the main agent:

```
- Title
- arXiv ID
- Why it matters (one sentence)
- Method details (architecture, training strategy, key innovation)
- Experimental setup (datasets, baselines, ablation design)
- Experimental results (key metrics, comparative data)
- Why it passed initial screening
- Source URL
```

Sub-agents do NOT score or filter. They only extract. All content must come from the paper itself -- no speculation, no filling in missing details.

All sub-agents can be launched in parallel. They have no dependencies on each other.

### Phase 3: Aggregation and writing (Main Agent)

After receiving all sub-agent cards, the main agent:

1. Scores each paper using the rubric below (5 positive signals + 3 negative flags)
2. Selects 6-8 final papers and 2-4 watchlist items
3. Writes Top Takeaways -- identifying cross-paper trends or contradictions
4. Composes the full report in standard format

---

## Paper selection rubric

Score each candidate paper before inclusion.

### Positive signals

- `Problem importance (0-3)`: meaningful problem with practical or research value
- `Method substance (0-5)`: real algorithmic, architectural, training, or inference contribution
- `Experimental rigor (0-5)`: strong baselines, ablations, multiple datasets, or careful evaluation
- `Result significance (0-3)`: notable gains, new capability, or meaningful efficiency improvement
- `Clarity and reproducibility (0-2)`: enough implementation detail to explain how it works

### Negative signals

- `Hype penalty (0 to -4)`: title or framing oversells limited evidence
- `Thin novelty penalty (0 to -4)`: mostly recombination, repackaging, or small prompt tweaks
- `Weak evaluation penalty (0 to -4)`: tiny benchmark set, weak baselines, or missing ablations

### Inclusion rule

- Keep a paper in the main report only if it has strong substance and no major red flag.
- Use a watchlist section for borderline but still interesting papers.
- Exclude papers that are mostly noise, vanity benchmarks, weak prompt wrappers, or marketing-heavy writeups.

## Red flags for "watered" papers

Exclude or strongly down-rank papers with one or more of these patterns:

- only a tiny variation on a known recipe with no serious evaluation
- benchmark cherry-picking
- no strong baseline comparisons
- claims of general capability from narrow task evidence
- exaggerated gains with missing details
- vague implementation section that hides what is actually new

## Paper summary format

All summaries must be written in Chinese. Only paper titles and technical terms without standard Chinese translations may remain in English.


For every kept paper, include:

1. `Title`
2. `Why it matters`
3. `Implementation method`
4. `Experimental setup`
5. `Experimental results`
6. `Why it passed the filter`
7. `Sources`

Be concrete about architecture choices, data, training strategy, inference method, and evaluation metrics whenever the source provides them.

---

## News pipeline: Source matrix -> Parallel fetch -> Aggregate

### Phase 1: Source matrix (Main Agent)

For each tracked company, the main agent builds a source matrix. Source types include but are not limited to:

- **Official channels**: company blogs, newsrooms, official GitHub repos, official social media accounts
- **Tech media**: Ars Technica, The Verge, TechCrunch, The Register, VentureBeat, ZDNet
- **Community platforms**: Hacker News, Reddit (r/MachineLearning, r/singularity), Twitter/X official accounts
- **Vertical outlets**: company-specific or domain-specific sources as appropriate

### Phase 2: Parallel fetch via script (preferred) or manual fallback

**Primary method**: Run the bundled parallel fetcher script. This replaces manual per-source queries and eliminates sequential timeout cascading.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/fetch_company_news.ps1 `
    -ConfigPath config/news_sources.json `
    -OutputPath tmp_company_news.json `
    -MaxTotalSeconds 90
```

The script reads `config/news_sources.json`, which defines **three source tiers** per company:
- **Tier 1 (fast RSS)**: Official blog RSS feeds, Google News RSS -- 8s timeout, 1 retry
- **Tier 2 (aggregator)**: Tech media search pages (The Verge, TechCrunch, Ars Technica) -- 8s timeout
- **Universal fallback**: Google News RSS with company keywords works for every company

All fetches run **in parallel** (not sequentially) with `-ThrottleLimit 20`. No single source blocks the pipeline -- if OpenAI's blog times out, Google News and The Verge still run simultaneously for OpenAI and for all other companies.

### Phase 2b: Manual fallback (only if script fails)

If `fetch_company_news.ps1` fails or is unavailable, query sources manually with these resilience rules:

**Timeout rules**:
- Per-source timeout: **8 seconds maximum**, not 15s
- Retry once on timeout (total 16s per source worst case)
- Run sources **in parallel**, not sequentially
- If 3+ sources fail for the same company, skip that company rather than burning time budget
- Total news collection budget: 60 seconds, then stop and report what was found

**JS-rendered page handling**:
- Never attempt to scrape JS-rendered pages (Next.js, React SPA) with plain HTTP -- they return empty shells
- For Anthropic: use their RSS feed (`https://www.anthropic.com/feed.xml`) or Google News search
- For GitHub org pages: use the GitHub API or skip and watch for releases
- Rule of thumb: if raw HTML < 10KB and mostly `<script>` tags, page is JS-rendered -- immediately fall back

**Source priority order**:
1. Google News RSS: `https://news.google.com/rss/search?q={KEYWORD}&hl=en-US&gl=US&ceid=US:en`
2. Official blog RSS (if known to work)
3. Tech media search pages
4. Company homepages (last resort, often JS-rendered)

**Content extraction format** (same as script output):
```
- Company name
- Headline (in Chinese)
- What happened (2-3 sentences, in Chinese)
- Why it matters (1-2 sentences, in Chinese)
- Source URL (must be a direct, real link)
```

Do NOT judge newsworthiness at extraction time. Return every potentially relevant item. URLs must be real and accessible -- no fabricated links.

### Phase 3: Dedup and aggregate (Main Agent)

After receiving all sub-agent cards, the main agent:

1. Deduplicates by URL (same news reported by multiple sources)
2. Cross-validates -- prioritizes official sources + authoritative media
3. Labels confidence:
   - **Confirmed**: official release OR 2+ independent reliable sources
   - **Unverified**: single non-official source
   - Unverified items must be flagged in the report
4. Groups by company, selects top 2-3 updates per company
5. For weekly reports: adds a cross-company trend analysis

### Source configuration maintenance

The file `config/news_sources.json` is the canonical source list. When a source consistently fails across 3+ runs:
1. Check if the URL is still valid
2. Check if an RSS feed alternative exists
3. If unfixable, add a note in the config and demote to tier 3
4. If a new reliable source is found, add it to the config

At minimum, every company must have at least one Google News RSS entry, since that source works for any keyword and returns structured XML.

---

## Sub-Agent quality constraints

**Output language**: All sub-agent extracted content must be returned in Chinese. The main agent's final report is also in Chinese. Only original paper titles, company/product names, and untranslatable technical terms may stay in English.


All sub-agents (paper reading + news fetching) must follow these rules:

- **No fabrication**: do not invent papers, data, news events, or URLs that do not exist
- **No distortion**: returned content must faithfully reflect the original source
- **Flag uncertainty**: if source information is incomplete or ambiguous, note it explicitly -- do not fill gaps with guesses
- **Real URLs only**: every URL must be a directly accessible link to the original source; no fabricated or concatenated URLs
- **Failure handling**: if a sub-agent cannot complete its task (network timeout, source unavailable, etc.), return a clear failure reason; the main agent records the source as unavailable in the report

---

## Company item format

All company items must be written in Chinese. Company names and product names may remain in English. Headlines, descriptions, and analysis must be in Chinese.


For each company item, include:

1. `Headline`
2. `What changed`
3. `Why it matters`
4. `Source`

## Output files

All files use Chinese. See Language requirement above.

Each run should create or update:

- eports/daily/YYYY-MM-DD.md
- eports/daily/YYYY-MM-DD.email.md

The full report should contain:

1. `Top takeaways`
2. `Selected research papers`
3. `Papers to watch`
4. `Company updates`
5. `What to keep an eye on next`
6. `Sources`

The email digest should be short, scannable, in Chinese, and limited to the most important items from the day.

## Quality bar

- Cite direct sources with Markdown links.
- Distinguish clearly between facts and inference.
- Avoid repeating the same story unless there is a meaningful new development.
- If confidence is limited, say so plainly.
- Do not invent missing implementation details or results.

## Weekly roundup

On Monday (Asia/Shanghai time), compile a weekly company news roundup covering the preceding Monday through Sunday. Write it to `reports/weekly/YYYY-MM-DD.md` using the same company item format as the daily report. Include only company news items -- skip paper coverage.

## Email step

If `config/email.json` exists, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/send_digest.ps1 -ConfigPath config/email.json -ReportPath reports/daily/YYYY-MM-DD.md -DigestPath reports/daily/YYYY-MM-DD.email.md
```

If the email config or SMTP password is missing, do not fail the report. Note the skip in the run summary.
