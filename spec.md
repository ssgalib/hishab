# Expense Tracker App — Implementation Plan

## Overview

A fully offline Android expense tracker app built with Flutter. The user speaks an expense in English (e.g. "bought 3 eggs for 50 taka"), Android's native speech recognition converts it to text, a fine-tuned Gemma 3 270M model (running on-device via ONNX Runtime) parses the text into structured JSON, and the result is saved to a local SQLite database. The user can view, filter, and manage their expenses through a clean UI.

---

## Architecture

```
User speaks
    ↓
Android SpeechRecognizer API (native, no internet)
    ↓
Raw text string
    ↓
ONNX Runtime (on-device inference)
    ↓
Fine-tuned Gemma 3 270M model
    ↓
JSON string: { item, quantity, amount, category }
    ↓
Parse + validate JSON
    ↓
SQLite (via sqflite Flutter package)
    ↓
UI update
```

---

## Tech Stack

| Component | Technology |
|---|---|
| UI framework | Flutter (Dart) |
| Speech to text | Android native SpeechRecognizer via MethodChannel |
| On-device inference | ONNX Runtime for Android (onnxruntime-android) |
| Local database | SQLite via sqflite Flutter package |
| State management | Provider or Riverpod |
| Platform | Android only (minSdk 26 / Android 8.0+) |

---

## Model Preparation (done before app development)

### Step 1 — Merge LoRA weights into base model

Run in Google Colab after fine-tuning:

```python
from peft import AutoPeftModelForCausalLM
import torch

model = AutoPeftModelForCausalLM.from_pretrained(
    "./gemma-expense-final",
    torch_dtype=torch.float32,
)
merged_model = model.merge_and_unload()
merged_model.save_pretrained("./gemma-merged")
tokenizer.save_pretrained("./gemma-merged")
```

### Step 2 — Export to ONNX

```python
from transformers.onnx import export
from pathlib import Path
from transformers import AutoTokenizer
from optimum.exporters.onnx import main_export

main_export(
    model_name_or_path="./gemma-merged",
    output=Path("./gemma-onnx"),
    task="text-generation",
    opset=17,
)
```

Requires: `pip install optimum[exporters]`

### Step 3 — Quantize to INT8 (reduce size for mobile)

```python
from onnxruntime.quantization import quantize_dynamic, QuantType

quantize_dynamic(
    model_input="./gemma-onnx/model.onnx",
    model_output="./gemma-onnx/model_int8.onnx",
    weight_type=QuantType.QInt8,
)
```

### Step 4 — Verify model output before putting in app

```python
import onnxruntime as ort
import numpy as np

session = ort.InferenceSession("./gemma-onnx/model_int8.onnx")

prompt = """### Instruction:
Extract expense details from the sentence and return JSON only. No explanation.

### Input:
bought 3 eggs for 50 taka

### Output:
"""

inputs = tokenizer(prompt, return_tensors="np")
outputs = session.run(None, dict(inputs))
print(tokenizer.decode(outputs[0][0]))
# expected: {"item": "eggs", "quantity": "3 piece", "amount": 50, "category": "food"}
```

Final file to use in the app: `model_int8.onnx`
Place it in: `assets/model/model_int8.onnx`
Also copy tokenizer files to: `assets/tokenizer/`

---

## Flutter Project Structure

```
expense_tracker/
├── android/
│   └── app/
│       ├── src/main/
│       │   ├── kotlin/com/expense/tracker/
│       │   │   ├── MainActivity.kt          ← registers MethodChannels
│       │   │   ├── SpeechChannel.kt         ← handles STT via SpeechRecognizer
│       │   │   └── OnnxChannel.kt           ← loads and runs ONNX model
│       │   └── AndroidManifest.xml          ← RECORD_AUDIO permission
├── assets/
│   ├── model/
│   │   └── model_int8.onnx
│   └── tokenizer/
│       ├── tokenizer.json
│       ├── tokenizer_config.json
│       └── special_tokens_map.json
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── channels/
│   │   ├── speech_channel.dart              ← Dart side of STT MethodChannel
│   │   └── onnx_channel.dart               ← Dart side of ONNX MethodChannel
│   ├── models/
│   │   └── expense.dart                    ← Expense data class
│   ├── database/
│   │   └── db_helper.dart                  ← SQLite CRUD operations
│   ├── providers/
│   │   └── expense_provider.dart           ← state management
│   └── screens/
│       ├── home_screen.dart                ← main screen with mic button
│       ├── history_screen.dart             ← list of all expenses
│       └── summary_screen.dart             ← totals by category
└── pubspec.yaml
```

---

## Android Native Side

### AndroidManifest.xml

