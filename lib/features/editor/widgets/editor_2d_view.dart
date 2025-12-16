import 'dart:typed_data';
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
  final GlobalKey _canvasKey = GlobalKey();
  int? _lastX;
  int? _lastY;
  bool _isDrawing = false;
  
  static const double _canvasDisplaySize = 320.0;
  static const int _skinSize = 64;

  @override
  void initState() {
    super.initState();
    // Start centered with some zoom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerAndZoom(1.5);
    });
  }

  void _centerAndZoom(double scale) {
    // Calculate center offset for the canvas
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final screenCenter = box.size.center(Offset.zero);
    final canvasCenter = Offset(_canvasDisplaySize / 2, _canvasDisplaySize / 2);
    
    // Create transform that centers the canvas and applies scale
    final matrix = Matrix4.identity()
      ..translate(screenCenter.dx - canvasCenter.dx * scale, 
                  screenCenter.dy - canvasCenter.dy * scale)
      ..scale(scale);
    
    _transformController.value = matrix;
  }

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
        
        return Container(
          color: const Color(0xFF111111),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Zoomable canvas
              LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    transformationController: _transformController,
                    boundaryMargin: EdgeInsets.all(constraints.maxWidth),
                    minScale: 0.5,
                    maxScale: 20.0,
                    child: Center(
                      child: GestureDetector(
                        key: _canvasKey,
                        onPanStart: (details) => _onDrawStart(details.localPosition, provider),
                        onPanUpdate: (details) => _onDrawUpdate(details.localPosition, provider),
                        onPanEnd: (_) => _onDrawEnd(provider),
                        onTapDown: (details) {
                          _onDrawStart(details.localPosition, provider);
                          _onDrawEnd(provider);
                        },
                        child: SizedBox(
                          width: _canvasDisplaySize,
                          height: _canvasDisplaySize,
                          child: Stack(
                            children: [
                              // Skin image
                              Positioned.fill(
                                child: Image.memory(
                                  bytes,
                                  key: ValueKey(bytes.length), // Update key when bytes change
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.none,
                                  gaplessPlayback: true,
                                ),
                              ),
                              // Grid overlay
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: GridPainter(),
                                  ),
                                ),
                              ),
                              // Border
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white38, width: 1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Tool indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: provider.currentColor,
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.currentTool.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Zoom controls
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoomButton(Icons.add, () {
                      final currentScale = _transformController.value.getMaxScaleOnAxis();
                      _applyZoomFromCenter(currentScale * 1.5);
                    }),
                    const SizedBox(height: 8),
                    _zoomButton(Icons.remove, () {
                      final currentScale = _transformController.value.getMaxScaleOnAxis();
                      _applyZoomFromCenter(currentScale / 1.5);
                    }),
                    const SizedBox(height: 8),
                    _zoomButton(Icons.center_focus_strong, () {
                      _centerAndZoom(1.5);
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyZoomFromCenter(double newScale) {
    newScale = newScale.clamp(0.5, 20.0);
    
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final screenCenter = box.size.center(Offset.zero);
    final canvasCenter = Offset(_canvasDisplaySize / 2, _canvasDisplaySize / 2);
    
    final matrix = Matrix4.identity()
      ..translate(screenCenter.dx - canvasCenter.dx * newScale, 
                  screenCenter.dy - canvasCenter.dy * newScale)
      ..scale(newScale);
    
    _transformController.value = matrix;
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  (int, int) _localToPixel(Offset local) {
    final scale = _canvasDisplaySize / _skinSize;
    final x = (local.dx / scale).floor().clamp(0, _skinSize - 1);
    final y = (local.dy / scale).floor().clamp(0, _skinSize - 1);
    return (x, y);
  }

  void _onDrawStart(Offset local, SkinProvider provider) {
    if (provider.currentTool == EditorTool.rotate) return;
    
    _isDrawing = true;
    provider.startStroke();
    final (x, y) = _localToPixel(local);
    _lastX = x;
    _lastY = y;
    provider.paintPixel(x, y, notify: false);
    setState(() {});
  }

  void _onDrawUpdate(Offset local, SkinProvider provider) {
    if (!_isDrawing || provider.currentTool == EditorTool.rotate) return;
    final (x, y) = _localToPixel(local);
    
    if (_lastX != null && _lastY != null) {
      provider.paintLine(_lastX!, _lastY!, x, y);
    }
    _lastX = x;
    _lastY = y;
    setState(() {});
  }

  void _onDrawEnd(SkinProvider provider) {
    if (!_isDrawing) return;
    _isDrawing = false;
    provider.endStroke();
    _lastX = null;
    _lastY = null;
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / 64.0;
    
    // Minor grid lines
    final minorPaint = Paint()
      ..color = const Color(0x20FFFFFF)
      ..strokeWidth = 0.5;
    
    for (int i = 1; i < 64; i++) {
      if (i % 8 != 0) {
        final pos = i * pixelSize;
        canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), minorPaint);
        canvas.drawLine(Offset(0, pos), Offset(size.width, pos), minorPaint);
      }
    }
    
    // Major grid lines every 8 pixels
    final majorPaint = Paint()
      ..color = const Color(0x50FFFFFF)
      ..strokeWidth = 1.0;
    
    for (int i = 0; i <= 64; i += 8) {
      final pos = i * pixelSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), majorPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), majorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
