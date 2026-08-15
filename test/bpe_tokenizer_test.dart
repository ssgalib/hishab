import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/tokenizer/bpe_tokenizer.dart';

void main() {
  late GemmaBpeTokenizer tokenizer;
  late Map<String, dynamic> vectors;

  setUpAll(() {
    final vocabBin = File('assets/tokenizer/vocab.bin').readAsBytesSync();
    final mergesBin = File('assets/tokenizer/merges.bin').readAsBytesSync();
    tokenizer = GemmaBpeTokenizer.fromBinaries(vocabBin, mergesBin);
    vectors = jsonDecode(
      File('test/fixtures/tokenizer_vectors.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('matches reference tokenization vectors', () {
    for (final entry in vectors.entries) {
      final input = entry.key;
      final expected = (entry.value as List).map((e) => e as int).toList();
      final actual = tokenizer.encode(input);
      expect(
        actual,
        expected,
        reason: 'mismatch for input: $input',
      );
    }
  });

  test('encodes special tokens inside text', () {
    final ids = tokenizer.encode('bought <end_of_turn> eggs');
    expect(ids, [109158, 236743, 106, 14318]);
  });

  test('applies byte fallback via utf8Encode helper', () {
    expect(GemmaBpeTokenizer.byteToken(0), '<0x00>');
    expect(GemmaBpeTokenizer.byteToken(0x61), '<0x61>');
    expect(GemmaBpeTokenizer.byteToken(0xff), '<0xff>');
  });

  test('normalizer replaces spaces with U+2581', () {
    final ids = tokenizer.encode('a b');
    expect(ids, [236746, 518]); // ['a', '▁b']
  });
}
