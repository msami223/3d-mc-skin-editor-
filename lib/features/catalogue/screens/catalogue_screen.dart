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
    debugPrint('🟡 Loading Steve preset...');
    context.read<SkinProvider>().loadSteveSkin();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
  }

  Future<void> _importSkin(BuildContext context) async {
    debugPrint('🟡 HOME SCREEN: Import button clicked');
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    debugPrint('🟡 HOME SCREEN: File picker result: ${result != null ? "GOT RESULT" : "NULL"}');
    
    if (result != null && result.files.single.path != null) {
      debugPrint('🟡 HOME SCREEN: File path: ${result.files.single.path}');
      final bytes = await File(result.files.single.path!).readAsBytes();
      debugPrint('🟡 HOME SCREEN: Bytes read, length: ${bytes.length}');
      
      final image = img.decodeImage(bytes);
      debugPrint('🟡 HOME SCREEN: Image decoded: ${image != null ? "${image.width}x${image.height}" : "NULL"}');
      
      if (image != null) {
        if (image.width == 64 && image.height == 64) {
           debugPrint('🟡 HOME SCREEN: Loading skin to provider...');
           context.read<SkinProvider>().loadSkin(image);
           debugPrint('🟡 HOME SCREEN: Skin loaded! Navigating to editor...');
           
           if (context.mounted) {
             Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
           }
        } else {
          debugPrint('🟡 HOME SCREEN: Invalid size: ${image.width}x${image.height}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skin must be 64x64')));
          }
        }
      } else {
        debugPrint('🟡 HOME SCREEN: Image decode failed');
      }
    } else {
      debugPrint('🟡 HOME SCREEN: No file selected or path null');
    }
  }
}
