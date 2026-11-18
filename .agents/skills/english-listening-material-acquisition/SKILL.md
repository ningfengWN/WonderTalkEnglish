---
name: english-listening-material-acquisition
description: Find, validate, legally acquire, annotate, and import authentic English listening materials with transcripts and synchronized audio into WonderTalkEnglish. Use for requests about lesson sourcing, audio downloads, subtitles, transcript alignment, lesson-library enrichment, and offline course packs.
---

# English Listening Material Acquisition

## Purpose

Build **usable, provenance-traceable, rights-aware lessons**, not merely a list of URLs. Preserve two independent learning paths:

- **Speaking**: everyday and family conversation, primarily listening, shadowing, retelling and interaction.
- **Understanding**: history, finance, earnings calls and Federal Reserve materials, primarily listening, reading and verifying conceptual understanding.

Work in `ningfengWN/WonderTalkEnglish`. Respect existing user profiles and course progress. Do not develop children's modules unless expressly requested; family resources can remain catalog-only.

## Existing project interfaces

- `WonderTalkEnglish/Lessons/learning_catalog_v1.json` — source-index catalog of 40 lessons (E01–E20, F01–F07, N01–N05, P01–P05, H01–H03).
- `WonderTalkEnglish/Lessons.swift` — `Lesson`, `LessonLine`, `CourseStore`.
- `WonderTalkEnglish/ContentView.swift` — material links, import UI and study screens.
- `tools/download_study_materials.py` — **best-effort personal/noncommercial** downloader for an allowlist (ELLLO and Open Yale Courses). It is not a universal downloader; dynamic site assets and terms may prevent downloads.

Always inspect the latest repository code before modifying it. Do not rely only on this skill for the exact current data schema.

## End-to-end workflow

### 1. Select and scope

Take requested `lesson_id` values from the catalog, or discover new lessons around a specified everyday scenario or knowledge topic. Keep search intent explicit: difficulty, accent, natural human speech, content length, interactive-dialogue versus lecture, and whether the goal is **personal offline study** or **App redistribution**. Do not silently assume a commercial license.

### 2. Find authoritative originals

Prioritize the originator's official course/IR/government/university page over copied transcripts and SEO mirrors. Record:

- canonical title, official page URL, publisher, author/speaker and publication/recording date when known
- skill level (editorial estimate clearly labeled if unverified), subject, intended training mode
- player/stream/download URL, actual file type, any official captions and transcript URLs
- language variety, duration if measured, content version, access date
- legal terms or license URL and whether audio/text/third-party material have different owners

Useful starting points: ELLLO, British Council LearnEnglish and LearnEnglish Kids, Open Yale Courses, Federal Reserve, issuer Investor Relations, SEC EDGAR, Reuters. A journalistic article is **not** a listening lesson unless real playable audio is confirmed. A company earnings release is **not** an earnings-call transcript.

### 3. Verify source integrity and availability

Open the primary page and check its title against the catalog. Confirm audio is genuinely audible (not just a player icon), content language, published date, transcript matching the recording, and whether download is explicitly offered. If any of these cannot be tested, mark it **unverified**, not **available**.

Classify each component separately: `verified_official_download`, `official_stream_only`, `third_party_with_provenance`, `missing`, `requires_access`, or `unverified`. A direct MP3 URL does not itself prove a right to redistribute or download.

### 4. License gate before retrieval

Decide permission separately for **personal use**, **noncommercial education**, **republication**, **editing/derivative work**, **commercial app distribution**, and **storage in a public repository**.

- Read the current publisher's license/terms and identify exceptions.
- ELLLO and Yale may permit some noncommercial educational uses, subject to the current conditions and third-party exceptions.
- British Council material is not automatically redistributable merely because personal downloads are offered.
- Reuters, publishers and corporate IR sites require specific terms assessment; do not assume earnings audio or news text can be repackaged.
- Federal Reserve material often has public-domain characteristics, with potential third-party exceptions.
- Never bypass paywalls, DRM, access controls, signed URLs or robots/terms restrictions.
- Do **not** commit third-party full transcripts, audio/video, or large extracts to a public repository without a clear applicable license or permission.

If rights cannot be established, create a **link-only course**, or use independently authored educational text/audio that does not impersonate the original.

### 5. Acquire original assets only when permitted

For approved personal noncommercial ELLLO/Yale material, from repository root on a machine with network access:

```bash
python3 tools/download_study_materials.py \
  --ids h01 h02 h03 e02 \
  --agree-noncommercial
```

