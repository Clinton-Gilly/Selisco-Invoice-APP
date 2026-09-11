import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth_lock/lock_screen.dart';
import 'biometric_service.dart';

class AppLockState {
  final bool isLocked;
  final bool isAuthenticating;
  final String? errorMessage;

  const AppLockState({
    required this.isLocked,
    this.isAuthenticating = false,
    this.errorMessage,
  });

  AppLockState copyWith({
    bool? isLocked,
    bool? isAuthenticating,
    String? errorMessage,
  }) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: errorMessage,
    );
  }
}

class AppLockNotifier extends Notifier<AppLockState> {
  // 4 minutes session timeout (between 3 to 5 minutes as requested)
  static const Duration sessionTimeout = Duration(minutes: 4);
  DateTime? _pausedAt;

  @override
  AppLockState build() {
    Future.microtask(() => authenticate());
    return const AppLockState(isLocked: true);
  }

  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  Future<void> authenticate() async {
    if (state.isAuthenticating) return;

    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    try {
      final success = await _biometricService.authenticate(
        localizedReason: 'Authenticate to access Selisco Invoices & Delivery Notes',
      );

      if (success) {
        _pausedAt = null;
        state = const AppLockState(isLocked: false, isAuthenticating: false);
      } else {
        state = state.copyWith(
          isLocked: true,
          isAuthenticating: false,
          errorMessage: 'Authentication failed. Please try again or enter your device PIN.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLocked: true,
        isAuthenticating: false,
        errorMessage: 'Authentication error: ${e.toString()}',
      );
    }
  }

  void onAppPaused() {
    _pausedAt = DateTime.now();
  }

  void onAppResumed() {
    if (state.isLocked) {
      if (!state.isAuthenticating) {
        authenticate();
      }
      return;
    }

    if (_pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!);
      if (elapsed >= sessionTimeout) {
        // More than 4 minutes in background: lock and request authentication
        state = state.copyWith(isLocked: true);
        authenticate();
      }
      // If elapsed < 4 minutes, keep unlocked without prompting!
      _pausedAt = null;
    }
  }

  void lock() {
    if (!state.isLocked) {
      state = state.copyWith(isLocked: true);
    }
  }
}

final appLockNotifierProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(() {
  return AppLockNotifier();
});

class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(appLockNotifierProvider.notifier).onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appLockNotifierProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockNotifierProvider);

    if (lockState.isLocked) {
      return const LockScreen();
    }

    return widget.child;
  }
}
