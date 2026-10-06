# AI-Cab — AI Vocabulary App: Product & Build Plan

> Status: **plan only** — nothing here is built yet.
> Inspiration: *Vocabulary — Learn words daily* (Monkey Taps), App Store id1084540807.
> Reference screenshots: `design/reference/vocabulary/01–10`.
> Goal: a calm, swipeable daily feed that teaches the language of AI (LLMs, agents, robotics, policy) at three depth levels, with widgets, notifications and a chapter "Journey" doing the habit work.

The build runs in **3 phases** (§5):

| Phase | Theme | Weeks | Ships as |
|---|---|---|---|
| **1** | Foundation & core learning loop | 0–3 | Internal TestFlight |
| **2** | Content engine, sync & library | 4–6 | External TestFlight (beta) |
| **3** | Journey, practice, monetization & launch | 7–9 | App Store v1.0 |

---

## 1. Design breakdown

### 1.1 Two visual styles in the reference — and which one to use

The screenshots show two generations of the reference app:

| | **Style A — "Quiet"** (01–05) | **Style B — "Tactile"** (06–07) |
|---|---|---|
| Background | Near-black `#121315` | Warm charcoal `#2B2B2D` |
| Cards | Flat charcoal, no border | Mid-grey `#3A3A3C`, **2px black outline + hard offset bottom shadow** (looks pressable, like a physical tile) |
| Display type | Geometric sans | **Bold serif** headings ("Explore topics", "Feelings You Can't Explain"); sans for body/UI |
| Accents | Single muted olive | Teal `#8EC3BF` + coral `#EE8B7E` (with halftone-dot shadows) + cream `#F1EFE8` fills |
| Illustrations | Monochrome olive isometric objects | Cream/teal/coral isometric objects with thick black outlines |
| Locked marker | Gem in a circle | Outline padlock |
| Tabs | Learn · Topics · Progress · Settings | **Words · Topics · Journey · Practice · Profile** |

Onboarding (08–10) uses a third, **light** look: cream background `#F1EFE8`, near-white option pills, dark olive `#4B5230` full-width CTA, soft painted illustration.

**Recommendation:** use **Style B (tactile)** for the main app. It's more distinctive, the outlined tiles suit "learning blocks", and teal reads more "tech" than olive. Keep Style A's calm full-screen **word card** layout for the feed, and use the **light cream onboarding** as a gentle first impression before the dark app.

### 1.2 Design tokens (proposed)

| Token | Value |
|---|---|
| `bg/base` | `#2A2A2C` (feed may go darker: `#1A1B1D`) |
| `bg/surface` | `#3A3A3C` · `bg/surface-pressed` `#444446` |
| `stroke/outline` | `#0E0E0F`, 2pt · `shadow/hard` 0×4pt, `#0E0E0F`, no blur |
| `accent/primary` | Teal `#8EC3BF` (banners, progress, selected) |
| `accent/secondary` | Coral `#EE8B7E` (highlights, streak, "new") |
| `accent/cream` | `#F1EFE8` (illustration fills, onboarding bg) |
| `cta/onboarding` | Olive `#4B5230` on cream |
| `text` | primary `#F4F3EF`, secondary `#A3A3A6`, tertiary `#6C6C70`; on-cream `#1E1F1A` |
| Type | Display serif (e.g. *Source Serif 4 Bold* / *Fraunces*), UI sans (*Inter* / SF Pro). Word 46, chapter title 34 serif, large title 40 serif, body 19–21 |
| Radius | cards 28 · tiles 32 · pills 999 |
| Material | Floating pill tab bar, blurred (`.ultraThinMaterial` / iOS 26 Liquid Glass) |

### 1.3 Screen-by-screen

