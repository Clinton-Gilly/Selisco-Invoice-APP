import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_update_service.dart';
import 'in_app_updater.dart';

enum _Phase { downloading, needsPermission, readyToInstall, error }

/// Full-screen updater: downloads the new APK inside the app with a live
/// progress ring and "what's new" cards, then opens Android's installer.
class UpdateDownloadScreen extends StatefulWidget {
  final AppUpdateInfo info;
  final bool mandatory;

  const UpdateDownloadScreen({super.key, required this.info, this.mandatory = false});

  static Future<void> open(BuildContext context, AppUpdateInfo info, {bool mandatory = false}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => UpdateDownloadScreen(info: info, mandatory: mandatory),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
        ),
      ),
    );
  }

  @override
  State<UpdateDownloadScreen> createState() => _UpdateDownloadScreenState();
}

class _UpdateDownloadScreenState extends State<UpdateDownloadScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _bgTop = Color(0xFF1E1B4B);
  static const _bgBottom = Color(0xFF0F172A);
  static const _accent = Color(0xFF818CF8);
  static const _accent2 = Color(0xFF22D3EE);
  static const _success = Color(0xFF34D399);

  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  final CancelToken _cancelToken = CancelToken();
  _Phase _phase = _Phase.downloading;
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(received: 0, total: 0, bytesPerSecond: 0);
  String? _apkPath;
  String? _error;
  late final List<String> _highlights = _parseHighlights(widget.info.releaseNotes);
  int _highlightIndex = 0;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _highlightTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _highlights.length > 1) {
        setState(() => _highlightIndex = (_highlightIndex + 1) % _highlights.length);
      }
    });
    _startDownload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    _highlightTimer?.cancel();
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the "Install unknown apps" settings page: carry on.
    if (state == AppLifecycleState.resumed && _phase == _Phase.needsPermission) {
      _installIfAllowed();
    }
  }

  static List<String> _parseHighlights(String notes) {
    final lines = notes
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^\s*[-•*]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isEmpty ? ['Performance improvements and bug fixes.'] : lines;
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _error = null;
    });
    try {
      final path = await InAppUpdater.download(
        url: widget.info.downloadUrl,
        version: widget.info.latestVersion,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      _apkPath = path;
      setState(() => _phase = _Phase.readyToInstall);
      await Future.delayed(const Duration(milliseconds: 900)); // let the success animation land
      await _installIfAllowed();
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() {
        _phase = _Phase.error;
        _error = e is DioException
            ? 'Download interrupted. Check your internet connection and try again.'
            : e.toString().replaceFirst(RegExp(r'^\w+Exception: '), '');
      });
    }
  }

  Future<void> _installIfAllowed() async {
    if (_apkPath == null) return;
    if (!await InAppUpdater.canInstallPackages()) {
      if (mounted) setState(() => _phase = _Phase.needsPermission);
      return;
    }
    if (mounted) setState(() => _phase = _Phase.readyToInstall);
    try {
      await InAppUpdater.install(_apkPath!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'Could not open the installer: $e';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    await launchUrl(Uri.parse(widget.info.downloadUrl), mode: LaunchMode.externalApplication);
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  String _eta(Duration? d) {
    if (d == null) return '';
    if (d.inSeconds < 60) return '${d.inSeconds}s left';
    return '${d.inMinutes}m ${d.inSeconds % 60}s left';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(flex: 2),
                  _buildRing(),
                  const SizedBox(height: 28),
                  _buildStatus(),
                  const Spacer(flex: 2),
                  _buildHighlights(),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              'v${AppUpdateService.currentVersion}  →  v${widget.info.latestVersion}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const Spacer(),
          if (!widget.mandatory)
            IconButton(
              tooltip: 'Cancel update',
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildRing() {
    final done = _phase == _Phase.readyToInstall || _phase == _Phase.needsPermission;
    final target = done ? 1.0 : _progress.fraction;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_pulse, _spin]),
          builder: (context, _) {
            return SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: value,
                  pulse: _pulse.value,
                  spin: _spin.value,
                  done: done,
                  error: _phase == _Phase.error,
                ),
                child: Center(child: _buildRingCenter(value, done)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRingCenter(double value, bool done) {
    if (_phase == _Phase.error) {
      return const Icon(Icons.wifi_off_rounded, color: Color(0xFFFCA5A5), size: 54);
    }
    if (done) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (_, s, _) => Transform.scale(
          scale: s,
          child: const Icon(Icons.check_rounded, color: _success, size: 84),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(value * 100).floor()}%',
          style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        Text(
          _progress.total > 0 ? '${_mb(_progress.received)} / ${_mb(_progress.total)} MB' : 'Connecting…',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatus() {
    late final String title;
    late final String subtitle;
    switch (_phase) {
      case _Phase.downloading:
        title = 'Downloading update';
        final bps = _progress.bytesPerSecond;
        final speed = bps <= 0
            ? ''
            : bps < 1024 * 1024
                ? '${(bps / 1024).round()} KB/s'
                : '${_mb(bps.round())} MB/s';
        subtitle = [speed, _eta(_progress.remaining)].where((s) => s.isNotEmpty).join('  •  ');
        break;
      case _Phase.readyToInstall:
        title = 'Ready to install';
        subtitle = 'Tap "Install" on the next screen. Your data stays safe.';
        break;
      case _Phase.needsPermission:
        title = 'One quick permission';
        subtitle = 'Allow Selisco to install updates, then come back here.';
        break;
      case _Phase.error:
        title = 'Update paused';
        subtitle = _error ?? 'Something went wrong.';
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(_phase),
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            subtitle.isEmpty ? 'Starting…' : subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _accent2, size: 16),
              const SizedBox(width: 6),
              Text(
                "WHAT'S NEW IN v${widget.info.latestVersion}",
                style: const TextStyle(color: _accent2, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Align(
                key: ValueKey(_highlightIndex),
                alignment: Alignment.topLeft,
                child: Text(
                  _highlights[_highlightIndex],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
              ),
            ),
          ),
          if (_highlights.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _highlights.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _highlightIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _highlightIndex ? _accent : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    Widget primary(String label, IconData icon, VoidCallback onTap) => SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );

    switch (_phase) {
      case _Phase.downloading:
        return Text(
          'You can keep this screen open — it only takes a moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        );
      case _Phase.readyToInstall:
        return primary('Install now', Icons.system_update_rounded, _installIfAllowed);
      case _Phase.needsPermission:
        return primary('Allow installs', Icons.verified_user_rounded, InAppUpdater.openInstallPermissionSettings);
      case _Phase.error:
        return Column(
          children: [
            primary('Try again', Icons.refresh_rounded, _startDownload),
            TextButton(
              onPressed: _openInBrowser,
              child: Text('Download in browser instead', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ),
          ],
        );
    }
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double spin;
  final bool done;
  final bool error;

  _RingPainter({
    required this.progress,
    required this.pulse,
    required this.spin,
    required this.done,
    required this.error,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 18;
    final accent = error
        ? const Color(0xFFF87171)
        : done
            ? const Color(0xFF34D399)
            : const Color(0xFF818CF8);

    // Expanding pulse halos
    for (final offset in [0.0, 0.5]) {
      final t = (pulse + offset) % 1.0;
      canvas.drawCircle(
        center,
        radius + 6 + t * 22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: (1 - t) * 0.35),
      );
    }

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress;
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            transform: const GradientRotation(-math.pi / 2),
            colors: done || error
                ? [accent, accent]
                : const [Color(0xFF22D3EE), Color(0xFF818CF8), Color(0xFFC084FC)],
          ).createShader(rect),
      );

      // Glowing head of the arc
      if (!done && !error) {
        final angle = -math.pi / 2 + sweep;
        final head = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawCircle(head, 11, Paint()..color = const Color(0xFFC084FC).withValues(alpha: 0.35));
        canvas.drawCircle(head, 5, Paint()..color = Colors.white);
      }
    }

    // Orbiting sparkle while waiting / downloading
    if (!done && !error) {
      final a = spin * 2 * math.pi;
      final p = center + Offset(math.cos(a), math.sin(a)) * (radius - 26);
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFF22D3EE).withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.pulse != pulse || old.spin != spin || old.done != done || old.error != error;
}
