# AI-Cab — AI Vocabulary App: Product & Build Plan

> Status: **plan only** — nothing here is built yet.
> Inspiration: *Vocabulary — Learn words daily* (Monkey Taps), App Store id1084540807.
> Goal: a calm, swipeable daily feed that teaches the language of AI (LLMs, agents, robotics, policy) at three depth levels, with widgets doing most of the habit work.

---

## 1. Design breakdown (from the reference screenshots)

### 1.1 Visual language

| Token | Observed in reference | Proposed for AI-Cab |
|---|---|---|
| Background | Near-black, slightly warm (`~#121315`) | `bg/base #111214` |
| Surface (cards, rows) | Charcoal, one step up (`~#1D1E21`) | `bg/surface #1C1D20`, `bg/surface-2 #26272B` (pressed / secondary buttons) |
| Accent | Muted olive / moss (`~#4D5532` button, `~#6E7A52` hero card) | Keep one muted accent. Olive works; alternative "signal teal" `#4F7A74` to feel more "tech" — decide in design week |
| Text | Off-white primary, ~55% grey secondary | `text/primary #F2F2F0`, `text/secondary #8E8F93`, `text/tertiary #5C5D61` |
| Divider | 1px hairline, ~10% white | `stroke/hairline rgba(255,255,255,0.10)` |
| Type | Geometric grotesk (Google-Sans-like). Word ≈ 44–48pt medium; definition ≈ 22pt regular; large titles ≈ 40pt bold | SF Pro Rounded **or** a licensed geometric sans (e.g. Inter Display / Manrope). Word 46/Medium, definition 21/Regular, section header 28/Semibold |
| Shape | Big radii: cards 28–32pt, pills fully rounded, round 56pt icon buttons | `radius/card 28`, `radius/row 28`, `radius/pill 999` |
| Illustration | Monochrome isometric 3D objects tinted with the accent (heart w/ arrow, popsicle, skull book, cocktail glass) | Same style, AI subjects: chip, robot head, neural graph, token blocks, gavel (policy), telescope (research). One illustration per topic |
| Premium marker | Gem/diamond icon in a small circle on locked topics; gem button top-right of feed | Same pattern — consistent "pro" glyph |
| Material | Floating pill tab bar with blurred background; nav bar blurs on scroll | iOS 26 Liquid Glass / `.ultraThinMaterial` fallback |

**Mood:** dark, quiet, lots of empty space, one idea per screen. No gradients, no gamified confetti. This restraint is the product — copy it.

### 1.2 Screen-by-screen

**A. Learn feed (screenshot 3)**
- Full-screen vertical pager, one term per page, content vertically centered-ish (word sits at ~35% height).
- Stack: **word** → **pronunciation pill** (`/IPA/` + speaker icon, tap to speak) → hairline divider → **part of speech + definition** (`n. …`).
- Action row in lower third: **Share**, **Favorite (heart)**, **Info (i)** — outline icons, ~44pt, evenly spaced.
- Top-right: round **premium (gem)** button. No title bar.
- Bottom: floating pill **tab bar** — Learn · Topics · Progress · Settings; selected tab gets a darker inset pill.
- AI-Cab additions:
  - **Level switch** (Beginner / Builder / Research) — small segmented pill under the pronunciation pill, or long-press the word. Changes the definition text in place.
  - **Example sentence** in tertiary grey below the definition (the reference shows a faint quote line peeking under the modal in screenshot 1).
  - Optional "NEW this week" tag for pipeline-sourced terms.

**B. Review prompt modal (screenshot 1)**
- Dimmed feed behind, centered card: "Loving the app?" → primary olive **Love it!** (heart icon), secondary **Not really**, tertiary **Remind me later**.
- Soft pre-prompt: *Love it* → `SKStoreReviewController` / `requestReview`; *Not really* → in-app feedback form (keeps 1-star reviews off the store); *Later* → re-ask after N more sessions.
- Trigger: after ~3 days active + ≥15 cards seen + just favorited/shared something (positive moment).

