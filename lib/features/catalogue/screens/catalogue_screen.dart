import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../../editor/providers/skin_provider.dart';
import '../../editor/screens/editor_screen.dart';

class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skin Catalogue')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _loadPreset(context, 'steve'), // Implementation pending
              child: const Text('Load Steve Preset'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _importSkin(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import from Device'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadPreset(BuildContext context, String name) {
    // For now, just load default blank skin
    // In real app, load asset
    context.read<SkinProvider>().resetSkin(); // Need to implement reset
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
  }

  Future<void> _importSkin(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        if (image.width == 64 && image.height == 64) {
           context.read<SkinProvider>().loadSkin(image);
           if (context.mounted) {
             Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
           }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skin must be 64x64')));
          }
        }
      }
    }
  }
}
