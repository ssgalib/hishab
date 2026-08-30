import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/services/model_downloader.dart';

void main() {
  late HttpServer server;
  late Directory tmp;
  late String savePath;
  late Uint8List payload;

  /// Serves [payload]; honors Range requests unless [ignoreRange].
  Future<(String url, List<String> requests)> startServer({
    bool ignoreRange = false,
    int? overrideLength,
  }) async {
    final requests = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add(req.headers.value('range') ?? '<no range>');
      final range = ignoreRange ? null : req.headers.value('range');
      int start = 0;
      var partial = false;
      if (range != null && range.startsWith('bytes=')) {
        start = int.parse(range.substring(6).split('-').first);
        partial = true;
      }
      final length = overrideLength ?? payload.length;
      final end = length;
      req.response.statusCode =
          partial ? HttpStatus.partialContent : HttpStatus.ok;
      if (!partial) req.response.contentLength = end;
      if (partial) {
        req.response.contentLength = end - start;
        req.response.headers.set(
          'content-range',
          'bytes $start-${end - 1}/$length',
        );
      }
      if (req.method == 'HEAD') return req.response.close();
      await req.response.addStream(
        Stream.fromIterable([payload.sublist(start)]),
      );
      await req.response.close();
    });
    return ('http://127.0.0.1:${server.port}/model.onnx', requests);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('model_dl_test');
    savePath = '${tmp.path}/model.onnx';
    payload = Uint8List.fromList(List.generate(1000, (i) => i % 251));
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  test('downloads the full file and renames .part into place', () async {
    final (url, requests) = await startServer();
    final progress = <int>[];

    await ModelDownloader.download(
      url: url,
      savePath: savePath,
      onProgress: (r, t) => progress.add(r),
      isCancelled: () => false,
    );

    expect(requests.first, '<no range>');
    expect(File(savePath).readAsBytesSync(), payload);
    expect(File('$savePath.part').existsSync(), isFalse);
    expect(progress.last, payload.length);
  });

  test('resumes from an existing .part via a Range request', () async {
    final (url, requests) = await startServer();
    // Simulate 400 bytes already downloaded.
    await File('$savePath.part').writeAsBytes(payload.sublist(0, 400));

    await ModelDownloader.download(
      url: url,
      savePath: savePath,
      onProgress: (_, _) {},
      isCancelled: () => false,
    );

    expect(requests.first, 'bytes=400-');
    expect(File(savePath).readAsBytesSync(), payload);
  });

  test('restarts from scratch when the server ignores Range', () async {
    final (url, requests) = await startServer(ignoreRange: true);
    await File('$savePath.part').writeAsBytes(payload.sublist(0, 400));

    await ModelDownloader.download(
      url: url,
      savePath: savePath,
      onProgress: (_, _) {},
      isCancelled: () => false,
    );

    expect(requests.first, 'bytes=400-');
    expect(File(savePath).readAsBytesSync(), payload); // not doubled
  });

  test('cancel throws the cancel exception, never writes the final file',
      () async {
    final (url, _) = await startServer();

    await expectLater(
      ModelDownloader.download(
        url: url,
        savePath: savePath,
        onProgress: (_, _) {},
        isCancelled: () => true,
      ),
      throwsA(isA<ModelCancelledException>()),
    );
    expect(File(savePath).existsSync(), isFalse);
  });

  test('download reports progress and total from content-length', () async {
    final (url, _) = await startServer();
    int? seenTotal;
    int lastReceived = 0;

    await ModelDownloader.download(
      url: url,
      savePath: savePath,
      onProgress: (r, t) {
        seenTotal = t;
        lastReceived = r;
      },
      isCancelled: () => false,
    );

    expect(seenTotal, payload.length);
    expect(lastReceived, payload.length);
  });
}
