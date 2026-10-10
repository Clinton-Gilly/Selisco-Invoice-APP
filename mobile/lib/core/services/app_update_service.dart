import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  /// Installed versions below this cannot dismiss the update prompt.
  final String minVersion;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseName,
    required this.releaseNotes,
    required this.downloadUrl,
    this.minVersion = '0.0.0',
  });
}

class AppUpdateService {
  static const String _kLastCheckKey = 'last_update_check_timestamp';

  /// Installed version, read from the APK itself (pubspec `version:`) so it can't drift.
  static String currentVersion = '0.0.0';
  static bool _dialogOpen = false;

  static Future<String> loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (e) {
      debugPrint('Could not read app version: $e');
    }
    return currentVersion;
  }

  /// Compare two semantic version strings (e.g. "1.1.0" vs "1.0.1")
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
              'https://backend-tau-puce-j0499ijf6d.vercel.app/selisco.apk',
          minVersion: d['minVersion']?.toString() ?? '0.0.0',
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
            : 'https://backend-tau-puce-j0499ijf6d.vercel.app/selisco.apk';

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

  /// Automatically check for updates on startup
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_kLastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Only check once every 2 hours on background startup
      if (now - lastCheck < 2 * 60 * 60 * 1000) return;
      await prefs.setInt(_kLastCheckKey, now);

      if (!context.mounted) return;
      await checkForUpdate(context, isAutomated: true);
    } catch (_) {}
  }

  /// Automatically check for updates immediately on sign in / unlock
  static Future<void> checkOnSignIn(BuildContext context) async {
    try {
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
    if (currentVersion == '0.0.0') await loadCurrentVersion();
    final info = await fetchLatestUpdateInfo();

    if (!context.mounted) return;

    if (info != null && isVersionNewer(info.latestVersion, currentVersion)) {
      // The check runs on launch and after unlock; never stack two prompts.
      if (_dialogOpen) return;
      _dialogOpen = true;
      final mandatory = isVersionNewer(info.minVersion, currentVersion);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgContext) => _UpdateDialog(info: info, mandatory: mandatory),
      );
      _dialogOpen = false;
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

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final bool mandatory;

  const _UpdateDialog({required this.info, this.mandatory = false});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isLaunching = false;
  String? _errorMessage;

  Future<void> _handleUpdate() async {
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    final String apkUrl = widget.info.downloadUrl;
    final Uri apkUri = Uri.parse(apkUrl);
    final Uri portalUri = Uri.parse('https://backend-tau-puce-j0499ijf6d.vercel.app/download');

    bool opened = false;

    // Attempt 1: Open direct APK download in external browser
    try {
      opened = await launchUrl(apkUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    // Attempt 2: Open direct APK with platform default
    if (!opened) {
      try {
        opened = await launchUrl(apkUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    // Attempt 3: Open download page in external browser
    if (!opened) {
      try {
        opened = await launchUrl(portalUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    // Attempt 4: Open download page with platform default
    if (!opened) {
      try {
        opened = await launchUrl(portalUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    if (!mounted) return;

    if (opened) {
      if (widget.mandatory) {
        setState(() => _isLaunching = false);
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening browser to download APK... Follow prompts to install.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );
    } else {
      setState(() {
        _isLaunching = false;
        _errorMessage = 'Could not open browser automatically. Please tap "Copy Link" below to download manually.';
      });
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.info.downloadUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download link copied! Open Chrome and paste the URL to install.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                Text(
                  widget.mandatory ? 'Update Required' : 'Update Available!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'v${AppUpdateService.currentVersion}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Icon(Icons.arrow_forward, size: 12, color: AppColors.textSecondary),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'v${widget.info.latestVersion}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
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
            if (widget.mandatory) ...[
              const SizedBox(height: 8),
              const Text(
                'This version is no longer supported. Please install the update to keep using the app.',
                style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
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
                    widget.info.releaseNotes.isNotEmpty
                        ? widget.info.releaseNotes
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_errorMessage != null)
          TextButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Link'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        if (!widget.mandatory)
          TextButton(
            onPressed: _isLaunching ? null : () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ElevatedButton.icon(
          onPressed: _isLaunching ? null : _handleUpdate,
          icon: _isLaunching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(
            _isLaunching ? 'Opening...' : 'Update Now',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
