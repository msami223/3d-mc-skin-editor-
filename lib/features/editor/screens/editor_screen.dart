import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/skin_provider.dart';
import '../widgets/editor_2d_view.dart';
import '../widgets/editor_3d_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _is3DMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2a3a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1a26),
        title: const Text('Skin Editor'),
        actions: [
          // View toggle
          IconButton(
            onPressed: () => setState(() => _is3DMode = !_is3DMode),
            icon: Icon(_is3DMode ? Icons.grid_on : Icons.view_in_ar),
            tooltip: _is3DMode ? 'Switch to 2D' : 'Switch to 3D',
          ),
          // Save
          IconButton(
            onPressed: () async {
              final success = await context.read<SkinProvider>().saveToGallery();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ Saved to Gallery!' : '❌ Failed to save'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
            tooltip: 'Save to Gallery',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left toolbar - Tools
          _buildLeftToolbar(),
          
          // Center - Canvas (2D or 3D)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _is3DMode 
                  ? const Editor3DView(key: ValueKey('3d'))
                  : const Editor2DView(key: ValueKey('2d')),
            ),
          ),
          
          // Right toolbar - Colors
          _buildRightToolbar(),
        ],
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return Consumer<SkinProvider>(
      builder: (context, provider, _) {
        return Container(
          width: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF0d1a26),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Drawing tools
              _toolButton(Icons.edit, 'Draw', 
                provider.currentTool == EditorTool.pencil,
                () => provider.setTool(EditorTool.pencil)),
              _toolButton(Icons.auto_fix_high, 'Erase', 
                provider.currentTool == EditorTool.eraser,
                () => provider.setTool(EditorTool.eraser)),
              _toolButton(Icons.format_color_fill, 'Fill', 
                provider.currentTool == EditorTool.fill,
                () => provider.setTool(EditorTool.fill)),
              _toolButton(Icons.colorize, 'Pick', 
                provider.currentTool == EditorTool.picker,
                () => provider.setTool(EditorTool.picker)),
              
              const SizedBox(height: 12),
              Container(height: 1, width: 40, color: Colors.grey.shade700),
              const SizedBox(height: 12),
              
              // Rotate tool (for 3D)
              _toolButton(Icons.rotate_left, 'Rotate', 
                provider.currentTool == EditorTool.rotate,
                () => provider.setTool(EditorTool.rotate),
                highlight: _is3DMode && provider.currentTool == EditorTool.rotate),
              
              const SizedBox(height: 12),
              Container(height: 1, width: 40, color: Colors.grey.shade700),
              const SizedBox(height: 12),
              
              // History
              _toolButton(Icons.undo, 'Undo', false, () => provider.undo()),
              _toolButton(Icons.redo, 'Redo', false, () => provider.redo()),
              
              const SizedBox(height: 12),
              Container(height: 1, width: 40, color: Colors.grey.shade700),
              const SizedBox(height: 12),
              
              // View toggle
              _toolButton(Icons.grid_on, '2D', !_is3DMode, 
                () => setState(() => _is3DMode = false)),
              _toolButton(Icons.view_in_ar, '3D', _is3DMode, 
                () => setState(() => _is3DMode = true)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightToolbar() {
    return Consumer<SkinProvider>(
      builder: (context, provider, _) {
        return Container(
          width: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF0d1a26),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Current color
              GestureDetector(
                onTap: () => _showColorPicker(provider),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: provider.currentColor,
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: provider.currentColor.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              // Quick colors
              ..._quickColors.map((color) => GestureDetector(
                onTap: () => provider.setColor(color),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: provider.currentColor == color ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _toolButton(IconData icon, String label, bool isSelected, VoidCallback onTap, {bool highlight = false}) {
    Color bgColor;
    if (highlight) {
      bgColor = Colors.blue;
    } else if (isSelected) {
      bgColor = Colors.blue.shade700;
    } else {
      bgColor = Colors.transparent;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(SkinProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: provider.currentColor,
            onColorChanged: (color) => provider.setColor(color),
            enableAlpha: true,
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static const List<Color> _quickColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.brown,
    Colors.black,
    Colors.white,
    Colors.grey,
  ];
}
