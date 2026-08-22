import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/app_state.dart';
import 'services/chat_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/media_service.dart';

// ==========================================
// APP BOOTSTRAP
// ==========================================

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => ChatService()),
        Provider(create: (context) => StorageService()),
        Provider(create: (context) => MediaService()),
      ],
      child: const MagicApp(),
    ),
  );
}

class MagicApp extends StatelessWidget {
  const MagicApp({super.key});

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MAGIC OR8.2',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it', 'IT')],
    );
  }
}
