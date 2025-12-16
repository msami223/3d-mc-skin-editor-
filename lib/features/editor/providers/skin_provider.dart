import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

enum EditorTool { pencil, eraser, fill, picker }

class SkinProvider extends ChangeNotifier {
  img.Image? _skinImage;
  final List<img.Image> _history = [];
  int _historyIndex = -1;
  Color _currentColor = Colors.red;
  EditorTool _currentTool = EditorTool.pencil;
  
  // For performance: cache encoded PNG
  Uint8List? _cachedPngBytes;
  bool _isDirty = true;
  
  // Track if we're in a drawing stroke
  bool _isDrawing = false;

  img.Image? get skinImage => _skinImage;
  Color get currentColor => _currentColor;
  EditorTool get currentTool => _currentTool;
  
  // Get cached PNG bytes for efficient rendering
  Uint8List? get pngBytes {
    if (_skinImage == null) return null;
    if (_isDirty || _cachedPngBytes == null) {
      _cachedPngBytes = Uint8List.fromList(img.encodePng(_skinImage!));
      _isDirty = false;
    }
    return _cachedPngBytes;
  }

  SkinProvider() {
    _initializeDefaultSkin();
  }

  void _initializeDefaultSkin() {
    _skinImage = img.Image(width: 64, height: 64);
    img.fill(_skinImage!, color: img.ColorRgba8(200, 200, 200, 255)); 
    _isDirty = true;
    _addToHistory();
  }

  void resetSkin() {
    _initializeDefaultSkin();
    _history.clear();
    _historyIndex = -1;
    _addToHistory();
    notifyListeners();
  }

  void loadSkin(img.Image image) {
    _skinImage = image;
    _isDirty = true;
    _history.clear();
    _historyIndex = -1;
    _addToHistory();
    notifyListeners();
  }

  Future<bool> saveToGallery() async {
    if (_skinImage == null) return false;
    try {
      if (!await Gal.hasAccess()) {
         await Gal.requestAccess();
      }
      final pngBytes = img.encodePng(_skinImage!);
      await Gal.putImageBytes(
        Uint8List.fromList(pngBytes),
        name: "minecraft_skin_${DateTime.now().millisecondsSinceEpoch}"
      );
      return true;
    } catch (e) {
      debugPrint('Error saving skin: $e');
      return false;
    }
  }

  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void setTool(EditorTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  // Start a drawing stroke - don't notify until endStroke
  void startStroke() {
    _isDrawing = true;
  }
  
  // End drawing stroke - batch update
  void endStroke() {
    _isDrawing = false;
    _isDirty = true;
    _addToHistory();
    notifyListeners();
  }

  void paintPixel(int x, int y, {bool notify = true}) {
    if (_skinImage == null) return;
    if (x < 0 || x >= 64 || y < 0 || y >= 64) return;

    if (_currentTool == EditorTool.picker) {
      final pixel = _skinImage!.getPixel(x, y);
      _currentColor = Color.fromARGB(pixel.a.toInt(), pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
      _currentTool = EditorTool.pencil;
      notifyListeners();
      return;
    }

    if (_currentTool == EditorTool.fill) {
      _floodFill(x, y);
      _isDirty = true;
      _addToHistory();
      notifyListeners();
      return;
    }

    final colorToPaint = _currentTool == EditorTool.eraser 
        ? img.ColorRgba8(0, 0, 0, 0) 
        : img.ColorRgba8(_currentColor.red, _currentColor.green, _currentColor.blue, _currentColor.alpha);
    _skinImage!.setPixel(x, y, colorToPaint);
    _isDirty = true;
    
    // Only notify if not in a stroke (for single taps) or if explicitly requested
    if (!_isDrawing && notify) {
      notifyListeners();
    }
  }
  
  // Paint multiple pixels at once for smoother lines
  void paintLine(int x1, int y1, int x2, int y2) {
    if (_skinImage == null) return;
    
    final colorToPaint = _currentTool == EditorTool.eraser 
        ? img.ColorRgba8(0, 0, 0, 0) 
        : img.ColorRgba8(_currentColor.red, _currentColor.green, _currentColor.blue, _currentColor.alpha);
    
    // Bresenham's line algorithm
    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;
    
    int x = x1;
    int y = y1;
    
    while (true) {
      if (x >= 0 && x < 64 && y >= 0 && y < 64) {
        _skinImage!.setPixel(x, y, colorToPaint);
      }
      
      if (x == x2 && y == y2) break;
      
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
    
    _isDirty = true;
  }

  void _floodFill(int x, int y) {
    final targetColor = _skinImage!.getPixel(x, y);
    final replacementColor = _currentTool == EditorTool.eraser 
        ? img.ColorRgba8(0, 0, 0, 0) 
        : img.ColorRgba8(_currentColor.red, _currentColor.green, _currentColor.blue, _currentColor.alpha);
    
    if (targetColor == replacementColor) return;

    final stack = <img.Point>[img.Point(x, y)];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final px = p.x.toInt();
      final py = p.y.toInt();
      if (px < 0 || px >= 64 || py < 0 || py >= 64) continue;
      if (_skinImage!.getPixel(px, py) != targetColor) continue;

      _skinImage!.setPixel(px, py, replacementColor);
      stack.add(img.Point(px + 1, py));
      stack.add(img.Point(px - 1, py));
      stack.add(img.Point(px, py + 1));
      stack.add(img.Point(px, py - 1));
    }
  }
  
  void recordChange() {
    _isDirty = true;
    _addToHistory();
    notifyListeners();
  }

  void _addToHistory() {
    if (_skinImage == null) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(img.Image.from(_skinImage!));
    _historyIndex++;
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _skinImage = img.Image.from(_history[_historyIndex]);
      _isDirty = true;
      notifyListeners();
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _skinImage = img.Image.from(_history[_historyIndex]);
      _isDirty = true;
      notifyListeners();
    }
  }
}
