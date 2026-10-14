# DeskBridge

An experimental Apple Vision Pro app that shows a virtual keyboard and trackpad on your real desk and uses them to drive a Mac.

The idea comes from the tabletop typing shown in the demo video on the Meta VR Glasses product page. DeskBridge is an independent project and is **not affiliated with Meta** or related to any Meta product or software. Apple, Vision Pro, visionOS and macOS are Apple trademarks.

Japanese version of the previous README: [README.ja.md](README.ja.md) (it may lag behind this file).

## Contents

1. [What it is, status, requirements, build and run](#1-what-it-is)
2. [Architecture](#2-architecture)
3. [Training-free design and Vera](#3-training-free-design-and-vera)
4. [Measured results (synthetic data only)](#4-measured-results-synthetic-data-only)
5. [Related work](#5-related-work)
6. [Privacy, safety, limitations, license](#6-privacy-and-safety)

## 1. What it is

DeskBridge has two parts: a **visionOS app** that detects touches on a virtual keyboard / trackpad placed on a desk, and a **Mac app (or command-line tool)** that turns the received events into real keyboard and pointer input on the Mac.

There are two input modes on the Vision Pro:

| Mode | How input is sensed | Requirements |
|---|---|---|
| **Shared Space** (main mode) | You place a volume on the desk by hand. visionOS standard direct taps and drags are the input. Works next to the normal Mac Virtual Display. | None beyond a normal install |
| **Full Space, automatic desk detection** | ARKit hand tracking and plane detection. Fingertip height is tracked per finger; touches are detected from the height time series. | Developer mode on the Vision Pro and the "Mac Virtual Display in Immersive Experiences" developer setting |

### Status

This is experimental software. Be precise about what has and has not been verified:

- **Implemented in this repository:** both input modes; virtual keyboard sizing for MacBook / external compact / external wide keyboards; US (ANSI) layout and a JIS layout model (work in progress, see [Layouts and adaptation](#layouts-and-calibration-free-adaptation-in-progress)); the Mac receiver with approval, accessibility permission and several key posting paths; an optional training-free typing pipeline (below); a recording mode for collecting real ARKit data.
- **Device verification:** How far on-device testing has gone is not recorded in the repository. The previous README says that delivery of keys to a specific target app (especially while the Mac Virtual Display is in use) and blind-typing stability are still being verified on a device; the switchable posting paths exist for that reason.
- **Synthetic data only:** everything about the training-free typing pipeline's *accuracy*. All numbers in this README come from a synthetic hand-motion generator plus simulated users, not from real ARKit recordings. Thresholds and correction sizes are expected to change once real recordings are analyzed.
- **Not implemented:** running the decoder and language model on the Vision Pro itself, a virtual HID device, a CHOICE (candidate picking) UI on the Vision Pro, a Vision Pro-side ledger.

### Requirements

- Apple Vision Pro (visionOS 26 or later) and an Apple silicon Mac (macOS 15 or later)
- Xcode 26, a physical Vision Pro, both devices on the same local network
- Full Space mode only: Vision Pro developer mode and the immersive Mac Virtual Display setting
- Accessibility permission for the Mac side

### Build and run

```sh
xcodegen generate
open DeskBridge.xcodeproj
```

1. In Signing & Capabilities, set your own Team and unique Bundle IDs for both the Mac and Vision targets.
2. Run `DeskBridgeMac` on the Mac and allow local network access.
3. Install `DeskBridgeVision` on the Vision Pro and allow local network, hand tracking and world sensing.
4. Pick the Mac in the Vision list, approve the connection on the Mac, grant accessibility permission, then press "enable input".
5. On the Vision side choose the keyboard type closest to your real one and show the input surface. Overlay the virtual keyboard on the real one and match size with the width and depth sliders. Settings for built-in and external keyboards are stored separately.
6. Move the virtual keyboard from the real keyboard to the desk with the volume handle and fix it with visionOS snap/lock; the placement is restored on the next launch. Turn on the light-blue contact-area display if alignment is hard. Press "Confirm placement and start input", then touch the keys directly and drag on the trackpad.
7. Connect the Mac Virtual Display from Control Center as usual.

For the Full Space automatic mode, enable the developer setting for the immersive Mac Virtual Display, press "start desk display", put all fingertips on the desk and press "record fingertip heights on the desk". This records a per-finger zero height and noise level.

#### Running the Mac side as a CLI

Instead of the window app you can run, in a terminal:

```sh
./scripts/run-mac-cli.sh
```

The script builds and signs the CLI on this Mac, installs it to `~/Applications/DeskBridgeCLI.app` and starts it. Do not run the window app and the CLI at the same time. If you have several development certificates, set `DESKBRIDGE_SIGN_IDENTITY` to the certificate's SHA-1 or name; without a certificate the build is ad-hoc signed and you may have to re-grant accessibility permission after each rebuild.

CLI commands (type them in the running CLI):

| Command | Meaning |
|---|---|
| `allow` / `deny` | Accept or reject the pending connection from the Vision Pro |
| `enable` / `disable` | Start or stop generating input events |
| `access` | Open the permission settings |
| `status` | State, received counts, key/pointer posted and observed counts |
| `apps` | List running apps with Bundle IDs |
| `target <bundle id>` / `target off` | Fix the key destination to one app (switches to `fixedPid`) / back to the frontmost app |
| `keypath <hid \| session \| annotatedSession \| frontmostPid \| fixedPid>` | Key posting path (default `frontmostPid`) |
| `pointerpath <hid \| session \| warp>` | Pointer posting path (default `hid`) |
| `testkey` / `testmove` | Post an `A` key / a cursor move locally, without the Vision Pro |
| `reset` | Reset posted/observed counters |
| `typing ...` | The experimental typing pipeline (see below) |
| `record ...` | Recording mode (see below) |
| `quit` | Exit |

Pid-addressed paths (`frontmostPid`, `fixedPid`, `warp` clicks) do not pass through the session event layers, so system shortcuts such as Spotlight or Cmd+Tab do not work with them.

`./scripts/list-event-taps.sh` lists system-wide event taps (layer, owning process, enabled, listen-only). Comparing its output with and without the Mac Virtual Display running helps to find the taps involved in the input hand-over described in the next section.

#### Why several key posting paths

While the Mac Virtual Display is in use and you look at a visionOS window, Mac input can be redirected to visionOS. It is not known in advance which posting path is exempt from that hand-over, so the Mac app and CLI can switch paths (the chosen path persists across launches except `fixedPid`). DeskBridge counts its own posted events with listen-only event taps on the session and annotated-session layers; its events carry a marker value in `eventSourceUserData` and only events with that marker are counted (nothing else is recorded). For pid-addressed paths a count of 0 at those layers is normal. A manual test procedure and a result table are in the Japanese README ([README.ja.md](README.ja.md), section "実機での切り分け手順"); the table is still to be filled in from device runs.

#### Tests

Pure logic can be tested without a device (run from the repository root):

```sh
swiftc Shared/DeskProtocol.swift Shared/DeskLayout.swift Tests/DeskLayoutTests.swift -o /tmp/deskbridge-tests && /tmp/deskbridge-tests
swiftc -O Shared/DeskProtocol.swift Shared/TextDecoder*.swift Tests/TextDecoderTests.swift -o /tmp/textdecoder-tests && /tmp/textdecoder-tests
scripts/run-typing-tests.sh        # prototype unit tests, golden pipeline tests, recording tests, etc.
```

`Tests/fixtures/golden_{en,romaji}.json` are written by `tools/proto/export_golden.py`; the Swift port reproduces the Python prototype's numbers in double precision (beam log-probabilities to 1e-9). The decoder source `Shared/TextDecoderDefaultModel.swift` embeds a roughly 58,000-line character model, so compiling takes a while.

## 2. Architecture

```
 Apple Vision Pro (Vision/)                        Mac (Mac/, MacCLI/)
 --------------------------------                  ------------------------------------------------
 Shared Space: RealityKit volume                   MacBridge (Multipeer advertiser, approval)
   direct taps / drags  ---------- InputEvent --->   -> CGEvent key/pointer posting
 Full Space: ARKit hands + planes                      paths: hid | session | annotatedSession |
   per-finger height time series                              frontmostPid | fixedPid
   DeskInteraction / ThreeLevelTapDetector           event-tap observation (own events only)
 LatticeTypingController ------- TapMessage ----->  TypingSession (serial queue, ledger store)
   (typing pipeline on/off)    <-- TypingControl --   TypingPipeline -> TextDecoder -> WordBoundaryChooser
 SessionRecorder / RecordingWriter                      -> LM scorer (localhost Python/MLX server)
   hand joints + detector decisions  -- chunks --->   KeyRecorder (real key times) + receive/verify
                                                      Typing ledger (JSONL) / TypingProfile (fold)
 ------------------------------------------------------------------------------------------------
 Shared/  (compiled into both apps and the CLI)
   DeskProtocol, DeskLayout (layouts, hit models, tap detection), Typing* (key model, ledger,
   profile, feedback, pipeline, adaptation), TextDecoder* (lattice decoder + models),
   WordBoundaryScorer, Recording* (protocol, chunked transfer), TrackingLifecycle
 ------------------------------------------------------------------------------------------------
 tools/  (Python, offline, not shipped)
   synth/ synthetic hands     proto/ prototype decoder + analysis of real recordings
   lmscore/ LM benchmark + localhost LM server     proto_grammar/ Vera grammar experiment (negative result)
```

Directories:

| Path | Contents |
|---|---|
| `Shared/` | Code used by every target: `DeskProtocol` (versioned `InputEvent`, `MacInputStatus`), `DeskLayout` (keyboard layouts, key hit model, tap detection incl. the three-valued detector), `TypingKeyModel`, `TypingProfile` (ledger and fold), `TypingFeedback`, `TypingPipeline`, `TypingProtocol` (`TapMessage`, `TypingControlMessage`), `TypingAdaptation`, `TextDecoder*` (lattice decoder, English / romaji base models, user n-gram mix), `WordBoundaryScorer`, `Recording*`, `TrackingLifecycle` (start/stop state machine for ARKit providers) |
| `Vision/` | visionOS app: scene and tracking, shared-space view, visual factory, `LatticeTypingController`, session recorder and recording UI |
| `Mac/`, `MacCLI/` | Mac window app and CLI: `MacBridge` (connection, event posting), `TypingSession` / `TypingPanel`, `KeyRecorder` / `RecordingPanel` |
| `docs/` | `HID_ARCHITECTURE.md` (virtual HID and remote workspace ideas), `RECORDING_FORMAT.md` (recording file format), and layouts/adaptation notes (see below) |
| `tools/` | Python prototypes and benchmarks, described in sections 3 and 4 |
| `Tests/`, `scripts/` | Swift test programs and fixtures; build/run/test scripts |

### Connection

Vision Pro and Mac talk over Multipeer Connectivity (`_deskbridge._tcp`, `encryptionPreference: .required`). The Mac asks for approval of each connecting peer and only generates input after accessibility permission is granted and input is explicitly enabled. Pointer movement is sent unreliably, everything else reliably.

### Two input modes

- **Shared Space:** a RealityKit volume with a single thin contact surface over the whole keyboard (the touch point is projected onto the key plan, which reduces picking the side of a neighbouring key from oblique touches). Only direct touch is accepted. visionOS reports at most one contact per hand, so this mode cannot guarantee fast ten-finger touch typing. Finger heights are not available here, so the typing pipeline below cannot be used in this mode.
- **Full Space:** ARKit hand and plane tracking gives five fingertips per hand. The default detector uses per-finger height time series instead of an absolute height. The key under the fingertip is chosen as the most likely one under per-key 2D Gaussians and a touch-typing finger-to-key prior; gaps between keys are assigned to a neighbouring key. The virtual keyboard follows the head position a little while the hands are away from the desk.

### Typing pipeline (experimental, off by default)

When enabled, Full Space typing goes through the following steps. The decision logic is a Swift port of the Python prototype in `tools/proto/` and is checked against it numerically.

1. **Tap detection per finger.** For each finger a height time series is built (fingertip Y minus that finger's zero height recorded at calibration). A peak of downward speed followed by a sudden stop gives a local minimum; it is confirmed two frames later. The finger is re-armed after rising 3 mm. Zero heights are tracked slowly from the bottoms of taps. The touch point is the xy average of the three frames from the minimum to the confirmation.
2. **Three-valued output: sure / maybe / none.** The detector does not force a yes/no. A tap is *sure* if drop, peak speed, stop time and single-frame drop fraction all pass strict thresholds, *maybe* if it passes looser ones, otherwise *none*. Thresholds scale with the measured height and speed noise (MAD) of the calibration second. A *maybe* tap that overlaps within 60 ms a more than 1.6 times deeper tap of a finger within two fingers on the same hand is dropped as sympathetic movement; for this, confirmed taps are held for 0.16 s and emitted in time order.
3. **Calibration correction.** The mean difference between the fingertip positions during calibration and the home-key centres (F D S A / J K L ;) is computed per hand and 0.9 times its z (towards the user) component is subtracted from touch points. This corrects the bias of hidden, over-bent fingertip estimates. Subtracting x was tried in the prototype and made things worse (it picks up hand drift).
4. **Per-key candidates.** Each tap becomes the top 6 keys with log-likelihoods: a 2D Gaussian per key (mean at the key centre, standard deviation proportional to key size) times a finger-to-key prior (own finger 1, same hand 0.3, other hand 0.1). The decoder receives all of these; it does not commit to one key. Shift is treated as "make the next character upper case or a symbol", and keys without a character (Esc, Tab, arrows) are excluded from character candidates.
5. **Word-level lattice decoder with a diverse n-best.** A beam search (width 40) scores the sum of tap log-likelihoods plus a weighted (0.4) character language model plus penalties for dropping a *maybe* tap (-3.0; *sure* taps cannot be dropped) and for inserting a character with no tap (-2.0). To get useful alternatives at word boundaries it additionally keeps the best hypothesis of up to 30 groups with different first words, so a boundary sees about 9 word candidates on average. A word is judged once four more taps have followed it.
6. **Word-boundary rescoring by a small LM.** All candidates for the first word are passed to the judge. A small language model (Qwen3.5-2B, 4-bit) scores each candidate plus the trailing space in the preceding context. The LM **returns scores for candidates only and the result is an index into the candidate list; it never generates text** and cannot produce a string that is not a path through the observed taps.

   ```
   logit_i = w_beam * beam_logp_i + LM_i / T
   p = softmax(logit)
   p_top >= tau_commit  -> commit the word
   otherwise            -> CHOICE: up to 3 candidates (stop at cumulative p 0.98); no auto-correction
   ```

   English uses `w_beam 2.0, T 1.4, tau 0.95`. Romaji uses a simple kana conversion of context and candidates, `T 3.2, tau 0.99`, and commits only if the LM's best equals the beam's best. If the LM does not answer within 0.4 s the LM term is dropped and the same rule runs on the beam posterior alone. Currently the LM runs as a Python/MLX HTTP server on `127.0.0.1` of the same Mac (`tools/lmscore/word_server.py`, `LocalBridgeWordBoundaryScorer`; it only connects to localhost and does not log typed text).
7. **Posting keys.** Committed words are turned into virtual key codes and posted with the selected path (hid, session, annotated session, to the frontmost pid, to a fixed pid). They are posted as physical key codes, so they also work with a Japanese IME in romaji input. Backspace and Return are handled as command keys only on a *sure* tap with a posterior of at least 0.8 over all keys, because they cannot be undone. The last word of a sentence is only entered after a space, Return, or 1.5 s idle.
8. **Feedback ledger.** Every tap, commit, label, confirmed word and revocation is appended to an append-only JSONL ledger on the Mac only (see [section 3](#3-training-free-design-and-vera)). Labels come from the user: a word deleted and retyped within 8 s is matched to the old word by edit distance (at most max(2, half the word length)) and gives *explicit* per-key labels; a word that stays gives an *implicit* label only if the commit passed a safety valve (`p_top >= 0.99` English, `0.999` romaji); text in an unresolved CHOICE is never learned from.
9. **Profile adaptation.** The user profile is derived by folding the ledger: per-key Gaussian (shrinkage with prior weight 20, hierarchical per finger bias), finger-to-key prior (pseudo-count 10), per-finger tap thresholds (from the median drop of positive examples, sent back to the Vision Pro), and a user n-gram built only from confirmed words. In the "learn while typing" start mode (calibration-free, `TypingProfileConfig.online`) an adaptation health monitor returns to the frozen prior if more than half of the last 40 words (after at least 20) needed correction.
10. **Recording mode.** To collect real ARKit data, the Vision Pro can record all 27 joints of both hands at maximum rate plus the detector's decisions (including candidates that missed the threshold). Mode A records the real Mac keyboard: the Mac logs real key down/up times from HID timestamps, and the two clocks are synchronized with an NTP-style round-trip measurement over the existing connection (at start, every 20 s, at stop; all samples kept). Mode B records typing of on-screen prompt sentences on the virtual keyboard. After stopping, the Vision Pro transfers the session to the Mac in 128 KiB frames with a per-frame and whole-file sha256 that the Mac verifies, re-requesting on mismatch. The file format is in [docs/RECORDING_FORMAT.md](docs/RECORDING_FORMAT.md); `tools/proto/analyze_recording.py` computes precision/recall against real keys and proposes new thresholds, to be confirmed on a separate session.

#### Typing pipeline usage

On the Mac (CLI): `typing on [en | romaji] [lm none | lm 8765]`, `typing status`, `typing off`, `typing pick <n>` (choose among the latest CHOICE), `typing ledger [wipe]`, `typing rollback <event id>`. Without an LM, start with `lm none` and the beam posterior alone decides. With the LM:

```sh
tools/lmscore/venv/bin/python tools/lmscore/word_server.py --kind 2B --port 8765
curl -s http://127.0.0.1:8765/health
```

The LM venv and weights live in the worktree `deskbridge-wt/nolearn`, not in this checkout, because they are large. On the Vision Pro: start desk display, record fingertip heights on the desk, switch on the typing decoder. The ledger is stored at `~/Library/Application Support/DeskBridge/ledger/` (`mac-en.jsonl`, `mac-romaji.jsonl`; non-US layouts and users get suffixes).

#### Planned: everything on the Vision Pro

The current split is: detection on the Vision Pro, decoding and LM on the Mac. The plan is to move decoding, the LM (MLX Swift, a small Qwen model) and the ledger onto the Vision Pro so that the Mac only receives committed keys. This is **not implemented and not verified**: there is no MLX Swift scorer yet (the `WordBoundaryScorer` protocol is the seam for it; the Qwen3.5 architecture mixes linear and full attention, whose layers cannot be trimmed in a KV cache), and on-device 0.8B / 2B latency and memory have not been measured. `Shared/` is Foundation-only for these parts so that the code can move.

#### Layouts and calibration-free adaptation (in progress)

Layouts: `KeyboardLayout.us` (ANSI) and `KeyboardLayout.jis` (the Mac Japanese keyboard, with its different shift symbols, tall Return, the extra key left of the right Shift, and Eisu/Kana keys) exist in `Shared/DeskLayout.swift`; the layout can be chosen automatically from the physical keyboard type the Mac reports, or manually. Ledgers are named per user x language x layout so that ledgers for different layouts are never mixed. A start mode without up-front calibration (frozen geometric prior, adapt while typing) sits next to the calibrate-first mode. This work is in progress and uncommitted; see [docs/LAYOUTS_AND_ADAPTATION.md](docs/LAYOUTS_AND_ADAPTATION.md) when it is available. Nothing in it has been measured on a device.

## 3. Training-free design and Vera

**DeskBridge does not train a touch model.** There is no neural network that maps hand joints to keys or characters, and no training set is needed to use it. Compare TouchInsight (section 5), which trains a network on egocentric video. In DeskBridge:

- touches are found by hand-written geometry on fingertip height time series;
- keys are chosen with explicit per-key Gaussians and a fixed finger prior, which are updated only by counting confirmed evidence;
- words are chosen by a beam search over a lattice and a character n-gram, then by a **frozen** pretrained small language model that is only used as a scorer. The LM is not fine-tuned and does not see touch data.

The thresholds and the synthetic hand generator were tuned by hand on a development set of simulated typists, not trained as a model. They have not been validated on real hands yet.

### What comes from Vera

[Vera](https://github.com/Ag3497120/vera) is a separate project by the same author: a training-free, deterministic, refusal-first structure for language. DeskBridge takes four **principles** from it, not code:

1. **Typed abstention.** A decision may say "not sure". Tap detection returns sure / maybe / none instead of forcing yes/no, and the word judge returns CHOICE instead of auto-correcting when its confidence is below the commit threshold.
2. **The model chooses only among candidates the structure produced.** The structure (taps -> key candidates -> lattice) builds the candidate set; the LM output is an index into it. The LM cannot invent a key or a word that the observed taps do not support.
3. **An append-only ledger with a deterministic, auditable fold.** All state that matters (taps, commits, labels, confirmed text, revocations) is appended to a ledger that is never rewritten. The profile is a pure function of the ledger (the same fold replays to the same result, checked by a digest), and a rollback is a new `revoke` record followed by re-folding, so any adaptation can be audited and undone.
4. **Learn only from confirmed or user-corrected evidence.** Labels come from the user's own corrections (explicit) or from words that survived untouched and passed a high-confidence valve (implicit). Unresolved CHOICE text is never learned from. The prototype showed why: a variant that accepted everything (NAIVE-SELF) was worse than no adaptation (23.6 % vs 17.9 % CER in the table below), because it reinforced its own mistakes.

**Vera code is not part of DeskBridge.** Vera's Japanese grammar layer (particle adhesion) was tried in the romaji word-boundary stage as an experiment in `tools/proto_grammar/` and gave no gain: on the evaluation set (6 simulated typists, 70 romaji sentences each) all confidence intervals of the differences included zero, and when the grammar layer changed the first word it broke more words than it fixed (for example 12 fixed vs 19 broken with the 2B LM). It was therefore not ported to Swift, and Swift code and the app contain no Vera dependency. `tools/proto_grammar/` is kept only as a documented negative result.

## 4. Measured results (synthetic data only)

**All numbers below are from synthetic hand motion** (`tools/synth/default.yaml` plus the observation layer in `tools/proto/tracking.py`) and from simulated users who notice and fix their mistakes with probability 0.6 to 1.0. Parameters were tuned on typists 0 to 3; reported numbers use typists 4 to 9 (70 sentences per language), one random seed. They are not real ARKit measurements and must not be put in a ranking against published figures: the prototype README quotes 4.8 to 5.7 % for contact-based baselines and 2.38 % (Meta TCN) and 2.9 % (TouchInsight) from the literature, but definitions, vocabularies and conditions differ, and those figures have not been re-checked here.

### Character error rate of the decoder

CER is the edit distance of the automatically committed text (CHOICE words left at the best candidate) to the reference, over the last 20 sentences, English and romaji combined (`tools/proto/README.md`):

| Condition | CER |
|---|---|
| Current detection + nearest key (baseline B0) | 60.5 % |
| B0 + language-model decoder (B1) | 52.9 % |
| Prototype pipeline, no adaptation | 17.9 % |
| + simulated realistic user feedback, SELF(BS) | 13.4 % |
| + accept everything, NAIVE-SELF (control) | 23.6 % |

With the small LM at word boundaries (last 20 sentences, `tools/proto/README_LM.md`, separate runs per language):

| | No adaptation | + LM (Qwen3.5-2B) + SELF(BS) | After user corrections |
|---|---|---|---|
| English | 14.9 % | **10.8 %** | 5.4 % |
| Romaji | 19.5 % | **12.1 %** | 5.9 % |

(The 10.8 % figure is the English-only row, so it is not a direct continuation of the combined 17.9 % -> 13.4 % chain above.) Over all 70 sentences without adaptation the LM lowers CER from 14.1 % to 11.4 % (English) and from 19.7 % to 17.9 % (romaji); the intervals of these differences do not include zero. For words whose correct path was in the n-best, the wrong-commit rate was 1.7 % with the LM against 8.5 % without (English).

**What limits accuracy is missed taps.** About 17 % of English words (about 34 % of romaji) have no correct path in the n-best at all, almost always because a tap was not detected (detection recall about 94 %; recall of *sure* taps alone about 62 %). The LM cannot repair that: 76 % of wrong English words (69 % romaji, LM 2B) are of this kind. On real ARKit data the missed-tap behaviour will differ, which is the largest uncertainty of the whole pipeline.

### Small LM comparison (`tools/lmscore/README.md`)

Task: pick the true word from 5 candidates (the truth plus 4 perturbations) at a word boundary; top-1 accuracy. Machine: Apple M1 Max (10-core CPU, 32-core GPU, 64 GB), measured on 2026-10-12 **while another agent's multi-process experiments kept the load average at 8 to 78, so latencies are inflated**. Latency is p50 / p95 in milliseconds for 5 candidates and 40 words of context, warm, with a naive implementation that recomputes the context for each candidate (a prefix KV cache is expected to help a lot and was measured separately in the prototype, not in this table).

English (n = 1137 trials = 379 word boundaries x 3 seeds):

| Model (runtime) | Weights | Top-1 (95% CI) | Latency p50 / p95 ms | Memory (RSS) |
|---|---|---|---|---|
| Qwen3.5-0.8B 4-bit (MLX) | 625 MB | 96.0 % (94.7-97.0) | 157 / 271 | 1.17 GB |
| **Qwen3.5-2B 4-bit (MLX)** | 1.72 GB | **97.7 %** (96.7-98.4) | 383 / 488 | 1.77 GB |
| Qwen3.5-4B 4-bit (MLX) | 3.03 GB | 98.0 % (97.0-98.6) | 1054 / 1182 | 2.61 GB |
| LiquidAI d1-3B (transformers fp16, MPS) | 6.25 GB | 95.3 % (94.0-96.4) | 153 / 326 | 6.96 GB (MPS) |
| LiquidAI d1-omni-600M (transformers fp16, MPS) | 2.35 GB (fp32 checkpoint) | 48.8 % (45.9-51.7), chance is 20 % | 28 / 39 | 0.91 GB |

Romaji (n = 775 trials = 267 word boundaries x 3 seeds; some kana rows have n = 259). "raw" is the text as romaji; "kana" is context and candidates converted to hiragana with a simple converter:

| Model | Top-1 raw | Top-1 kana | Latency p50 / p95 ms raw / kana |
|---|---|---|---|
| Qwen3.5-0.8B | 57.7 % | 76.1 % | 279 / 315 and 216 / 232 |
| Qwen3.5-2B | 65.2 % | 77.0 % | 724 / 825 and 550 / 748 |
| Qwen3.5-4B | 69.4 % | 76.4 % (n = 259) | 1797 / 2072 and 1454 / 1620 |
| d1-3B | 71.4 % | **80.9 %** (78.0-83.5) | 318 / 337 and 309 / 386 |
| d1-omni-600M | 34.2 % | 44.4 % (n = 259) | 33 / 41 and 33 / 47 |

(Top-1 values for the Qwen rows are the "sum of log-probabilities" scoring; the source table also lists a per-character-average scoring, which sometimes differs by several points.)

How to read it:

- English: Qwen3.5-2B is the best trade-off. Its lead over 0.8B (1.7 points) has overlapping intervals, but it is better calibrated, and at a commit threshold of 0.95 it auto-committed 92 % of words with 1 wrong commit in 1137. 4B gains 0.3 points at 2.7 times the latency.
- d1-3B is worse than Qwen 2B in English but best in romaji kana; d1-omni-600M is not usable for this task.
- The word-boundary populations are small and the 3 seeds are correlated, so the intervals are optimistic; the romaji differences among Qwen 2B / 4B and d1-3B (76 to 81 %) are not significant.
- **License note for the d1 models:** they use the LFM Open License v1.0, which is Apache-2.0-like but limits commercial use to entities with annual revenue under USD 10 million. The Qwen3.5 models used here are Apache-2.0. Check licenses before any commercial use.

Prototype latency with a KV cache (M1 Max, loaded machine) for one word boundary: Qwen3.5-2B p50 103 ms / p95 160 ms with in-sentence context only, and 166 / 374 ms with about 140 tokens of document context; 0.8B p50 about 40 to 55 ms. None of this has been measured on a Vision Pro.

## 5. Related work

- **TouchInsight** — Paul Streli, Mark Richardson, Fadi Botros, Shugao Ma, Robert Wang, Christian Holz. "TouchInsight: Uncertainty-aware Rapid Touch and Text Input for Mixed Reality from Egocentric Vision." ACM UIST 2024 (Meta Reality Labs and ETH Zürich). [arXiv:2410.05940](https://arxiv.org/abs/2410.05940), [project page](https://siplab.org/projects/TouchInsight).
  It models each touch location as a bivariate Gaussian with uncertainty and uses priors to infer the intended input. DeskBridge shares the idea of treating touch position as a distribution and passing the uncertainty on to a text decoder, but it uses explicit geometry and priors with no trained network, and works from ARKit joints rather than egocentric camera video.
- **TapType** — Paul Streli, Jiaxi Jiang, Andreas Rene Fender, Manuel Meier, Hugo Romat, Christian Holz. "TapType: Ten-finger text entry on everyday surfaces via Bayesian inference." CHI 2022. [DOI 10.1145/3491102.3501878](https://doi.org/10.1145/3491102.3501878), [arXiv:2410.06001](https://arxiv.org/abs/2410.06001).
  It fuses per-finger tap probabilities with an n-gram language model in a decoder. DeskBridge also decodes ten-finger taps with a language model, but with a word-level lattice of key candidates and a small LLM that rescores whole-word candidates at word boundaries, and its key probabilities come from geometry rather than a learned classifier.
- **Meta VR Glasses** — the demo video on the [Meta VR Glasses product page](https://www.meta.com/jp/vr-glasses/) was the inspiration for tabletop typing. DeskBridge has no relation to Meta, and nothing here is based on non-public information.
- **Vera** — [github.com/Ag3497120/vera](https://github.com/Ag3497120/vera), the source of the design principles in section 3.

Platform references (Apple): [Setting up access to ARKit data](https://developer.apple.com/documentation/visionos/setting-up-access-to-arkit-data), [Immersive spaces](https://developer.apple.com/documentation/swiftui/immersive-spaces), [InputTargetComponent](https://developer.apple.com/documentation/realitykit/inputtargetcomponent), [CGEvent.postToPid](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)), [Local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [visionOS Group Lab (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/8004/) (immersive Mac Virtual Display with developer settings).

## 6. Privacy and safety

Details are in [PRIVACY.md](PRIVACY.md). In short:

- No account, no external server. Input is sent as key codes, pointer movement, clicks and scrolls over an encrypted local Multipeer Connectivity session to a Mac that you approved. Events are not stored.
- The Mac asks for approval of each connection, and generates input only after the accessibility permission is granted **and** input is enabled. Always check who is connected while input is enabled.
- The Mac app does not capture the screen; it is independent of Apple's Mac Virtual Display video path.
- Shared Space mode does not read hand skeletons or camera images. Full Space mode processes ARKit hand and plane data on the Vision Pro and does not send it to the Mac, except in recording mode.
- **Typing pipeline ledger:** the Mac stores typed characters, tap positions and corrections in a JSONL ledger (owner read/write only) under Application Support. It is not sent to the Vision Pro or anywhere else, and can be deleted with `typing ledger wipe`. Do not use the pipeline while entering passwords or other secrets. The LM server is reached only on `127.0.0.1`.
- **Recordings:** a recording (only while you started one) stores all hand joints, fingertip positions and detector decisions on the Vision Pro and transfers them to your Mac. In mode A the Mac also stores the real key codes and times of everything typed in any app during the session, from which the text can be reconstructed; do not type passwords or private text. Mac key recording stops automatically after 45 minutes or when the Vision Pro connection is lost for more than 2 minutes. Delete with `record wipe` / the recording window. Analysis reports contain key-code statistics and timing, not the typed text; do not share the raw `mac-keys.jsonl`.

### Limitations

- The shared-space mode cannot recognize or measure a real keyboard with the camera and has no access to fingertip proximity, full hand skeletons or precise gaze and head position; the size is set by hand. Looking at the volume can still move focus and the cursor to it in ways direct-touch settings only partly prevent. Blind typing in this mode needs device verification.
- Full Space mode needs ARKit, Full Space and developer settings for the Mac Virtual Display. Apple Watch haptics cannot be sent directly from the Vision Pro (it would need an iPhone relay app and a watchOS app).
- The virtual keyboard has no tactile feedback. Modifier keys (Shift, Command, Option, Control) apply to the next key only. The trackpad supports drag-to-move and tap-to-click in shared space, and one-finger move, tap, long-press drag and two-finger scroll in Full Space. Accuracy and latency need device evaluation. **Do not use DeskBridge to enter passwords or sensitive information.**
- Typing pipeline: validated on synthetic data only; the LM runs on the Mac; no CHOICE UI on the Vision Pro; correction learning works only for fully deleted-and-retyped words; modifier keys are not handled in this pipeline; Japanese kana-kanji conversion results are not read (romaji is typed as is and the IME converts it).
- Posting key events with `CGEvent` is the current method; a virtual HID device and a remote workspace are not implemented (see [docs/HID_ARCHITECTURE.md](docs/HID_ARCHITECTURE.md)).

### License and notice

DeskBridge is released under the [MIT License](LICENSE), Copyright (c) 2026 DeskBridge contributors. DeskBridge is not affiliated with Meta, Apple, Alibaba (Qwen) or Liquid AI; product names belong to their owners. Models used by the optional LM benchmark and server are third-party and carry their own licenses (Qwen3.5: Apache-2.0; LiquidAI d1: LFM Open License v1.0). This document describes the source as it currently is; check communication and permission prompts on a real device before distributing a build.

The English text of this README was written with the help of AI.