**C. Share sheet (screenshot 2)**
- Full-height sheet with close (X) top-left.
- Rendered **share card**: word, hairline, definition, app badge chip ("V Vocabulary Builder" → "AI-Cab" badge).
- Action chips (horizontal scroll): **Watermark** toggle (pro), **Save to Photos**, **Themes** (card backgrounds — pro).
- Row of share targets: Instagram, Stories, X, Messenger, Facebook, … + system share.
- Implementation: SwiftUI view → `ImageRenderer` → PNG; Instagram Stories via `instagram-stories://share` pasteboard; others via `ShareLink`.

**D. Topics (screenshots 4–5)**
- Large title "Topics" + **Edit** button (choose which topics feed into Learn).
- **Recommended hero card**: full-width, accent background, "Recommended" white pill, illustration, eyebrow ("Name what's inside") + title ("Words for feelings").
- **Trending**: 2-column grid of square-ish cards (illustration top-left, gem top-right, two-line title bottom-left).
- **Category sections** ("Human", "World", …): full-width list rows (illustration, title, gem on right).
- Scroll behavior: large title collapses into a centered inline title over a blurred bar.
- AI-Cab mapping:
  - Recommended: *"Speak fluent AI" — The 50 words everyone's using*
  - Trending: **Agent Era**, **Vibe Coding**, **Reasoning Models**, **AI Drama & Headlines**
  - Section **Foundations**: How models learn · Data & training · Prompting · Safety & ethics
  - Section **Build**: LLM engineering · Agents & tools · RAG & retrieval · Evals · MLOps & infra
  - Section **Frontier**: Research math · Robotics · Multimodal · Hardware & chips
  - Section **World**: AI policy & law · Business of AI · AI culture & slang

**E. Screens not in the screenshots but in the reference app (to design ourselves)**
- **Onboarding** (5–7 steps): goal ("understand the news" / "talk to engineers" / "build with AI"), current level, topics, daily goal, notification permission, widget education, soft paywall.
- **Term detail (Info)** sheet: all three level definitions, analogy, example, etymology/origin ("coined by…"), related terms (chips → jump), source link, "first seen" date.
- **Progress**: streak, words learned, quiz accuracy, mastered vs. learning, favorites, history.
- **Practice / Quiz**: 3-question daily active-recall (definition → term multiple choice, term → definition, fill-the-blank).
- **Settings**: level, topics, reminders (count + time window), widget theme, app icon, restore purchases, feedback.
- **Paywall**: annual (with trial) + monthly + lifetime; benefits list (all topics, all levels, themes, no watermark, unlimited practice).
- **Widgets**: Lock Screen (inline + rectangular), Home Screen small / medium, StandBy.

### 1.3 Component inventory (build these first, everything else composes from them)

`TermCard` · `PronunciationPill` · `LevelSegment` · `IconActionRow` · `FloatingTabBar` · `PremiumBadge` · `HeroTopicCard` · `GridTopicCard` · `ListTopicRow` · `PrimaryButton / SecondaryButton` (pill) · `ModalCard` · `ShareCardView` · `ActionChip` · `SectionHeader` · `TopicIllustration`

---

## 2. Product scope

### MVP (v1.0)
1. Learn feed with 3-level definitions, pronunciation (TTS), favorite, share, info sheet.
2. Topics browser + topic selection (Edit) feeding the Learn algorithm.
3. Widgets: Lock Screen + Home Screen "Term of the Hour/Day".
4. Daily 3-question quiz + simple spaced-repetition for favorited/seen words.
5. Progress (streak, learned count) and Settings.
6. Remote content (weekly drops without App Store review), offline-first.
7. Premium via StoreKit 2 (locked topics, Research level, themes, watermark removal).
8. Review pre-prompt, reminders.

### Later (v1.x)
Interactive widgets (mark as known / next word), "In the news" context links, Apple Watch complication, search, custom collections, Android, localization.

---

## 3. Technical architecture

