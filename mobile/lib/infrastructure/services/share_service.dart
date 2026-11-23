import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The phone's share sheet (WhatsApp, email…) for photos (D-141). Photos are fetched from their signed
/// links into the phone's temporary folder first, since the share sheet sends files, not links.
abstract class IShareService {
  /// Shares the pictures at [urls] (in order) with [text]; false when they couldn't be fetched.
  Future<bool> sharePictures(List<String> urls, {String? text});
}

class ShareService implements IShareService {
  ShareService({Dio? dio, Future<Directory> Function()? temp})
      : _dio = dio ?? Dio(),
        _temp = temp ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _temp;

  @override
  Future<bool> sharePictures(List<String> urls, {String? text}) async {
    final dir = await _temp();
    final files = <XFile>[];
    try {
      for (final (i, url) in urls.indexed) {
        final res = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        final type = res.headers.value(Headers.contentTypeHeader) ?? 'image/jpeg';
        final ext = type.contains('png') ? 'png' : (type.contains('webp') ? 'webp' : 'jpg');
        final file = File('${dir.path}/kaamnishaan_${DateTime.now().millisecondsSinceEpoch}_$i.$ext');
        await file.writeAsBytes(res.data ?? const []);
        files.add(XFile(file.path, mimeType: type));
      }
    } on Object catch (_) {
      return false;
    }
    await SharePlus.instance.share(ShareParams(files: files, text: text, sharePositionOrigin: _middle()));
    return true;
  }

  /// iPad shows the share sheet as a bubble and needs a place to point it at: the middle of the screen.
  static Rect _middle() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
  }
}
