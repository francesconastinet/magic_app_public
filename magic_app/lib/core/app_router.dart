import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../views/detail_view.dart';
import '../views/home_view.dart';
import '../views/ar_view.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeView()),
    GoRoute(path: '/ar', builder: (context, state) => const ARView()),
    GoRoute(
      path: '/ar/:nome',
      builder: (context, state) {
        final nome = state.pathParameters['nome'];
        return ARView(nomeOperaIniziale: nome);
      },
    ),
    GoRoute(
      path: '/opera/:id',
      builder: (context, state) {
        final book = state.extra as BookModel;
        return DetailView(book: book);
      },
    ),
  ],
);