**Onboarding (08–10) — light cream theme**
1. **Welcome** — large illustration, headline + subhead, "Get started". AI-Cab: *"Speak fluent AI in 1 minute a day"* / *"Learn 250+ AI terms with a daily habit that takes a minute."* Illustration idea: two people under a tree whose canopy is a neural network.
2. **Self-assessment** — "How would you describe your vocabulary?" with 3 radio pills. AI-Cab: *"How familiar are you with AI?"* → "I hear the words but don't really get them" (Beginner) · "I use AI tools every day" (Builder) · "I build with or study AI" (Research). Sets default level.
3. *(add)* **Goal** — "Why are you here?" (follow the news · keep up at work · build AI products · career switch) → seeds topics.
4. *(add)* **Topics** — multi-select tiles.
5. **Daily goal / notifications** — live **notification preview card** (app icon, "AI-Cab", "*RAG (n.) – letting an AI look things up before answering*", "Now"), then rows: **How many** (−/3x/+ stepper), **Start at** 10:00 AM, **End at** 10:00 PM, CTA **"Allow and save"** → triggers the system permission prompt *after* the user has seen the value.
6. *(add)* **Widget education** — animated mock of the Lock Screen widget + "how to add".
7. *(add)* **Soft paywall** — skippable trial offer.

**Words feed (03; "Learn" in style A)**
- Full-screen vertical pager, one term per page: **word** → **pronunciation pill** (IPA + speaker) → hairline → **part of speech + definition** → faint example sentence.
- Action row: **Share · Favorite · Info**. Top-right premium button.
- AI-Cab addition: **level switch** (Beginner / Builder / Research) to swap the definition in place.

**Topics → "Explore topics" (07, with 04–05 as earlier variant)**
- Serif large title, **Edit** button, **Search** field.
- **Unlock banner** (teal, outlined, illustration of target+arrow): "Unlock everything — access all topics, words, themes, and remove ads". Hidden for subscribers.
- **2×2 library tiles**: **Favorites**, **Collections**, **Your own words**, **History**.
  - AI-Cab twist on *Your own words*: paste any AI term you've seen → app drafts the 3-level definition (LLM call), you save it to your deck.
- **Sections** ("About ourselves" → AI-Cab: *Foundations*, *Build*, *Frontier*, *World*) of large 2-column illustrated cards, **padlock** on premium.
- Earlier variant (04): "Recommended" hero card + "Trending" grid — keep **Trending** as the first section (Agent Era, Vibe Coding, Reasoning Models, AI Headlines).

**Journey (06) — new tab**
- One screen per **chapter**: letter-spaced eyebrow "CHAPTER 2", serif title "Feelings You Can't Explain".
- An isometric **zig-zag path of 6 outlined tiles** joined by dashed lines, each tile a lesson type (icon on tile):
  | Icon | Lesson | AI-Cab version |
  |---|---|---|
  | ★ | Learn the chapter's new words | 5–8 new terms in card format |
  | ➤ (send) | Use it — write/choose a sentence | "Which sentence uses *context window* correctly?" |
  | 🧩 puzzle | Match words ↔ definitions | Drag-match 4 pairs |
  | Aa | Recall / spell the term from its definition | Type or pick the term (acronym expansion too: "RAG = ?") |
  | ⇄ swap | Compare / contrast | **"X vs Y"** — fine-tuning vs RAG, GPU vs TPU, AGI vs ASI |
  | 🏆 | Chapter test | 10 mixed questions, unlocks next chapter |
- Decorative themed illustrations scattered around the path (emotion faces → AI-Cab: chips, robot heads, token blocks, speech bubbles).
- Completed tiles fill teal; current tile pulses; locked tiles are grey. Floating "^ Chapter 1" pill to jump back; next chapter title peeks at the bottom.
- AI-Cab chapter arc (example): 1 *Talking to Machines* · 2 *How Models Learn* · 3 *Inside the Transformer* · 4 *Making Models Useful* (RAG, tools) · 5 *Agents Take Action* · 6 *Measuring Smart* (evals, benchmarks) · 7 *Safety & Alignment* · 8 *The Hardware Underneath* · 9 *AI & the Law* · 10 *Frontier Research*.

**Practice tab** — daily 3-question quiz + review of SRS-due words + "practice favorites / a collection".

