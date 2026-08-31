# Hishab · হিসাব

**A fully offline, voice-first expense tracker for Android.** Speak an expense in
plain English — *"bought 3 eggs for 50 taka"* — and an on-device AI turns it into
a structured record. No account, no cloud, no internet. Everything stays on your phone.

<p align="center">
  <img src="screenshots/06-home.png" width="200" alt="Home" />
  <img src="screenshots/07-history.png" width="200" alt="History with category donut" />
  <img src="screenshots/08-edit-sheet.png" width="200" alt="Edit expense sheet" />
  <img src="screenshots/03-onboarding-voice-demo.png" width="200" alt="Onboarding voice demo" />
  <img src="screenshots/01-onboarding-welcome.png" width="200" alt="Onboarding welcome" />
</p>

## Requirements

**To use the app**

- **Android 8.0 (API 26) or newer** — phone or tablet (arm64-v8a, armeabi-v7a, x86_64)
- **~1.5 GB of free storage** — app (~150 MB) + parser model (~513 MB) + your data
- **4 GB of RAM or more recommended** — the parser runs a 270M-parameter model in memory
- **Microphone permission** — for voice entry (asked on first use)
- **Internet once** — to download the parser model (~513 MB, Wi-Fi recommended);
  everything after that is fully offline
- **English speech input** — voice entry uses Android's built-in SpeechRecognizer
  (en-US), which requires a speech service on the device (preinstalled on
  virtually all Android phones)

**To build from source**

- Flutter SDK (Dart ^3.13 — see `pubspec.yaml`) and the Android SDK
- No model files needed up front; the app downloads the parser on first run

## How it works

```
You speak
    ↓
Android SpeechRecognizer (on-device, en-US)
    ↓
Gemma 3 270M, fine-tuned — running locally via ONNX Runtime
    ↓
{ item, quantity, amount, category }
    ↓
SQLite (sqflite) → glass UI
```

The parser model runs entirely on the phone. Expense data never touches the
network — the only time the app uses the internet is the **one-time
parser-model download** (~513 MB from Hugging Face, with a terms-and-progress
screen, resumable). Existing v1.0 installs have their model migrated
automatically. Speech recognition currently uses Android's built-in
SpeechRecognizer; a custom ASR model fine-tuned on accented English is planned
to replace it.

## Features

- **Voice entry with live caption** — tap the mic, watch your words stream in,
  review the parsed expense, save. Tap to stop, silence auto-finalizes, 20s
  cap, friendly error recovery.
- **Review before save** — every parsed expense opens a confirm sheet; incomplete
  parses ("Almost there — no amount heard") land pre-filled for a quick fix. A
  price the model drops into `quantity` is moved back to `amount` automatically.
- **Manual entry** — a type-it sheet with amount pad, category chips, and date picker.
- **Home dashboard** — Today / This month totals, day/month/year grouping with
  per-group subtotals.
- **History** — This month / Last month / All time filters, item search,
  category donut chart with legend, CSV export via the Android share sheet,
  clear-all behind a confirmation.
- **Swipe to delete with undo**, everywhere.
- **First-run onboarding** — privacy promise, an interactive mic demo, and the
  microphone permission ask.
- **8 fixed categories** (food, transport, utilities, rent, medicine, education,
  entertainment, mobile), each with its own icon and color, tuned for everyday
  spending in Bangladesh. Currency is Taka (৳), integer amounts.

## Build & run

The APK is a shell (~148 MB) — the parser model is **not** bundled. On first
run the app walks through onboarding, then a one-time setup screen downloads
the model from
[Hugging Face](https://huggingface.co/ssgalib/expense-tracker-gemma)
(progress, cancel, and resume are supported). The model is stored in the
app's internal `files/models/` directory; v1.0 installs are migrated from
their bundled copy automatically.

```bash
flutter pub get
flutter run                # on a connected device/emulator
flutter build apk --release
```

## Tests

```bash
flutter test                                # unit + widget tests
flutter test integration_test -d <device>   # on-device E2E (real inference)
```

## Notes

- Two AI stages: **Android SpeechRecognizer** for speech (to be replaced by a
  custom fine-tuned ASR model) and the **Gemma 3 270M parser** (FP16 ~513 MB —
  INT8/INT4 quantization broke Gemma 3's soft-capping — downloaded once from
  Hugging Face instead of being bundled).
- Inference runs an autoregressive greedy decode loop in Kotlin
  (`OnnxChannel.kt`), stopping at `<end_of_turn>`.
- The Dart side implements the Gemma BPE tokenizer (`lib/tokenizer/`) and a
  JSON repair step for occasionally-truncated model output.
- Design system: warm parchment glass + lime accent + IBM Plex Mono, ported
  1:1 from the OpenDesign prototypes in `Ui-Ux-Fully-Offline-Voice-first-Android.zip`
  and `hishab-model-download.html`.
