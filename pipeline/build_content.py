#!/usr/bin/env python3
"""Validate the term bank in content/ and compile it into a ContentPack JSON.

Outputs:
  ios/AICab/Resources/content.json   bundled with the app (offline-first)
  dist/content/pack-v<N>.json        published to the CDN
  dist/content/manifest.json         what the app polls for updates

Usage:
  python3 pipeline/build_content.py            # validate + build
  python3 pipeline/build_content.py --check    # validate only (CI)

Term files are YAML, but scalar values never need quoting: any `key: value`
line inside a term is treated as plain text, so definitions can contain colons.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
APP_RESOURCE = ROOT / "ios" / "AICab" / "Resources" / "content.json"
DIST = ROOT / "dist" / "content"

LEVELS = ("beginner", "builder", "research")
DIFFICULTIES = ("beginner", "intermediate", "pro")
SECTIONS = ("trending", "foundations", "build", "frontier", "world")
PALETTES = ("teal", "coral", "cream", "olive")
MAX_WORDS = {"beginner": 32, "builder": 40, "research": 48}
BANNED = ("revolutionary", "game-changing", "game changer", "cutting-edge", "unleash", "delve")
SCALAR_LINE = re.compile(r"^(\s+)([a-z_]+): (.+)$")


class ContentError(Exception):
    pass


def load_terms_yaml(path: Path) -> list[dict]:
    """Loads a term file, auto-quoting free-text scalars so authors never fight YAML."""
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = SCALAR_LINE.match(line)
        if match:
            indent, key, value = match.groups()
            if value[0] not in "[{'\"":
                line = f"{indent}{key}: {json.dumps(value.strip(), ensure_ascii=False)}"
        lines.append(line)
    data = yaml.safe_load("\n".join(lines)) or []
    if not isinstance(data, list):
        raise ContentError(f"{path.name}: expected a list of terms")
    for item in data:
        item["_file"] = path.name
    return data


def load_config() -> tuple[dict, list[dict], list[dict]]:
    config = yaml.safe_load((CONTENT / "config.yaml").read_text(encoding="utf-8"))
    topics = yaml.safe_load((CONTENT / "topics.yaml").read_text(encoding="utf-8"))
    chapters = yaml.safe_load((CONTENT / "chapters.yaml").read_text(encoding="utf-8"))
    return config, topics, chapters


def build_topics(raw: list[dict], errors: list[str]) -> list[dict]:
    topics = []
    seen = set()
    for order, t in enumerate(raw):
        tid = t.get("id")
        if not tid or tid in seen:
            errors.append(f"topics.yaml: missing or duplicate id {tid!r}")
            continue
        seen.add(tid)
        if t.get("section") not in SECTIONS:
            errors.append(f"topic {tid}: bad section {t.get('section')!r}")
        if t.get("palette", "teal") not in PALETTES:
            errors.append(f"topic {tid}: bad palette {t.get('palette')!r}")
        topics.append({
            "id": tid,
            "title": t["title"],
            "eyebrow": t.get("eyebrow"),
            "section": t["section"],
            "symbol": t["symbol"],
            "palette": t.get("palette", "teal"),
            "isPremium": bool(t.get("premium", False)),
            "order": order,
        })
    return topics


def build_terms(raw: list[dict], topics: dict[str, dict], errors: list[str], warnings: list[str]) -> list[dict]:
    terms = []
    ids = [t.get("id") for t in raw]
    known = set(ids)
    dupes = {i for i in ids if ids.count(i) > 1}
    for d in sorted(dupes):
        errors.append(f"duplicate term id {d!r}")

    for t in raw:
        where = f"{t.get('_file')}:{t.get('id')}"
        missing = [key for key in ("id", "term", "difficulty", "topics", *LEVELS) if not t.get(key)]
        if missing:
            errors.append(f"{where}: missing {', '.join(missing)}")
            continue
        if t.get("difficulty") not in DIFFICULTIES:
            errors.append(f"{where}: difficulty must be one of {DIFFICULTIES}")
        term_topics = t.get("topics") or []
        for topic in term_topics:
            if topic not in topics:
                errors.append(f"{where}: unknown topic {topic!r}")
        for level in LEVELS:
            text = str(t.get(level, ""))
            words = len(text.split())
            if words > MAX_WORDS[level]:
                warnings.append(f"{where}: {level} definition is {words} words (max {MAX_WORDS[level]})")
            lowered = text.lower()
            for banned in BANNED:
                if banned in lowered:
                    errors.append(f"{where}: banned phrase {banned!r} in {level}")
        for key in ("related", "contrast"):
            for ref in t.get(key) or []:
                if ref not in known:
                    warnings.append(f"{where}: {key} → unknown term {ref!r} (dropped)")
        example = t.get("example")
        if example and t.get("term", "").lower() not in example.lower():
            warnings.append(f"{where}: example doesn't contain the term (no fill-in-the-blank question)")

        # A term is premium only if every topic it belongs to is premium.
        premium = bool(term_topics) and all(topics.get(x, {}).get("isPremium") for x in term_topics)
        terms.append({
            "id": t["id"],
            "term": str(t["term"]),
            "expansion": t.get("expansion"),
            "ipa": t.get("ipa"),
            "pos": t.get("pos", "n."),
            "definitions": {level: str(t[level]) for level in LEVELS},
            "analogy": t.get("analogy"),
            "example": t.get("example"),
            "origin": t.get("origin"),
            "difficulty": t["difficulty"],
            "topics": term_topics,
            "related": [r for r in t.get("related") or [] if r in known],
            "contrastWith": [r for r in t.get("contrast") or [] if r in known],
            "isPremium": truthy(t["premium"]) if "premium" in t else premium,
            "trendingScore": float(t.get("trending", 0)),
            "addedAt": str(t["added"]) if t.get("added") else None,
        })
    return terms


def build_chapters(raw: list[dict], known: set[str], errors: list[str]) -> list[dict]:
    chapters = []
    for c in raw:
        missing = [tid for tid in c["terms"] if tid not in known]
        if missing:
            errors.append(f"chapter {c['number']}: unknown terms {missing}")
        if len(c["terms"]) < 5:
            errors.append(f"chapter {c['number']}: needs at least 5 terms for its quizzes")
        chapters.append({
            "number": c["number"],
            "title": c["title"],
            "subtitle": c["subtitle"],
            "termIds": c["terms"],
            "isPremium": bool(c.get("premium", False)),
            "decorations": c.get("decorations", []),
        })
    return chapters


def truthy(value) -> bool:
    return str(value).strip().lower() in ("true", "yes", "1")


def strip_nones(value):
    if isinstance(value, dict):
        return {k: strip_nones(v) for k, v in value.items() if v is not None}
    if isinstance(value, list):
        return [strip_nones(v) for v in value]
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="validate only, don't write files")
    parser.add_argument("--strict", action="store_true", help="treat warnings as errors")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    config, raw_topics, raw_chapters = load_config()
    topics = build_topics(raw_topics, errors)
    topic_index = {t["id"]: t for t in topics}

    raw_terms: list[dict] = []
    for path in sorted((CONTENT / "terms").glob("*.yaml")):
        try:
            raw_terms.extend(load_terms_yaml(path))
        except yaml.YAMLError as exc:
            errors.append(f"{path.name}: {exc}")
    terms = build_terms(raw_terms, topic_index, errors, warnings)
    chapters = build_chapters(raw_chapters, {t["id"] for t in terms}, errors)

    for topic in topics:
        count = sum(topic["id"] in t["topics"] for t in terms)
        if count < 4:
            warnings.append(f"topic {topic['id']} has only {count} terms")

    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors or (args.strict and warnings):
        print(f"\n✗ {len(errors)} errors, {len(warnings)} warnings", file=sys.stderr)
        return 1

    free = sum(not t["isPremium"] for t in terms)
    print(f"✓ {len(terms)} terms ({free} free), {len(topics)} topics, {len(chapters)} chapters, {len(warnings)} warnings")
    if args.check:
        return 0

    version = int(config["version"])
    pack = strip_nones({
        "version": version,
        "generatedAt": dt.date.today().isoformat(),
        "terms": terms,
        "topics": topics,
        "chapters": chapters,
    })
    APP_RESOURCE.parent.mkdir(parents=True, exist_ok=True)
    APP_RESOURCE.write_text(json.dumps(pack, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    DIST.mkdir(parents=True, exist_ok=True)
    (DIST / f"pack-v{version}.json").write_text(json.dumps(pack, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (DIST / "manifest.json").write_text(json.dumps({"version": version, "url": f"pack-v{version}.json"}, indent=2), encoding="utf-8")
    print(f"→ wrote {APP_RESOURCE.relative_to(ROOT)} and {DIST.relative_to(ROOT)}/ (v{version})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
