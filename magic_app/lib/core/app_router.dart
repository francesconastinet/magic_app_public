import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../views/detail_screen.dart';
import '../views/home_screen.dart';
import '../views/ar_view.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/ar', builder: (context, state) => const ARScreen()),
    GoRoute(
      path: '/ar/:nome',
      builder: (context, state) {
        final nome = state.pathParameters['nome'];
        return ARScreen(nomeOperaIniziale: nome);
      },
    ),
    GoRoute(
      path: '/opera/:id',
      builder: (context, state) {
        final book = state.extra as BookModel;
        return DetailScreen(book: book);
      },
    ),
  ],
);
