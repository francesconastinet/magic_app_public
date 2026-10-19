import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../views/detail_view.dart';
import '../views/home_view.dart';
import '../views/ar_view.dart';
import '../views/pixel_matching_test_view.dart'; // NUOVO
import '../views/tflite_test_view.dart'; // NUOVO — vista di test del modello TFLite

final appRouter = GoRouter(
  // MODIFICATO — per provare la scansione AR con il modello di Rosario si parte dalla home
  // (per rieseguire i test del modello TFLite rimettere initialLocation: '/test-tflite',)
  // TEMPORANEO — solo per il test, poi da togliere
  // (riga precedente: initialLocation: '/test-pixelmatching',)
  // (riga precedente: initialLocation: '/test-tflite',)
  initialLocation: '/',
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
    // Serve solo per il test di valutazione, da togliere 
    GoRoute(
      path: '/test-pixelmatching',
      builder: (context, state) => const PixelMatchingTestView(),
    ),
    // NUOVO — serve solo per il test del modello TFLite, da togliere
    GoRoute(
      path: '/test-tflite',
      builder: (context, state) => const TfliteTestView(),
    ),
  ],
);