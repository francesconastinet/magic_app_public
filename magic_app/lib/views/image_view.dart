import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../data/models.dart';
import '../services/storage_service.dart';

// ==========================================
// SCHERMATA
// ==========================================

class ImageView extends StatefulWidget {
  final List<MediaItem> immagini;
  final int initialIndex;

  const ImageView({
    super.key,
    required this.immagini,
    required this.initialIndex,
  });

  @override
  State<ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  late PageController _pageController;
  late int _currentIndex;
  String? _basePath;
  bool _isLoadingPath = true;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _inizializzaPercorso();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final currentImage = widget.immagini[_currentIndex];
    final totalCount = widget.immagini.length;
    final layout = ImageLayout(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(layout.insetPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.adaptiveMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageDialogHeader(layout: layout, currentImage: currentImage),

            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(layout.borderRadius),
                ),
                child: Container(
                  color: Colors.black,
                  child: _isLoadingPath
                      ? const Center(child: CircularProgressIndicator())
                      : PageView.builder(
                          controller: _pageController,
                          physics: _isZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          itemCount: totalCount,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return ZoomableImageItem(
                              imagePath: widget.immagini[index].url,
                              basePath: _basePath,
                              layout: layout,
                              onZoomChanged: (isZoomed) {
                                if (_isZoomed != isZoomed) {
                                  setState(() => _isZoomed = isZoomed);
                                }
                              },
                            );
                          },
                        ),
                ),
              ),
            ),

            if (totalCount > 1)
              ImageDotsIndicator(
                layout: layout,
                currentIndex: _currentIndex,
                totalCount: totalCount,
              ),
          ],
        ),
      ),
    );
  }

  // --- LOGICA ---
  Future<void> _inizializzaPercorso() async {
    try {
      final storageService = context.read<StorageService>();
      _basePath = await storageService.percorsoPacchetto(AppConfig.packageId);
    } catch (e) {
      debugPrint('Errore caricamento percorso base immagini: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPath = false);
    }
  }
}

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class ImageLayout {
  final Size screenSize;
  final bool isLandscape;
  final bool isTablet;

  ImageLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape,
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  double get _sS => screenSize.shortestSide;

  // --- DIMENSIONI SCHERMATA ---
  double get adaptiveMaxWidth => isTablet
      ? screenSize.width * 0.8
      : (isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.9);
  double get insetPadding => _sS * 0.04;
  double get borderRadius => _sS * 0.03;
  double get errorIconSize => _sS * 0.12;

  // --- HEADER ---
  double get headerPadding => _sS * 0.02;
  double get titleFontSize => _sS * (isTablet ? 0.03 : 0.04);
  double get closeIconSize => _sS * (isTablet ? 0.04 : 0.06);

  // --- INDICATORI SCORRIMENTO ---
  double get dotSize => _sS * 0.02;
  double get dotMargin => _sS * 0.01;
  double get dotsTopPadding => _sS * 0.02;
}

// ==========================================
// WIDGET
// ==========================================

// --- ZOOM IMMAGINE ---
class ZoomableImageItem extends StatefulWidget {
  final String imagePath;
  final String? basePath;
  final ImageLayout layout;
  final ValueChanged<bool> onZoomChanged;

  const ZoomableImageItem({
    super.key,
    required this.imagePath,
    required this.basePath,
    required this.layout,
    required this.onZoomChanged,
  });

  @override
  State<ZoomableImageItem> createState() => _ZoomableImageItemState();
}

class _ZoomableImageItemState extends State<ZoomableImageItem>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);

    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          _transformationController.value = _animation!.value;
        });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > 1.01);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.01 ? 1.0 : 2.5;
    final endMatrix = Matrix4.identity();

    if (targetScale > 1.0) {
      final dx = -position.dx * (targetScale - 1);
      final dy = -position.dy * (targetScale - 1);
      endMatrix.translate(dx, dy);
      endMatrix.scale(targetScale);
    }

    _animation = Matrix4Tween(begin: currentMatrix, end: endMatrix).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 4.0,
      child: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imagePath.startsWith('assets/')) {
      return Image.asset(
        widget.imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image,
          color: Colors.white,
          size: widget.layout.errorIconSize,
        ),
      );
    } else {
      if (widget.basePath == null) {
        return Icon(
          Icons.error,
          color: Colors.red,
          size: widget.layout.errorIconSize,
        );
      }

      final percorsoAssoluto = '${widget.basePath}/${widget.imagePath}';

      return Image.file(
        File(percorsoAssoluto),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image,
          color: Colors.white,
          size: widget.layout.errorIconSize,
        ),
      );
    }
  }
}

// --- HEADER ---
class ImageDialogHeader extends StatelessWidget {
  final ImageLayout layout;
  final MediaItem currentImage;

  const ImageDialogHeader({
    super.key,
    required this.layout,
    required this.currentImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(layout.headerPadding),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(layout.borderRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              currentImage.titolo,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: layout.titleFontSize,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: layout.closeIconSize,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// --- INDICATORI SCORRIMENTO ---
class ImageDotsIndicator extends StatelessWidget {
  final ImageLayout layout;
  final int currentIndex;
  final int totalCount;

  const ImageDotsIndicator({
    super.key,
    required this.layout,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: layout.dotsTopPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalCount,
          (index) => Container(
            margin: EdgeInsets.symmetric(horizontal: layout.dotMargin),
            width: layout.dotSize,
            height: layout.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentIndex == index ? Colors.blueAccent : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
