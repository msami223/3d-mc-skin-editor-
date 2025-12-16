import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skin_provider.dart';
import '../widgets/editor_2d_view.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/editor_3d_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Editor'),
        actions: [
          IconButton(
            onPressed: () => context.read<SkinProvider>().undo(),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: () => context.read<SkinProvider>().redo(),
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            onPressed: () async {
              final success = await context.read<SkinProvider>().saveToGallery();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Skin saved to Gallery!' : 'Failed to save skin')),
                );
              }
            },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentIndex == 0 
                ? const Editor2DView() 
                : const Editor3DView(),
          ),
          const EditorToolbar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: '2D Picker'),
          BottomNavigationBarItem(icon: Icon(Icons.bento), label: '3D Preview'),
        ],
      ),
    );
  }
}
