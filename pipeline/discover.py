#!/usr/bin/env python3
"""Find candidate AI terms trending this week that aren't in the catalog yet.

Sources (public, no keys): arXiv listings (cs.CL, cs.LG, cs.AI), Hugging Face daily papers,
and Hacker News stories mentioning AI. Candidate phrases are scored by frequency × source
diversity and written to pipeline/out/candidates.json for generate.py.

Usage:
  python3 pipeline/discover.py [--limit 40]
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from build_content import CONTENT, load_terms_yaml

OUT = Path(__file__).resolve().parent / "out"
UA = {"User-Agent": "ai-cab-content-bot/1.0 (+https://github.com/aannuuj/ai-cab)"}

STOP = {
    "the", "a", "an", "of", "for", "and", "with", "via", "in", "on", "to", "from", "using", "towards", "toward",
    "is", "are", "be", "we", "our", "large", "language", "models", "model", "learning", "based", "new", "show",
    "how", "what", "why", "your", "you", "can", "at", "by", "as", "into", "beyond", "through", "llm", "llms", "ai",
}
GENERIC = {"paper", "dataset", "benchmark", "study", "approach", "method", "framework", "survey", "analysis", "system"}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def arxiv_titles() -> list[str]:
    query = "cat:cs.CL+OR+cat:cs.LG+OR+cat:cs.AI"
    url = f"https://export.arxiv.org/api/query?search_query={query}&sortBy=submittedDate&sortOrder=descending&max_results=200"
    root = ET.fromstring(fetch(url))
    ns = {"a": "http://www.w3.org/2005/Atom"}
    return [" ".join((e.findtext("a:title", "", ns) or "").split()) for e in root.findall("a:entry", ns)]


def hf_titles() -> list[str]:
    data = json.loads(fetch("https://huggingface.co/api/daily_papers?limit=100"))
    return [item.get("paper", {}).get("title") or item.get("title", "") for item in data]


def hn_titles() -> list[str]:
    url = "https://hn.algolia.com/api/v1/search_by_date?tags=story&query=AI&hitsPerPage=200"
    return [hit.get("title", "") for hit in json.loads(fetch(url)).get("hits", [])]


def phrases(title: str) -> set[str]:
    """Acronyms, hyphenated coinages and 2–3 word noun-ish phrases."""
    found: set[str] = set()
    for acr in re.findall(r"\b[A-Z][A-Za-z]*[A-Z][A-Za-z0-9-]*\b", title):
        if 2 <= len(acr) <= 12:
            found.add(acr)
    words = [w for w in re.findall(r"[A-Za-z][A-Za-z0-9-]+", title)]
    lowered = [w.lower() for w in words]
    for n in (2, 3):
        for i in range(len(lowered) - n + 1):
            gram = lowered[i : i + n]
            if any(g in STOP or g in GENERIC for g in gram):
                continue
            found.add(" ".join(gram))
    for w in words:
        if "-" in w and len(w) > 6:
            found.add(w.lower())
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=40)
    args = parser.parse_args()

    existing: set[str] = set()
    for path in (CONTENT / "terms").glob("*.yaml"):
        for t in load_terms_yaml(path):
            existing.add(str(t.get("term", "")).lower())
            if t.get("expansion"):
                existing.add(str(t["expansion"]).lower())

    sources = {"arxiv": arxiv_titles, "huggingface": hf_titles, "hackernews": hn_titles}
    counts: collections.Counter[str] = collections.Counter()
    seen_in: dict[str, set[str]] = collections.defaultdict(set)
    examples: dict[str, str] = {}
    for name, loader in sources.items():
        try:
            titles = loader()
        except Exception as exc:  # one flaky source shouldn't sink the run
            print(f"warning: {name} failed: {exc}", file=sys.stderr)
            continue
        print(f"{name}: {len(titles)} titles", file=sys.stderr)
        for title in titles:
            for p in phrases(title):
                counts[p] += 1
                seen_in[p].add(name)
                examples.setdefault(p, title)

    scored = []
    for phrase, count in counts.items():
        if count < 2 or phrase.lower() in existing:
            continue
        score = count * (1 + 0.75 * (len(seen_in[phrase]) - 1))
        scored.append({"phrase": phrase, "score": round(score, 2), "sources": sorted(seen_in[phrase]), "seen_in": examples[phrase]})
    scored.sort(key=lambda c: c["score"], reverse=True)

    OUT.mkdir(exist_ok=True)
    (OUT / "candidates.json").write_text(json.dumps(scored[: args.limit], indent=2))
    print(f"→ {min(len(scored), args.limit)} candidates in pipeline/out/candidates.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
