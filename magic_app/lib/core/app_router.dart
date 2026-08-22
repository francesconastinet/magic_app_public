import 'package:go_router/go_router.dart';
import '../data/opera_repository.dart';
import '../screens/detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/ar_screen.dart';

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
        final id = state.pathParameters['id']!;
        final book = OperaRepository.tutteLeOpere().firstWhere(
          (o) => o.id == id,
        );
        return DetailScreen(book: book);
      },
    ),
  ],
);