Add these permissions:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<!-- INTERNET is needed only if using online STT fallback; remove if fully offline -->
```

Set minimum SDK:

```xml
<uses-sdk android:minSdkVersion="26"/>
```

### MainActivity.kt

```kotlin
package com.expense.tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SpeechChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        OnnxChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
```

### SpeechChannel.kt

Handles speech recognition using Android's native `SpeechRecognizer`. Uses `RECOGNIZE_SPEECH` intent with `LANGUAGE_MODEL_FREE_FORM`. Returns the recognized string back to Flutter via MethodChannel result.

```kotlin
package com.expense.tracker

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class SpeechChannel(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "com.expense.tracker/speech")
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> startListening(result)
                "stopListening" -> stopListening(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        pendingResult = result
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                pendingResult?.success(matches?.firstOrNull() ?: "")
                pendingResult = null
            }
            override fun onError(error: Int) {
                pendingResult?.error("STT_ERROR", "Speech recognition error: $error", null)
                pendingResult = null
            }
            // all other RecognitionListener methods: empty override
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        speechRecognizer?.startListening(intent)
    }

    private fun stopListening(result: MethodChannel.Result) {
        speechRecognizer?.stopListening()
        result.success(null)
    }
}
```

### OnnxChannel.kt

Loads the ONNX model from assets, tokenizes the input prompt, runs inference, and returns the raw output string to Flutter.

```kotlin
package com.expense.tracker

import android.content.Context
import ai.onnxruntime.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.LongBuffer

class OnnxChannel(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "com.expense.tracker/onnx")
    private var session: OrtSession? = null
    private val env = OrtEnvironment.getEnvironment()

    init {
        loadModel()
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "runInference" -> {
                    val inputIds = call.argument<List<Int>>("input_ids") ?: emptyList()
                    runInference(inputIds, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun loadModel() {
        val modelBytes = context.assets.open("model/model_int8.onnx").readBytes()
        session = env.createSession(modelBytes, OrtSession.SessionOptions())
    }

    private fun runInference(inputIds: List<Int>, result: MethodChannel.Result) {
        try {
            val ids = inputIds.map { it.toLong() }.toLongArray()
            val shape = longArrayOf(1, ids.size.toLong())
            val tensor = OnnxTensor.createTensor(env, LongBuffer.wrap(ids), shape)
            val outputs = session!!.run(mapOf("input_ids" to tensor))
            val logits = outputs[0].value as Array<Array<FloatArray>>
            // get argmax token at each position (greedy decode)
            val tokenIds = logits[0].map { probs ->
                probs.indices.maxByOrNull { probs[it] }!!
            }
            result.success(tokenIds)
        } catch (e: Exception) {
            result.error("ONNX_ERROR", e.message, null)
        }
    }
}
```

Note: Full autoregressive decoding (generating token by token until EOS) should be implemented in OnnxChannel for production. The above is a single forward pass skeleton. The Flutter side should call runInference in a loop, appending each new token, stopping when EOS token id is generated.

### build.gradle (app level)

Add ONNX Runtime dependency:

```gradle
dependencies {
    implementation 'com.microsoft.onnxruntime:onnxruntime-android:1.17.0'
}
```

---

## Flutter Side

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.9.0
  provider: ^6.1.0
  permission_handler: ^11.0.0

flutter:
  assets:
    - assets/model/
    - assets/tokenizer/
```

### lib/models/expense.dart

```dart
class Expense {
  final int? id;
  final String item;
  final String? quantity;
  final int amount;
  final String category;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.item,
    this.quantity,
    required this.amount,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'item': item,
    'quantity': quantity,
    'amount': amount,
    'category': category,
    'created_at': createdAt.toIso8601String(),
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'],
    item: map['item'],
    quantity: map['quantity'],
    amount: map['amount'],
    category: map['category'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
```

### lib/database/db_helper.dart

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'expenses.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item TEXT NOT NULL,
            quantity TEXT,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap());
  }

  static Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final maps = await db.query('expenses', orderBy: 'created_at DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  static Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  static Future<Map<String, int>> getTotalByCategory() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM expenses GROUP BY category'
    );
    return {for (var r in result) r['category'] as String: r['total'] as int};
  }

  static Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
```

### lib/channels/speech_channel.dart

```dart
import 'package:flutter/services.dart';

class SpeechChannel {
  static const _channel = MethodChannel('com.expense.tracker/speech');

  static Future<String> startListening() async {
    final result = await _channel.invokeMethod<String>('startListening');
    return result ?? '';
  }

