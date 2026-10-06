#!/usr/bin/env python3
"""Draft catalog entries for new AI terms with Claude, for human review.

Reads pipeline/out/candidates.json (from discover.py) or --terms, asks Claude to (1) decide
whether each candidate is a real, durable AI term worth teaching and (2) write the entry in the
house style. Accepted drafts go to content/terms/drafts-<date>.yaml; the weekly workflow opens a
PR so a person reviews every word before it ships.

Usage:
  ANTHROPIC_API_KEY=... python3 pipeline/generate.py [--max 15] [--terms "context rot" "MoE routing"]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import anthropic
import yaml

from build_content import CONTENT, load_terms_yaml

ROOT = Path(__file__).resolve().parent
MODEL = "claude-opus-5-5"

TOPICS = [t["id"] for t in yaml.safe_load((CONTENT / "topics.yaml").read_text())]

SYSTEM = """You write entries for AI-Cab, an app that teaches the vocabulary of AI in one-minute daily cards.

House style:
- beginner: plain English for a smart non-technical reader, ≤ 25 words, no jargon.
- builder: how an engineer meets it in practice, ≤ 35 words.
- research: the precise technical idea (math notation is fine), ≤ 45 words.
- analogy: one short everyday comparison.
- example: one natural sentence that contains the term verbatim.
- No hype words (revolutionary, game-changing, cutting-edge, unleash, delve).
- Only include `origin` when you are confident of the paper/organisation and year.
- Be accurate. If a candidate is a product name, a one-off paper title, or too vague to teach, reject it."""

ENTRY_SCHEMA = {
    "type": "object",
    "properties": {
        "accept": {"type": "boolean"},
        "reason": {"type": "string"},
        "id": {"type": "string", "description": "kebab-case slug"},
        "term": {"type": "string"},
        "expansion": {"type": "string"},
        "pos": {"type": "string", "enum": ["n.", "v.", "adj."]},
        "difficulty": {"type": "string", "enum": ["beginner", "intermediate", "pro"]},
        "topics": {"type": "array", "items": {"type": "string", "enum": TOPICS}},
        "beginner": {"type": "string"},
        "builder": {"type": "string"},
        "research": {"type": "string"},
        "analogy": {"type": "string"},
        "example": {"type": "string"},
        "origin": {"type": "string"},
    },
    "required": ["accept", "reason", "id", "term", "pos", "difficulty", "topics", "beginner", "builder", "research", "analogy", "example"],
    "additionalProperties": False,
}


def draft(client: anthropic.Anthropic, phrase: str, context: str, existing: list[str]) -> dict | None:
    prompt = (
        f"Candidate term: {phrase}\n"
        f"Seen in: {context or 'n/a'}\n\n"
        f"Terms already in the catalog (don't duplicate; reuse ids for `related`): {', '.join(existing[:400])}\n\n"
        "Decide whether to accept it, then write the entry. Use the canonical spelling of the term."
    )
    response = client.beta.messages.create(
        model=MODEL,
        max_tokens=4000,
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        output_config={"effort": "medium", "format": {"type": "json_schema", "schema": ENTRY_SCHEMA}},
        system=SYSTEM,
        messages=[{"role": "user", "content": prompt}],
    )
    if response.stop_reason == "refusal":
        print(f"  refused: {phrase}", file=sys.stderr)
        return None
    text = next((b.text for b in response.content if b.type == "text"), "")
    try:
        entry = json.loads(text)
    except json.JSONDecodeError:
        print(f"  unparseable response for {phrase}", file=sys.stderr)
        return None
    if not entry.pop("accept", False):
        print(f"  rejected {phrase}: {entry.get('reason')}", file=sys.stderr)
        return None
    entry.pop("reason", None)
    return entry


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, default=15, help="max candidates to send to Claude")
    parser.add_argument("--terms", nargs="*", help="explicit terms instead of candidates.json")
    args = parser.parse_args()

    existing_terms = []
    for path in (CONTENT / "terms").glob("*.yaml"):
        existing_terms += load_terms_yaml(path)
    existing_ids = {t["id"] for t in existing_terms}
    existing_names = sorted({str(t["term"]) for t in existing_terms})

    if args.terms:
        candidates = [{"phrase": t, "seen_in": ""} for t in args.terms]
    else:
        path = ROOT / "out" / "candidates.json"
        if not path.exists():
            print("No candidates.json, run discover.py first", file=sys.stderr)
            return 1
        candidates = json.loads(path.read_text())

    client = anthropic.Anthropic()
    today = dt.date.today().isoformat()
    accepted = []
    for candidate in candidates[: args.max]:
        print(f"• {candidate['phrase']}", file=sys.stderr)
        entry = draft(client, candidate["phrase"], candidate.get("seen_in", ""), existing_names)
        if not entry or entry["id"] in existing_ids:
            continue
        entry["added"] = today
        entry["trending"] = 0.7
        existing_ids.add(entry["id"])
        accepted.append(entry)

    if not accepted:
        print("No new terms this week.")
        return 0

    out = CONTENT / "terms" / f"drafts-{today}.yaml"
    header = f"# Drafted by pipeline/generate.py on {today}. Review every entry before merging.\n\n"
    body = "\n".join(yaml.safe_dump([e], allow_unicode=True, sort_keys=False, width=1000) for e in accepted)
    out.write_text(header + body, encoding="utf-8")
    print(f"→ {len(accepted)} drafts in {out.relative_to(CONTENT.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