```
┌──────────────────────── iOS app (SwiftUI, iOS 17+) ────────────────────────┐
│  Features: Learn · Topics · Progress · Settings · Quiz · Paywall · Onboard │
│  Core: ContentRepository ─ SelectionEngine ─ SRS ─ Entitlements ─ Analytics│
│  Storage: SwiftData (terms cache, user progress)  +  bundled seed.json     │
│  App Group container ──► WidgetKit extension (reads shared snapshot)      │
└───────────────▲─────────────────────────────────────────────▲─────────────┘
                │ delta sync (version / updatedAt)            │ StoreKit 2
       Firebase Firestore (published terms, topics)    App Store
       Firebase Remote Config (feature flags, paywall copy, featured topic)
                ▲
                │ publish (approved only)
┌───────────────┴──────── Content pipeline (Python) ─────────────────────────┐
│ Scheduled job → collect → extract candidates → dedupe → LLM generate      │
│ (structured JSON) → validate → drafts collection → human review → publish │
└────────────────────────────────────────────────────────────────────────────┘
```

**Key decisions**
- **Native SwiftUI** — widgets, Lock Screen, App Intents, Live Activities need it; matches the reference's polish.
- **Offline-first**: ship ~250 terms in `seed.json`; Firestore is a delta source, never a hard dependency. App launches and works on airplane mode.
- **Firestore over a custom backend**: weekly content drops, no server to run. Read-only for clients via security rules. Keep user progress local (+ optional iCloud/CloudKit sync later) — no accounts in v1.
- **Widget data**: app writes a "next 24 terms" snapshot into the App Group; widget timeline rotates through it hourly. Widgets never hit the network.
- **Pronunciation**: `AVSpeechSynthesizer` for v1; store IPA in data. Upgrade path: pre-generated audio files in Firebase Storage.
- **Analytics**: Firebase Analytics or TelemetryDeck (privacy-friendly) — events: card_view, level_switch, favorite, share, quiz_answer, paywall_view, purchase.

### 3.1 Data model

```jsonc
// terms/{id}
{
  "id": "rag",
  "term": "RAG",
  "expansion": "Retrieval-Augmented Generation",
  "ipa": "/ræɡ/",
  "pos": "n.",
  "definitions": {
    "beginner":  "Letting an AI look things up before it answers, like an open-book exam.",
    "builder":   "Retrieve relevant chunks from a vector/keyword index and inject them into the prompt to ground the model's answer.",
    "research":  "Conditioning generation on retrieved documents p(y|x,z) to reduce hallucination and keep knowledge updatable without retraining."
  },
  "analogy": "An open-book exam instead of answering from memory.",
  "example": "We added RAG so the support bot cites our actual docs.",
  "origin": "Lewis et al., 2020 (Meta AI).",
  "level": "intermediate",              // home level: beginner | intermediate | pro
  "topics": ["llm-engineering", "rag"],
  "related": ["embedding", "vector-database", "hallucination", "grounding"],
  "sources": [{ "title": "...", "url": "..." }],
  "quiz": [{ "type": "mcq", "prompt": "...", "choices": ["..."], "answer": 0 }],
  "isPremium": false,
  "trendingScore": 0.72,
  "firstSeenAt": "2026-10-01",
  "status": "published",              // draft | in_review | published | retired
  "updatedAt": "2026-10-06T00:00:00Z",
  "contentVersion": 3
}

// topics/{id}
{ "id": "agents", "title": "Agent Era", "eyebrow": "Software that acts",
  "section": "trending", "illustration": "robot_hand", "isPremium": true, "order": 2 }

// local only (SwiftData): UserTermState
{ termId, seenCount, lastSeenAt, favorite, srsBox, nextReviewAt, known }
```

### 3.2 Feed selection engine (simple, deterministic)
Each feed batch of 20 =
- ~60% new terms from selected topics at the user's level (± one level),
- ~25% SRS reviews due (Leitner boxes 1→5: 1d, 3d, 7d, 14d, 30d),
- ~15% trending / "new this week".
Never repeat a term within 48h unless it's a due review.

### 3.3 Project structure (proposed)
```
ios/AICab/            App target (Features/, Core/, DesignSystem/, Resources/seed.json)
ios/AICabWidgets/     WidgetKit extension
ios/AICabTests/
pipeline/             Python content engine (sources/, generate/, schemas/, review/, publish/)
content/              Canonical term bank (YAML/JSON, git-reviewed) + illustrations
design/reference/     Inspiration screenshots (see §6)
docs/                 This plan, design tokens, content style guide
```
Making `content/` the source of truth in git (pipeline opens PRs, a merge publishes to Firestore) gives free review, history and rollback — recommended over reviewing in the Firebase console.