Inspect `PrivateStudyDownloads/download_report.json` **and actual downloaded files**. The script saves source HTML and may discover downloadable audio; Yale text extraction is heuristic and needs human verification. Status codes and paths are not proof of transcript quality or a playable file. Never label a lesson `offline_ready` just because its page was saved.

For other providers, only use documented, authorized download/export endpoints. If no permission or stable download exists, retain the official URL rather than scraping or reproducing copyrighted content.

### 6. Deep-process transcript

Use **authorized** full transcript or a separately written/original script. Detect whether it is truly verbatim or only a summary. Normalize whitespace, punctuation, speakers and sentence boundaries while preserving spoken meaning. Avoid silently “correcting” informal spoken grammar. Capture disfluencies if they affect listening.

Record sentence-level `id`, `english`, optional learner-authored `chinese`, optional `speaker`, and time boundaries only after alignment. No fictitious verbatim transcripts, timestamps, translations or metadata.

### 7. Validate, align and package

- Probe real file duration and decodeability; avoid empty files, HTML saved as `.mp3`, zero-volume audio, mismatched segments and duplicate files.
- Align all transcript segments with the *same recording edition*. Each time range must satisfy `0 <= start < end <= duration`, with monotonically ordered segments unless overlap is justified.
- Test first, middle and last sentence playback and audio/speech compatibility on an actual Mac/iPhone simulator where available.
- For external personal-use assets, keep a private folder; import via the App's local audio and transcript workflows. For a redistributable App package, first establish valid rights to bundle.
- The iOS project currently separates bundled sample audio from imported MP3/M4A; do not claim remote URLs automatically play offline.

### 8. Curriculum enrichment

For **Speaking**: identify the useful communicative acts, 3–8 high-frequency expression targets, pronunciation/connected-speech challenges, a short dialogue roleplay, and a retelling prompt. For **Understanding**: key concepts, evidence/claims, vocabulary in context, 3–5 comprehension questions; English spoken recap is optional. Do not fabricate example quotes and attribute them to a source.

For each lesson, produce a short source note and a manifest with machine-readable acquisition status; use `references/lesson-manifest.example.json` as the shape reference. Distinguish **editor-authored exercises** from **publisher-owned content**.

### 9. Integrate without destructive data changes

Reuse catalog lesson IDs. Never reset the `CourseStore` or overwrite previously imported recordings, user translations, audio time boundaries or saved completion status. Apply a backward-compatible schema change, verify JSON decoding, and ensure link-only lessons show their source while missing audio does not lead to a dead play button.

### 10. Acceptance gates and reporting

Before saying “downloaded” or “usable in App”, verify:

1. URL still points to the intended original.
2. License permits the actual intended use.
3. File exists, has correct media type and decodes.
4. Transcript and audio genuinely match.
5. Alignment has no invalid spans.
6. Lesson appears in the App, and audio plays when installed.
7. Original recordings are distinguished from any synthetic demonstration audio.

Use one of these explicit completion states per lesson:
- `indexed` — metadata + official URL only
- `source_verified` — official source inspected
- `assets_acquired_private` — files downloaded locally for permitted private use
- `transcript_processed` — authorized matching text prepared
- `aligned` — verified sentence time spans
- `app_verified` — playback and learning UI checked on device/simulator

Report verified counts for each state and the blockers. Never promote a lesson to a state based on intent or an unexecuted script.

## Failure modes

- **Broken link**: search official site and update canonical URL with evidence; do not invent URLs.
- **Missing audio**: keep source-only or replace with another licensed listening lesson.
- **Missing transcript**: label unaligned; do not copy a copyrighted third-party transcript without rights. Optional local ASR can assist with permitted media, but must be checked against audio.
- **File blocked or inaccessible**: note what failed; do not bypass site restrictions.
- **Different versions**: never align one recording against another version's transcript.
- **Build unavailable**: say repository edits are committed but uncompiled/unverified.
- **License ambiguity**: do not bundle; preserve official link.

## Security and privacy

Do not commit credentials, cookies, paid-provider tokens, personal voice recordings, private transcripts, or downloaded copyrighted media. Keep personal study downloads out of the tracked source tree. Avoid exposing private study data in issue reports.

## Invocation examples

- “使用 english-listening-material-acquisition Skill，为 E01–E05 找到真人音频和官方逐字稿。”
- “按照英语素材获取 Skill，合法下载耶鲁前三讲，整理可用的听力材料。”
- “检查所有课程的音频、文字稿、版权许可和离线可用性。”
