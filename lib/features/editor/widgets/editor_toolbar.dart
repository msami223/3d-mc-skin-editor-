import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/skin_provider.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 60,
          color: Colors.grey[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(context, provider, EditorTool.pencil, Icons.edit),
              _buildToolButton(context, provider, EditorTool.eraser, Icons.auto_fix_normal), // Eraser icon
              _buildToolButton(context, provider, EditorTool.fill, Icons.format_color_fill),
              _buildToolButton(context, provider, EditorTool.picker, Icons.colorize),
              
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick a color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: provider.currentColor,
                          onColorChanged: (color) => provider.setColor(color),
                        ),
                      ),
                      actions: <Widget>[
                        ElevatedButton(
                          child: const Text('Done'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: provider.currentColor,
                    border: Border.all(color: Colors.white, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolButton(BuildContext context, SkinProvider provider, EditorTool tool, IconData icon) {
    final isSelected = provider.currentTool == tool;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.green : Colors.white),
      onPressed: () => provider.setTool(tool),
    );
  }
}