**Profile tab** — streak, words learned, mastered vs learning, chapter progress, settings (level, topics, reminders, widget theme, app icon, restore purchases, feedback).

**Review prompt (01)** — dimmed backdrop, card: "Loving the app?" → **Love it!** (→ `requestReview`), **Not really** (→ feedback form), **Remind me later**. Trigger at a positive moment (chapter complete, after a share/favorite, ≥3 active days).

**Share sheet (02)** — rendered share card (word, divider, definition, "AI-Cab" badge) + chips **Watermark** (pro), **Save to Photos**, **Themes** (pro) + targets Instagram, Stories, X, Messenger, Facebook, system share. Built with `ImageRenderer`.

**Not yet referenced (design ourselves):** paywall, widgets, term info sheet, Practice tab, Profile, collections detail, search results.

### 1.4 Component inventory

Foundation: `OutlinedCard` (outline + hard shadow, pressed state) · `PillButton` (primary/secondary/onboarding) · `RadioPill` · `StepperRow` · `TimeRow` · `SearchField` · `FloatingTabBar` (5 tabs) · `LockBadge` · `SectionHeader` (serif) · `Eyebrow` (letter-spaced caps)

Feature: `TermCard` · `PronunciationPill` · `LevelSegment` · `IconActionRow` · `UnlockBanner` · `LibraryTile` · `TopicCard` (large illustrated) · `JourneyTile` (isometric, 3 states) · `JourneyPath` · `NotificationPreview` · `ModalCard` · `ShareCardView` · `ActionChip` · `TopicIllustration`

---

## 2. Technical architecture

```
┌──────────────────────── iOS app (SwiftUI, iOS 17+) ─────────────────────────┐
│ Features: Onboarding · Words · Topics · Journey · Practice · Profile · Pay   │
│ Core: ContentRepository · FeedEngine · SRS · JourneyEngine · Entitlements   │
│       Notifications · Analytics                                             │
│ Storage: SwiftData (terms cache, user progress) + bundled seed.json         │
│ App Group container ──► WidgetKit extension (reads shared snapshot)        │
└───────────────▲──────────────────────────────────────────────▲─────────────┘
                │ delta sync (contentVersion / updatedAt)       │ StoreKit 2
   Firebase Firestore (terms, topics, chapters)         App Store
   Firebase Remote Config (flags, paywall copy, featured topic)
                ▲
                │ publish on merge
┌───────────────┴───── Content pipeline (Python, GitHub Actions cron) ────────┐
│ collect → extract candidates → dedupe → LLM generate (structured JSON)     │
│ → validate → PR to content/ → human review → merge → publish to Firestore  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key decisions**
- **Native SwiftUI** — required for Lock Screen/Home widgets, App Intents, polished isometric animations.
- **Offline-first** — ~250 terms + first 3 chapters bundled in `seed.json`; Firestore is only a delta source.
- **No accounts in v1** — progress local in SwiftData; iCloud (CloudKit) sync later.
- **Widgets** read a "next 24 terms" snapshot the app writes to the App Group; never hit the network.
- **Notifications** — local `UNCalendarNotificationTrigger`s, N per day spread evenly across the start–end window, rescheduled each app open with the next terms from the feed engine (no push server needed).
- **Pronunciation** — `AVSpeechSynthesizer` in v1; pre-generated audio later.
- **"Your own words" AI definitions** — call through a tiny serverless proxy (Firebase Function) so no API key ships in the app; rate-limited, premium-gated.

### 2.1 Data model

```jsonc
// terms/{id}
{
  "id": "rag",
  "term": "RAG",
  "expansion": "Retrieval-Augmented Generation",
  "ipa": "/ræɡ/",
  "pos": "n.",
  "definitions": {
    "beginner": "Letting an AI look things up before it answers, like an open-book exam.",
    "builder":  "Retrieve relevant chunks from a search index and inject them into the prompt to ground the answer.",
    "research": "Conditioning generation on retrieved documents p(y|x,z) to reduce hallucination and keep knowledge updatable without retraining."
  },
  "analogy": "An open-book exam instead of answering from memory.",
  "example": "We added RAG so the support bot cites our actual docs.",
  "origin": "Lewis et al., 2020.",
  "level": "intermediate",            // beginner | intermediate | pro
  "topics": ["llm-engineering"],
  "related": ["embedding", "vector-database", "hallucination"],
  "contrastWith": ["fine-tuning"],    // feeds the ⇄ "X vs Y" lesson
  "sources": [{ "title": "...", "url": "..." }],
  "quiz": [{ "type": "mcq", "prompt": "...", "choices": ["..."], "answer": 0 }],
  "isPremium": false,
  "trendingScore": 0.72,
  "firstSeenAt": "2026-10-01",
  "status": "published",            // draft | in_review | published | retired
  "updatedAt": "2026-10-06T00:00:00Z"
}