---

## 4. Content engine (pipeline)

1. **Collect** (weekly, GitHub Actions cron): arXiv (cs.CL, cs.LG, cs.AI, cs.RO listings), Hugging Face Papers daily, Hacker News (AI-tagged front page), OpenAI / Anthropic / Google DeepMind / Meta AI blogs & changelogs, optionally policy sources (EU AI Act updates, NIST).
2. **Extract candidates**: n-gram + LLM extraction of named concepts; frequency × recency × source-diversity → `trendingScore`.
3. **Dedupe**: normalize (case, acronyms ↔ expansions), compare against existing bank with embeddings; drop near-duplicates, flag "existing term, now trending" to bump score instead.
4. **Generate**: LLM call with a strict JSON schema (the `terms` shape above) + content style guide (definition length caps: beginner ≤ 25 words, builder ≤ 35, research ≤ 45; no hype words; analogy must be everyday).
5. **Validate**: schema check, length checks, banned-phrase list, related terms must exist, quiz answer must be in choices, second LLM pass as fact-checker producing a confidence score.
6. **Review**: open a PR to `content/` with a readable summary table; human approves/edits → merge.
7. **Publish**: on merge, script upserts to Firestore and bumps `contentVersion`; Remote Config flag sets the week's featured topic.

Target throughput: 10–20 new terms/week, < 15 min of human review.

---

## 5. Timeline

| Week | Deliverable | Done when |
|---|---|---|
| **0** (2–3 days) | Design system in Figma: tokens, components (§1.3), 5 core screens, 6 topic illustrations, widget mocks. Content style guide. Finalize the 250-term seed list. | Figma signed off; `seed.json` schema frozen |
| **1** | Xcode project, DesignSystem module, SwiftData models, seed import, **Learn feed** (pager, level switch, TTS, favorite) | Swipe through 250 seed terms offline at 60fps |
| **2** | **Topics** (hero / grid / list, Edit selection), **Info sheet**, **Share card** (render, save, Instagram Stories, themes), selection engine | Topic choice changes the feed; share image looks like the reference |
| **3** | **Widgets** (Lock Screen inline/rectangular, Home small/medium), App Group snapshot, **Quiz + SRS**, **Progress**, **Settings**, reminders | Widget rotates hourly with no app launch; daily quiz works |
| **4** | Firebase (Firestore delta sync, Remote Config, Analytics), pipeline: collectors + extraction + dedupe | New term added in Firestore appears in app without update |
| **5** | Pipeline: generation + validation + PR review flow + publish script + GitHub Actions cron | One end-to-end weekly drop reviewed and live |
| **6** | Onboarding, paywall + StoreKit 2, review pre-prompt, app icon(s), accessibility (Dynamic Type, VoiceOver), App Store assets, TestFlight | TestFlight build with 20 external testers |

Post-launch metrics to watch: D1/D7 retention, widget install rate, cards/session, share rate, trial→paid.

---

## 6. Design references — how to add yours

- Drop screenshots into `design/reference/<app-name>/` named by flow + order, e.g. `vocabulary/03-learn-feed.png`, `vocabulary/04-topics.png`. Commit and push from your machine; this cloud session will see them after a pull.
- Or attach them directly in chat (as you did) — I can save them into that folder.
- The five screenshots shared so far cover: review prompt, share sheet, learn feed, topics (top), topics (scrolled). **Missing to fully design:** onboarding, paywall, widgets, progress, settings, info/detail sheet, quiz.

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

1. **Name & accent color** — "AI-Cab" (vocab pun) keeps olive, or a more "tech" teal? Affects icon + illustrations.
2. **Level naming** — Beginner / Builder / Research vs. ELI5 / Engineer / Researcher.
3. **Premium line** — which topics/levels are free at launch (suggest: all Foundations + Beginner/Builder levels free; Research level, Frontier, themes, watermark off = Pro).
4. **Illustrations** — commission an illustrator vs. generate + clean up in-house (style must be consistent across ~25 topics).
5. **Accounts** — confirm no login in v1 (local progress + later iCloud sync).
