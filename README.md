# Expense Tracker

A fully offline Android expense tracker. Speak an expense in English (e.g.
*bought 3 eggs for 50 taka*), native Android speech recognition converts it to
text, an on-device fine-tuned Gemma 3 270M model (ONNX Runtime) parses it into
structured JSON, and the result is saved to a local SQLite database.

## Architecture

```
Speech -> Android SpeechRecognizer -> text -> Gemma 3 270M (ONNX, on-device)
       -> JSON {item, quantity, amount, category} -> SQLite (sqflite) -> UI
```

## Prerequisites

- Flutter SDK
- Android SDK (minSdk 26)
- The ONNX model (see below)

## Model

The fine-tuned model is hosted on Hugging Face (not in this repo):

https://huggingface.co/ssgalib/expense-tracker-gemma

Download the FP16 ONNX model into `assets/model/`:

```bash
mkdir -p assets/model
curl -L https://huggingface.co/ssgalib/expense-tracker-gemma/resolve/main/model.onnx \
  -o assets/model/model.onnx
```

The tokenizer's compact binary derivatives (`assets/tokenizer/vocab.bin`,
`merges.bin`) are committed. They are generated from the HF `tokenizer.json`
by `scripts/preprocess_tokenizer.py`.

## Build & run

```bash
flutter pub get
flutter run                # on a connected device/emulator
```

## Tests

```bash
flutter test                                    # unit + widget tests
flutter test integration_test -d <device>       # on-device E2E (real inference)
```

## Notes

- The model is FP16 (537 MB): dynamic INT8 and weight-only INT4 quantization
  both broke the model's output (Gemma3's soft-capping is too sensitive).
- Inference runs an autoregressive greedy decode loop in Kotlin
  (`OnnxChannel.kt`), stopping at `<end_of_turn>` (token 106).
- The Dart side implements the Gemma BPE tokenizer (`lib/tokenizer/`) and a
  JSON repair step for occasionally-truncated model output.
