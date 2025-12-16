import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skin_provider.dart';

class Editor2DView extends StatefulWidget {
  const Editor2DView({super.key});

  @override
  State<Editor2DView> createState() => _Editor2DViewState();
}

class _Editor2DViewState extends State<Editor2DView> {
  final TransformationController _transformController = TransformationController();
  int? _lastX;
  int? _lastY;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinProvider>(
      builder: (context, provider, child) {
        if (provider.skinImage == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final bytes = provider.pngBytes;
        if (bytes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        const double displaySize = 320.0;

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.5,
              maxScale: 20.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final pos = _toPixelCoords(details.localPosition, displaySize);
                    provider.paintPixel(pos.$1, pos.$2);
                    provider.recordChange();
                  },
                  onPanStart: (details) {
                    provider.startStroke();
                    final pos = _toPixelCoords(details.localPosition, displaySize);
                    _lastX = pos.$1;
                    _lastY = pos.$2;
                    provider.paintPixel(_lastX!, _lastY!, notify: false);
                  },
                  onPanUpdate: (details) {
                    final pos = _toPixelCoords(details.localPosition, displaySize);
                    final x = pos.$1;
                    final y = pos.$2;
                    
                    // Draw line from last position to current for smooth strokes
                    if (_lastX != null && _lastY != null) {
                      provider.paintLine(_lastX!, _lastY!, x, y);
                    }
                    
                    _lastX = x;
                    _lastY = y;
                    
                    // Force a repaint without full rebuild
                    setState(() {});
                  },
                  onPanEnd: (details) {
                    provider.endStroke();
                    _lastX = null;
                    _lastY = null;
                  },
                  child: RepaintBoundary(
                    child: Container(
                      width: displaySize,
                      height: displaySize,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade600, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        bytes,
                        gaplessPlayback: true, // Prevents flicker
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Tool indicator
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: provider.currentColor,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.currentTool.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            // Zoom controls
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    onPressed: () {
                      final currentScale = _transformController.value.getMaxScaleOnAxis();
                      _transformController.value = Matrix4.identity()..scale(currentScale * 1.5);
                    },
                    child: const Icon(Icons.zoom_in),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    onPressed: () {
                      final currentScale = _transformController.value.getMaxScaleOnAxis();
                      _transformController.value = Matrix4.identity()..scale(currentScale / 1.5);
                    },
                    child: const Icon(Icons.zoom_out),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'reset_view',
                    onPressed: () {
                      _transformController.value = Matrix4.identity();
                    },
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  (int, int) _toPixelCoords(Offset localPosition, double displaySize) {
    final double scale = displaySize / 64.0;
    final int x = (localPosition.dx / scale).floor();
    final int y = (localPosition.dy / scale).floor();
    return (x, y);
  }
}
