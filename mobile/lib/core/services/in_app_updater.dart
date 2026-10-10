import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Progress snapshot while an update APK downloads.
class UpdateDownloadProgress {
  final int received;
  final int total;
  final double bytesPerSecond;

  const UpdateDownloadProgress({required this.received, required this.total, required this.bytesPerSecond});

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  Duration? get remaining {
    if (bytesPerSecond <= 0 || total <= 0) return null;
    return Duration(seconds: ((total - received) / bytesPerSecond).ceil());
  }
}

/// Downloads the update APK inside the app and hands it to Android's installer,
/// so users never have to leave the app for a browser.
class InAppUpdater {
  static const _channel = MethodChannel('selisco/app_installer');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  static Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod('openInstallPermissionSettings');

  static Future<void> install(String apkPath) =>
      _channel.invokeMethod('installApk', {'path': apkPath});

  static Future<String> _apkPathFor(String version) async {
    final dir = await _channel.invokeMethod<String>('updateDirectory');
    return '$dir/selisco-$version.apk';
  }

  /// Downloads the APK for [version], reusing a previous complete download.
  /// Returns the local file path.
  static Future<String> download({
    required String url,
    required String version,
    required void Function(UpdateDownloadProgress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await _apkPathFor(version);
    final file = File(path);
    final doneMarker = File('$path.done');

    if (await file.exists() && await doneMarker.exists() && await _looksLikeApk(file)) {
      final size = await file.length();
      onProgress(UpdateDownloadProgress(received: size, total: size, bytesPerSecond: 0));
      return path;
    }

    // Remove older downloads so the cache doesn't fill up with past versions.
    for (final entity in file.parent.listSync()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }

    final partPath = '$path.part';
    final started = DateTime.now();
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

    await dio.download(
      url,
      partPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
        onProgress(UpdateDownloadProgress(
          received: received,
          total: total,
          bytesPerSecond: seconds > 0.3 ? received / seconds : 0,
        ));
      },
    );

    final part = File(partPath);
    if (!await _looksLikeApk(part)) {
      await part.delete().catchError((_) => part);
      throw const FormatException('The downloaded file is not a valid app package. Please try again.');
    }
    await part.rename(path);
    await doneMarker.writeAsString(version);
    return path;
  }

  /// APKs are zip files: at least a few MB and starting with "PK".
  static Future<bool> _looksLikeApk(File file) async {
    try {
      if (await file.length() < 1024 * 1024) return false;
      final raf = await file.open();
      final header = await raf.read(2);
      await raf.close();
      return header.length == 2 && header[0] == 0x50 && header[1] == 0x4B;
    } catch (_) {
      return false;
    }
  }
}
