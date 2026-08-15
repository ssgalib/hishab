#!/usr/bin/env python3
"""Generate compact binary tokenizer files + reference test vectors for the app."""
import json
import struct
import sys
from pathlib import Path

TOKENIZER_JSON = Path("model/lora/tokenizer.json")
OUT_DIR = Path("assets/tokenizer")
VECTORS = Path("test/fixtures/tokenizer_vectors.json")

TEST_INPUTS = [
    "bought 3 eggs for 50 taka",
    "took a rickshaw to university, paid 40 taka",
    "recharged mobile 100 taka",
    "got electricity bill for 100 taka",
    "just bought 2.5 kg potato for 1200 taka",
    "spent 1500 on internet bill",
    "purchased 100 ml mustard oil for 25 taka",
    "bought  3  eggs",
    "hello, world!",
    "Cafe 50 taka",
    "50",
    "x",
    "1.5 L oil",
    "৳ currency",
    "bus fare",
]


def write_str(w, s: str) -> None:
    b = s.encode("utf-8")
    w.write(struct.pack("<I", len(b)))
    w.write(b)


def main() -> None:
    t = json.loads(TOKENIZER_JSON.read_text())
    vocab = t["model"]["vocab"]  # token -> id
    merges = t["model"]["merges"]  # [[left, right], ...] in rank order

    with open(OUT_DIR / "vocab.bin", "wb") as w:
        w.write(struct.pack("<I", len(vocab)))
        for token, tid in vocab.items():
            write_str(w, token)
            w.write(struct.pack("<i", tid))

    with open(OUT_DIR / "merges.bin", "wb") as w:
        w.write(struct.pack("<I", len(merges)))
        for rank, (left, right) in enumerate(merges):
            write_str(w, left)
            write_str(w, right)
            w.write(struct.pack("<I", rank))

    # Reference vectors
    from tokenizers import Tokenizer

    tok = Tokenizer.from_file(str(TOKENIZER_JSON))
    vectors = {}
    for inp in TEST_INPUTS:
        enc = tok.encode(inp, add_special_tokens=False)
        vectors[inp] = enc.ids

    VECTORS.parent.mkdir(parents=True, exist_ok=True)
    VECTORS.write_text(json.dumps(vectors, indent=2))

    print(f"vocab.bin: {Path(OUT_DIR/'vocab.bin').stat().st_size} bytes")
    print(f"merges.bin: {Path(OUT_DIR/'merges.bin').stat().st_size} bytes")
    print(f"vectors: {len(vectors)} entries")


if __name__ == "__main__":
    main()
