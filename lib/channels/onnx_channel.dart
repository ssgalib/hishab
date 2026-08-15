import 'package:flutter/services.dart';
import '../tokenizer/bpe_tokenizer.dart';

class OnnxChannel {
  static const _channel = MethodChannel('com.expense.tracker/onnx');

  // Fixed token ids for the chat-template prompt around the input text.
  // <bos><start_of_turn>user\nINSTRUCTION<end_of_turn>\n<start_of_turn>model\n
  static const List<int> _prefixIds = [
    2, 105, 2364, 107, // <bos><start_of_turn>user\n
    82138, 18766, 4889, 699, 506, 13315, 532, 994, 10434, 1186, 236761,
    2301, 15569, 236761, 108, // Extract expense details ... No explanation.\n\n
  ];
  static const List<int> _suffixIds = [
    106, 107, 105, 4368, 107, // <end_of_turn>\n<start_of_turn>model\n
  ];

  static GemmaBpeTokenizer? _tokenizer;

  static Future<void> loadTokenizer() async {
    _tokenizer ??= await GemmaBpeTokenizer.load();
  }

  static Future<String> runInference(String inputText) async {
    await loadTokenizer();
    final tok = _tokenizer!;
    final inputIds = [
      ..._prefixIds,
      ...tok.encode(inputText),
      ..._suffixIds,
    ];

    final generatedIds = await _channel.invokeListMethod<int>(
      'runInference',
      {'input_ids': inputIds, 'max_new_tokens': 60},
    );

    return tok.decode(generatedIds ?? const []);
  }
}