  static Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
  }
}
```

### lib/channels/onnx_channel.dart

Handles tokenization on the Dart side (load tokenizer.json, encode prompt, send token ids to native, receive output token ids, decode to string).

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class OnnxChannel {
  static const _channel = MethodChannel('com.expense.tracker/onnx');
  static Map<String, int>? _vocab;
  static Map<int, String>? _idToToken;

  // Load tokenizer vocab from assets
  static Future<void> loadTokenizer() async {
    final raw = await rootBundle.loadString('assets/tokenizer/tokenizer.json');
    final json = jsonDecode(raw);
    final vocab = json['model']['vocab'] as Map<String, dynamic>;
    _vocab = vocab.map((k, v) => MapEntry(k, v as int));
    _idToToken = _vocab!.map((k, v) => MapEntry(v, k));
  }

  static List<int> encode(String text) {
    // Simple whitespace tokenizer — replace with proper BPE if needed
    // For Gemma, use the SentencePiece vocab from tokenizer.json
    // This is a placeholder; implement BPE encoding from tokenizer.json
    throw UnimplementedError('Implement BPE encoding from tokenizer.json');
  }

  static String decode(List<int> ids) {
    return ids.map((id) => _idToToken?[id] ?? '').join('');
  }

  static Future<String> runInference(String inputText) async {
    const instruction =
        'Extract expense details from the sentence and return JSON only. No explanation.';
    final prompt = '### Instruction:\n$instruction\n\n### Input:\n$inputText\n\n### Output:\n';

    final inputIds = encode(prompt);

    // autoregressive loop: generate until EOS or max tokens
    final generatedIds = List<int>.from(inputIds);
    const maxNewTokens = 80;
    const eosTokenId = 1; // Gemma EOS token id

    for (int i = 0; i < maxNewTokens; i++) {
      final outputIds = await _channel.invokeListMethod<int>(
        'runInference',
        {'input_ids': generatedIds},
      );
      if (outputIds == null || outputIds.isEmpty) break;
      final nextToken = outputIds.last;
      if (nextToken == eosTokenId) break;
      generatedIds.add(nextToken);
    }

    // decode only the new tokens (after prompt)
    final newTokens = generatedIds.sublist(inputIds.length);
    return decode(newTokens);
  }
}
```

Important note: Tokenization (BPE encoding) must be implemented properly on the Dart side using the `tokenizer.json` vocab and merge rules from the Gemma tokenizer. Consider using a Dart SentencePiece library or porting the merge rules manually. Alternatively, implement tokenization in Kotlin (native side) and pass the token IDs through the MethodChannel.

### lib/providers/expense_provider.dart

```dart
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../database/db_helper.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _statusMessage = '';

  List<Expense> get expenses => _expenses;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String get statusMessage => _statusMessage;

  Future<void> loadExpenses() async {
    _expenses = await DBHelper.getAllExpenses();
    notifyListeners();
  }

  void setListening(bool value) {
    _isListening = value;
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await DBHelper.insertExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await DBHelper.deleteExpense(id);
    await loadExpenses();
  }
}
```

