# AI Research Daily

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A curated daily digest of AI research --- papers that actually matter, stripped of hype.
Weekly roundups covering strategic moves from the major AI labs.

Every report is sourced, scored against a published rubric, and written to be useful
rather than loud. No AI-generated fluff. No recycled press releases.

## Why this exists

The AI research firehose is overwhelming. Hundreds of papers drop every day on arXiv
alone, most of them incremental. This project applies a consistent filtering discipline
to surface work with genuine substance: real algorithmic contributions, rigorous
evaluation, and results worth paying attention to.

Each paper is scored on five positive dimensions (problem importance, method substance,
experimental rigor, result significance, clarity) and three negative flags (hype,
thin novelty, weak evaluation). Papers that clear the bar get a structured summary
covering method, experiments, and results. Borderline cases go into a watchlist.

## Editorial standards

- **No fabrication.** Every factual claim --- paper titles, benchmarks, experimental
  results, company announcements --- must be traceable to a primary source linked in
  the report. Nothing is invented or embellished.
- **No distortion.** Conclusions reported must faithfully reflect what the original
  source demonstrates. Exaggerated or oversimplified claims are excluded.
- **Fact vs. inference.** When confidence is limited, the report says so plainly.
  Speculation is never presented as established fact.
- **Corrections.** If an error is discovered in a published report, a correction
  notice is appended to the original file with the date and nature of the fix.
  The original content is preserved for transparency.

## Report structure

### Daily reports (`reports/daily/YYYY-MM-DD.md`)

- **Top takeaways** --- the 4-6 most important developments of the day
- **Selected research papers** --- papers that passed the filtering rubric, with full
  summaries covering method, experiments, and results
- **Papers to watch** --- borderline but interesting work
- **Company updates** --- model launches, research releases, open-source drops, and
  strategic moves from DeepSeek, Google DeepMind, Meta, OpenAI, Anthropic, and
  Microsoft
- **What to keep an eye on** --- forward-looking notes
- **Sources** --- direct links for every claim

### Weekly reports (`reports/weekly/YYYY-MM-DD.md`)

Published every Monday, covering the preceding week's major company news.

## Directory layout

```
AI_Research_Daily/
--------- README.md
--------- LICENSE
--------- .gitignore
--------- reports/
    --------- daily/
    ---   --------- README.md
    ---   --------- YYYY-MM-DD.md
    --------- weekly/
        --------- README.md
        --------- YYYY-MM-DD.md
```

## License

MIT --- see [LICENSE](LICENSE) for details.

The reports themselves are provided for informational purposes. All paper and
company citations link to their original sources.
