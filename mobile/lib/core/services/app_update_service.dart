import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String tagName;
  final String releaseName;
  final String releaseNotes;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseName,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class AppUpdateService {
  static const String currentVersion = '1.0.1';
  static const String _kLastCheckKey = 'last_update_check_timestamp';

  /// Compare two semantic version strings (e.g. "1.0.1" vs "1.0.0")
  static bool isVersionNewer(String latest, String current) {
    try {
      final cleanLatest = latest.trim().replaceAll(RegExp(r'^v'), '');
      final cleanCurrent = current.trim().replaceAll(RegExp(r'^v'), '');

      final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches latest update info from backend /api/version or fallback GitHub Releases
  static Future<AppUpdateInfo?> fetchLatestUpdateInfo() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    // 1. Try backend API first
    try {
      final backendUrl = '${ApiConstants.baseUrl}${ApiConstants.appVersion}';
      final res = await dio.get(backendUrl);
      if (res.statusCode == 200 && res.data is Map && res.data['success'] == true) {
        final d = res.data['data'] as Map<String, dynamic>;
        return AppUpdateInfo(
          latestVersion: d['version']?.toString() ?? '1.0.0',
          tagName: d['tagName']?.toString() ?? 'v1.0.0',
          releaseName: d['releaseName']?.toString() ?? 'Selisco Update',
          releaseNotes: d['releaseNotes']?.toString() ?? '',
          downloadUrl: d['downloadUrl']?.toString() ??
              'https://github.com/Clinton-Gilly/Selisco-Invoice-APP/releases/latest/download/app-release.apk',
        );
      }
    } catch (e) {
      debugPrint('Backend version check failed: $e');
    }

    // 2. Direct GitHub API fallback
    try {
      final res = await dio.get(
        ApiConstants.githubReleasesLatest,
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map<String, dynamic>;
        final tagName = d['tag_name']?.toString() ?? 'v1.0.0';
        final ver = tagName.replaceAll(RegExp(r'^v'), '');
        final assets = (d['assets'] as List<dynamic>?) ?? [];
        final apkAsset = assets.firstWhere(
          (a) => a['name']?.toString().endsWith('.apk') == true,
          orElse: () => null,
        );

        final downloadUrl = apkAsset != null
            ? apkAsset['browser_download_url']?.toString() ?? ''
            : 'https://github.com/Clinton-Gilly/Selisco-Invoice-APP/releases/latest/download/app-release.apk';

        return AppUpdateInfo(
          latestVersion: ver,
          tagName: tagName,
          releaseName: d['name']?.toString() ?? 'Version $ver',
          releaseNotes: d['body']?.toString() ?? 'New features and improvements.',
          downloadUrl: downloadUrl,
        );
      }
    } catch (e) {
      debugPrint('GitHub version check fallback failed: $e');
    }

    return null;
  }

  /// Automatically check for updates on startup (throttled to once every 4 hours)
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_kLastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Only check once every 4 hours
      if (now - lastCheck < 4 * 60 * 60 * 1000) return;
      await prefs.setInt(_kLastCheckKey, now);

      if (!context.mounted) return;
      await checkForUpdate(context, isAutomated: true);
    } catch (_) {}
  }

  /// Check for update and show dialog if available
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isAutomated = false,
    bool showNoUpdateSnackBar = false,
  }) async {
    final info = await fetchLatestUpdateInfo();

    if (!context.mounted) return;

    if (info != null && isVersionNewer(info.latestVersion, currentVersion)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgContext) => _UpdateDialog(info: info),
      );
    } else if (showNoUpdateSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already on the latest version (v$currentVersion)!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Available!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${info.tagName} (Current: v${AppUpdateService.currentVersion})',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What\'s New in this Update:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.releaseNotes.isNotEmpty
                        ? info.releaseNotes
                        : 'Bug fixes, performance improvements, and updated enterprise features.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppColors.success),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'All your existing invoices and settings will be preserved.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            final uri = Uri.parse(info.downloadUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
