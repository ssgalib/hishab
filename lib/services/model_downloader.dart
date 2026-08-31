import 'dart:io';

/// Downloads the voice model over HTTPS into [savePath], with resume support
/// and progress reporting.
///
/// Integrity model: the download lands in a `.part` file and is renamed into
/// place only after the byte count matches the server's content-length (when
/// the server provides one). Transport integrity is TLS.
class ModelDownloader {
  ModelDownloader._();

  static const modelUrl =
      'https://huggingface.co/ssgalib/expense-tracker-gemma/resolve/main/model.onnx';

  /// Base URL of the speech (SenseVoice) model files on Hugging Face.
  static const speechBaseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main';

  /// Download [url] to [savePath].
  ///
  /// * Resumes from `savePath.part` via a Range request when present.
  /// * Calls [onProgress] with (receivedBytes, totalBytesOrNull) per chunk —
  ///   throttle in the caller.
  /// * Throws [ModelCancelledException] when [isCancelled] turns true,
  ///   [ModelDownloadException] for any network/size failure.
  static Future<void> download({
    required String savePath,
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
    HttpClient Function()? clientFactory,
    String? url,
  }) async {
    final part = File('$savePath.part');
    // The target directory may not exist yet (e.g. first speech-model
    // download) — create it or every write below fails.
    final parentDir = part.parent;
    if (!parentDir.existsSync()) parentDir.createSync(recursive: true);
    var resumeFrom = 0;
    if (await part.exists()) {
      resumeFrom = await part.length();
    }

    final client = (clientFactory ?? HttpClient.new)();
    try {
      final request = await client.getUrl(Uri.parse(url ?? modelUrl));
      if (resumeFrom > 0) {
        request.headers.set('range', 'bytes=$resumeFrom-');
      }
      final response = await request.close();

      // A 200 after asking for a range means the server ignored it — restart.
      var append = resumeFrom > 0 && response.statusCode == HttpStatus.partialContent;
      if (resumeFrom > 0 && !append && response.statusCode != HttpStatus.ok) {
        throw ModelDownloadException('HTTP ${response.statusCode}');
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw ModelDownloadException('HTTP ${response.statusCode}');
      }
      if (!append) resumeFrom = 0;

      final contentLength = response.contentLength; // -1 when unknown
      final int? totalBytes =
          contentLength >= 0 ? resumeFrom + contentLength : null;
      if (totalBytes != null && totalBytes <= 0) {
        throw ModelDownloadException('empty response');
      }

      var received = resumeFrom;
      final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in response) {
          if (isCancelled()) {
            throw ModelCancelledException();
          }
          received += chunk.length;
          sink.add(chunk);
          onProgress(received, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (totalBytes != null && received != totalBytes) {
        throw ModelDownloadException(
            'incomplete download: $received of $totalBytes');
      }
      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await part.rename(savePath);
    } finally {
      client.close(force: true);
    }
  }
}

class ModelCancelledException implements Exception {
  const ModelCancelledException();
  @override
  String toString() => 'Model download cancelled';
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => 'Model download failed: $message';
}
