import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/security/app_lock_wrapper.dart';
import 'core/theme/app_theme.dart';
import 'shared/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation and system UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: SeliscoApp(),
    ),
  );
}

class SeliscoApp extends StatelessWidget {
  const SeliscoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selisco Invoice & Logistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppLockWrapper(
        child: MainNavigationShell(),
      ),
    );
  }
}
