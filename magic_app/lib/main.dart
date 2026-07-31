import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/ar_screen.dart';
import 'screens/dettaglio_screen.dart';
import 'app_state.dart';
import 'services/chat_service.dart';
import 'services/auth_service.dart';
import 'services/package_storage.dart';
import 'services/media_service.dart';

// --- ROUTER ---
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/camera', builder: (context, state) => const CameraScreen()),
    GoRoute(
      path: '/collezioni',
      builder: (context, state) => const CollectionScreen(),
    ),
    GoRoute(
      path: '/ar/:nome',
      builder: (context, state) {
        final nome = state.pathParameters['nome']!;
        return ARScreen(nomeOpera: nome);
      },
    ),
    GoRoute(
      path: '/opera/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DettaglioScreen(id: id);
      },
    ),
  ],
);

// --- APP BOOTSTRAP ---
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => ChatService()),
        Provider(create: (context) => PackageStorage()),
        Provider(create: (context) => MediaService()),
      ],
      child: const MagicApp(),
    ),
  );
}

class MagicApp extends StatelessWidget {
  const MagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MAGIC OR8.2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Georgia',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        cardTheme: const CardThemeData(
          elevation: 3,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