### lib/screens/home_screen.dart

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../channels/speech_channel.dart';
import '../channels/onnx_channel.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import 'history_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    OnnxChannel.loadTokenizer();
    context.read<ExpenseProvider>().loadExpenses();
  }

  Future<void> _handleMicPressed() async {
    final provider = context.read<ExpenseProvider>();

    // request mic permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      provider.setStatus('Microphone permission denied');
      return;
    }

    // start listening
    provider.setListening(true);
    provider.setStatus('Listening...');
    final spokenText = await SpeechChannel.startListening();
    provider.setListening(false);

    if (spokenText.isEmpty) {
      provider.setStatus('No speech detected');
      return;
    }

    provider.setStatus('Recognized: "$spokenText"\nProcessing...');
    provider.setProcessing(true);

    // run model
    final rawJson = await OnnxChannel.runInference(spokenText);

    provider.setProcessing(false);

    // parse JSON
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final expense = Expense(
        item: map['item'] as String,
        quantity: map['quantity'] as String?,
        amount: (map['amount'] as num).toInt(),
        category: map['category'] as String,
        createdAt: DateTime.now(),
      );
      await provider.addExpense(expense);
      provider.setStatus('Saved: ${expense.item} — ${expense.amount} taka');
    } catch (e) {
      provider.setStatus('Could not parse: $rawJson');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SummaryScreen())),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // status message
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              provider.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // mic button
          GestureDetector(
            onTap: provider.isListening || provider.isProcessing
                ? null
                : _handleMicPressed,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.isListening
                    ? Colors.red
                    : provider.isProcessing
                        ? Colors.orange
                        : Colors.blue,
              ),
              child: Icon(
                provider.isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            provider.isListening
                ? 'Tap to stop'
                : provider.isProcessing
                    ? 'Processing...'
                    : 'Tap to speak',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),

          // recent expenses list
          const SizedBox(height: 32),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.expenses.take(10).length,
              itemBuilder: (ctx, i) {
                final e = provider.expenses[i];
                return ListTile(
                  leading: _categoryIcon(e.category),
                  title: Text(e.item),
                  subtitle: Text(e.quantity != null
                      ? '${e.quantity} · ${e.category}'
                      : e.category),
                  trailing: Text('${e.amount} ৳',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon(String category) {
    const icons = {
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'utilities': Icons.bolt,
      'rent': Icons.home,
      'medicine': Icons.medical_services,
      'education': Icons.school,
      'entertainment': Icons.movie,
      'mobile': Icons.phone_android,
    };
    return Icon(icons[category] ?? Icons.attach_money);
  }
}
```

### lib/screens/history_screen.dart

Displays all expenses in reverse chronological order with swipe-to-delete. Groups by date. Each item shows item name, quantity, amount, and category icon.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses yet'))
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (ctx, i) {
                final e = expenses[i];
                return Dismissible(
                  key: Key(e.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      context.read<ExpenseProvider>().deleteExpense(e.id!),
                  child: ListTile(
                    title: Text(e.item),
                    subtitle: Text(
                      '${e.category} · ${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                    ),
                    trailing: Text('${e.amount} ৳',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }
}
```

### lib/screens/summary_screen.dart

Shows total spending per category as both a number and a visual bar. Pulls data from `DBHelper.getTotalByCategory()`.

```dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<String, int> _totals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final totals = await DBHelper.getTotalByCategory();
    setState(() => _totals = totals);
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = _totals.values.isEmpty
        ? 1
        : _totals.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: _totals.isEmpty
          ? const Center(child: Text('No data yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _totals.entries.map((e) {
                final fraction = e.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${e.value} ৳'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: fraction,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
```

### lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

---

## Known Implementation Challenges

### 1. Tokenization on Dart/Kotlin side
Gemma uses SentencePiece (BPE) tokenization. This must be reimplemented on the mobile side since there is no official Dart SentencePiece library. Two options:
- **Option A (recommended):** Implement tokenization in Kotlin using the Java SentencePiece bindings, expose it through a third MethodChannel called `com.expense.tracker/tokenizer`.
- **Option B:** Port the BPE merge rules from `tokenizer.json` to Dart manually.

The tokenizer files needed are: `tokenizer.json`, `tokenizer_config.json`, `special_tokens_map.json`. These are saved alongside the model in `assets/tokenizer/`.

### 2. Autoregressive decoding
The ONNX model generates one token at a time. The inference loop must:
1. Encode the full prompt to token IDs
2. Run the model to get logits for next token
3. Pick the highest probability token (greedy decoding)
4. Append token to sequence
5. Repeat from step 2 until EOS token (id=1) or max 80 tokens
6. Decode output tokens back to string

This loop runs entirely in OnnxChannel.kt.

### 3. ONNX model size
The INT8 quantized model will be approximately 150-300MB. This is large for an APK asset. Solutions:
- Ship the model separately and download on first launch (requires internet once)
- Use Android App Bundles with on-demand delivery
- Or include in APK if size is acceptable

### 4. JSON parse failures
The model may occasionally produce malformed JSON. The app must handle this gracefully — show the raw text to the user and let them dismiss or retry.

### 5. Inference speed
On mid-range Android hardware, inference may take 2-5 seconds per query. Show a loading indicator during processing. Test on target device early.

---

## Build & Run Steps

```bash
# create flutter project
flutter create expense_tracker
cd expense_tracker

# add dependencies to pubspec.yaml (see above)
flutter pub get

# copy model files
mkdir -p assets/model assets/tokenizer
cp path/to/model_int8.onnx assets/model/
cp path/to/tokenizer.json assets/tokenizer/
cp path/to/tokenizer_config.json assets/tokenizer/
cp path/to/special_tokens_map.json assets/tokenizer/

# build and run on connected Android device
flutter run
```

---

## Categories Reference

The model is trained to output exactly one of these category strings:

| Category string | Meaning |
|---|---|
| `food` | Groceries, meals, drinks |
| `transport` | Rickshaw, CNG, bus, uber, fuel |
| `utilities` | Electricity, gas, water, internet |
| `rent` | House, room, or flat rent |
| `medicine` | Drugs, pharmacy items |
| `education` | Books, tuition, course fees |
| `entertainment` | Movies, games, subscriptions |
| `mobile` | Recharge, data packs |

---

## JSON Output Schema

```json
{
  "item": "string — name of the purchased item or service",
  "quantity": "string or null — number with unit e.g. '2 kg', '3 piece', null if not mentioned",
  "amount": "integer — cost in taka",
  "category": "string — one of the 8 categories above"
}
```
