import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'chat_widget.dart';
import 'menu_widget.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  final String? titoloFonteIniziale;
  final List<String>? idsFonteIniziale;

  const HomeScreen({
    super.key,
    this.titoloFonteIniziale,
    this.idsFonteIniziale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = HomeViewModel(
      appState: context.read<AppState>(),
      storage: context.read<StorageService>(),
      authService: context.read<AuthService>(),
      repository: context.read<CatalogueRepository>(),
    );

    _viewModel.onShowMessage = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    };

    _viewModel.inizializza(widget.titoloFonteIniziale, widget.idsFonteIniziale);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.avviaSincronizzazione();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, vm, child) {
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              centerTitle: true,
              actions: [
                Builder(
                  builder: (BuildContext ctx) {
                    return IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu Principale',
                      onPressed: () {
                        Scaffold.of(ctx).openEndDrawer();
                      },
                    );
                  },
                ),
              ],
              title: Image.asset(
                'assets/magic-logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
              bottom: vm.syncInCorso
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(3),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : null,
            ),
            endDrawer: const MenuWidget(),
            body: ChatWidget(
              titoloFonteSelezionata: vm.titoloFonteSelezionata,
              bookIds: vm.idsFonteSelezionata,
              onFonteSelezionata: vm.selezionaFonte,
            ),
          );
        },
      ),
    );
  }
}