// topics/{id}
{ "id": "agents", "title": "Agent Era", "section": "trending",
  "illustration": "robot_hand", "isPremium": true, "order": 2 }

// chapters/{n}
{ "n": 2, "title": "How Models Learn", "termIds": ["training", "dataset", "..."],
  "lessons": ["learn", "use", "match", "recall", "compare", "test"],
  "isPremium": false, "decorations": ["chip", "token_blocks"] }

// local (SwiftData)
UserTermState  { termId, seenCount, lastSeenAt, favorite, srsBox, nextReviewAt, known, source }
Collection     { id, name, termIds[] }
JourneyState   { chapter, lessonIndex, scores[] }
Settings       { level, topics[], notifyCount, notifyStart, notifyEnd, theme }
```

### 2.2 Engines
- **FeedEngine** — batch of 20 = ~60% new terms (selected topics, user level ±1), ~25% SRS reviews due, ~15% trending/new. No repeat within 48h unless due.
- **SRS** — Leitner boxes 1→5 at 1d / 3d / 7d / 14d / 30d; right answer moves up, wrong resets to 1.
- **JourneyEngine** — generates lesson questions from chapter terms (`definitions`, `quiz`, `contrastWith`, `example`), passes at ≥80%.

### 2.3 Repo structure
```
ios/AICab/          App (Features/, Core/, DesignSystem/, Resources/seed.json)
ios/AICabWidgets/   WidgetKit extension
ios/AICabTests/
pipeline/           Python content engine (sources/, generate/, schemas/, publish/)
functions/          Firebase Functions ("your own words" proxy)
content/            Source-of-truth term bank + chapters (YAML/JSON, PR-reviewed)
design/reference/   Inspiration screenshots
docs/               Plan, tokens, content style guide
```

---

## 3. Content engine

1. **Collect** (weekly cron): arXiv (cs.CL/LG/AI/RO), Hugging Face Papers, Hacker News AI stories, AI lab blogs/changelogs, policy sources (EU AI Act, NIST).
2. **Extract** candidate terms; score = frequency × recency × source diversity → `trendingScore`.
3. **Dedupe** against the bank (normalize acronyms ↔ expansions, embedding similarity); existing terms just get a score bump.
4. **Generate** with an LLM using a strict JSON schema + style guide (beginner ≤ 25 words, builder ≤ 35, research ≤ 45; everyday analogies; no hype).
5. **Validate**: schema, lengths, banned phrases, related/contrast terms exist, quiz answer in choices, second-pass fact-check confidence.
6. **Review**: pipeline opens a PR to `content/` with a summary table → human edits/approves.
7. **Publish** on merge: upsert to Firestore, bump `contentVersion`, set the featured topic via Remote Config.

Target: 10–20 new terms/week, ≤15 min review.

---

## 4. Monetization

- **Free**: Foundations + Trending topics, Beginner & Builder levels, chapters 1–3, 1 widget style, 3 notifications/day, share with watermark.
- **Pro** (annual w/ 7-day trial · monthly · lifetime): all topics & chapters, Research level, themes, watermark off, unlimited practice, collections, "your own words" AI definitions, more notifications/day, widget themes.
- Paywall entry points: onboarding (soft), Unlock banner, locked topic/chapter tap, Research level tap, premium button on feed, share-sheet Watermark/Themes.
- No ads (the reference mentions "remove ads"; skipping ads keeps the calm feel).

---

## 5. Three-phase plan

### Phase 1 — Foundation & core learning loop (Weeks 0–3)
**Goal:** a beautiful offline app that teaches one word at a time, everywhere (app, widget, notification).

| Week | Work |
|---|---|
| **0** (2–3 days) | Figma: tokens (§1.2), components (§1.4), onboarding, Words, Topics, Journey, widgets. 6 topic illustrations in the outlined isometric style. Content style guide. Finalize 250-term `seed.json` + chapters 1–3. |
| **1** | Xcode project, DesignSystem module (OutlinedCard, PillButton, tab bar…), SwiftData models, seed import. **Words feed**: pager, level switch, TTS, favorite, info sheet. |
| **2** | **Onboarding** (welcome → familiarity → goal → topics → daily goal with notification preview → widget education). Local **notification scheduler**. **Explore topics** (search, library tiles: Favorites + History, topic sections, Edit selection) wired into FeedEngine. |
| **3** | **Widgets** (Lock Screen inline/rectangular, Home small/medium) via App Group snapshot. **Share sheet** (render card, Save to Photos, Instagram Stories, system share). Basic **Profile** (streak, learned count, settings). Accessibility pass (Dynamic Type, VoiceOver). |

**Exit criteria:** fresh install → onboarding → swipe 250 terms offline at 60fps; notifications arrive within the chosen window; widget rotates hourly without opening the app; internal TestFlight.

### Phase 2 — Content engine, sync & library (Weeks 4–6)
**Goal:** content refreshes weekly without App Store releases; users can organize and own their words.

| Week | Work |
|---|---|
| **4** | Firebase: Firestore delta sync, security rules (read-only), Remote Config, Analytics events (card_view, level_switch, favorite, share, notif_open, widget_tap). Pipeline: collectors + candidate extraction + dedupe. |
| **5** | Pipeline: LLM generation, validation, PR-to-`content/` review flow, publish-on-merge script, GitHub Actions weekly cron. First end-to-end drop. "New this week" tag + Trending section driven by `trendingScore`. |
| **6** | Library: **Collections** (create, add from feed, practice a collection), **Your own words** (manual entry + AI-drafted definitions via Firebase Function), full-text **Search**. **Practice tab v1**: daily 3-question quiz + SRS review queue. External TestFlight with ~20 testers. |

**Exit criteria:** a term merged on Monday shows up in the app and widget by Tuesday with no app update; review takes ≤15 min/week; testers using Collections/Practice; D1 retention baseline measured.

### Phase 3 — Journey, monetization & launch (Weeks 7–9)
**Goal:** structured progression that drives retention, plus revenue and a store-ready launch.

| Week | Work |
|---|---|
| **7** | **Journey tab**: isometric `JourneyPath`/`JourneyTile` with locked / current / done states, chapter header, "^ Chapter N" jump pill, decorations. **JourneyEngine** + all 6 lesson types (learn, use, match, recall, compare "X vs Y", chapter test). Chapters 1–10 authored (pipeline proposes, human curates). |
| **8** | **StoreKit 2** paywall + entitlements, **Unlock banner**, padlocks on topics/chapters, Research-level gate, share **Themes** + watermark toggle, widget themes, alternate app icons. **Review pre-prompt** at positive moments. Profile v2 (chapter progress, mastered vs learning). |
| **9** | Polish (haptics, tile press animations, empty states), performance, crash-free QA, privacy manifest, App Store screenshots/preview video, ASO keywords (AI terms, AI glossary, learn AI), launch posts built from share cards. **Submit v1.0.** |

**Exit criteria:** Journey chapters 1–10 playable; purchase/restore works in sandbox; App Store approval.

### Post-launch (v1.x)
Interactive widgets (mark known / next word), Apple Watch complication, StandBy widget, iCloud sync, "In the news" links on terms, A/B tests on onboarding & paywall, Android, localization.

**Metrics:** D1/D7/D30 retention, widget install %, notification open rate, cards/session, journey chapter completion, share rate, trial start → paid conversion.

---

## 6. Design references

Saved in `design/reference/vocabulary/`:

| File | Screen |
|---|---|
| 01-review-prompt | "Loving the app?" pre-prompt |
| 02-share-sheet | Share card + targets |
| 03-learn-feed | Word card feed (style A) |
| 04-topics / 05-topics-scrolled | Topics with Recommended + Trending (style A) |
| 06-journey-chapter | Journey chapter path (style B) |
| 07-explore-topics | Explore topics with unlock banner + library tiles (style B) |
| 08-onboarding-welcome | Welcome |
| 09-onboarding-level | Self-assessment |
| 10-onboarding-daily-goal | Notification goal setup |

**Still missing:** paywall, widgets (lock/home), term info sheet, Practice tab, Profile, a Journey lesson in progress, collection detail. Add more by attaching in chat or committing to that folder.

---

## 7. Starter word bank (seed — expand to 250+ in Week 0)

Target split: 🟢 Beginner 80 · 🟡 Intermediate 95 · 🔴 Pro/Research 80.

**🟢 Beginner — concepts & mindsets**
AI, machine learning, model, training, dataset, algorithm, neural network, chatbot, prompt, LLM, generative AI, token, context window, hallucination, bias, deepfake, AGI, open-source model, multimodal, inference, parameter, benchmark, fine-tuning, AI agent, copilot, text-to-image, voice clone, guardrails, alignment, jailbreak, slop, vibe coding, system prompt, temperature, knowledge cutoff, GPU, data center, automation, computer vision, speech recognition

**🟡 Intermediate — architecture & engineering**
transformer, attention, self-attention, embedding, vector database, RAG, chunking, reranking, tokenizer, BPE, few-shot prompting, chain-of-thought, function calling / tool use, structured output, MCP, agent loop, orchestration, evals, LLM-as-judge, RLHF, DPO, LoRA, quantization, distillation, mixture of experts, KV cache, prompt caching, latency vs throughput, streaming, grounding, reasoning model, test-time compute, synthetic data, data contamination, overfitting, epoch, loss function, gradient descent, learning rate, batch size, context engineering, prompt injection, red teaming, model card, open weights

**🔴 Pro / Research — systems, math & infrastructure**
scaling laws, Chinchilla-optimal, emergent abilities, backpropagation, softmax, cross-entropy, perplexity, positional encoding, RoPE, flash attention, grouped-query attention, speculative decoding, continuous batching, paged attention, tensor parallelism, pipeline parallelism, FSDP, ZeRO, mixed precision, FP8, KL divergence, PPO, GRPO, reward model, reward hacking, constitutional AI, mechanistic interpretability, superposition, sparse autoencoder, activation steering, grokking, double descent, state-space model, Mamba, diffusion model, flow matching, world model, sim-to-real, VLA (vision-language-action), compute governance, frontier model, responsible scaling policy, EU AI Act, model weights security

---

## 8. Open decisions

1. **Visual style** — Style B tactile (recommended) vs Style A quiet; teal+coral vs olive accent.
2. **Level names** — Beginner / Builder / Research vs ELI5 / Engineer / Researcher.
3. **Free vs Pro line** (§4) — especially whether Journey chapters beyond 3 are Pro.
4. **Illustrations** — commission an illustrator vs generate + clean up in-house (~25 topics + chapter decorations, one consistent outlined style).
5. **Tabs** — 5 tabs (Words · Topics · Journey · Practice · Profile) as in style B — confirm.
6. **"Your own words" AI drafting** — include in v1 (needs a small backend function) or defer.
