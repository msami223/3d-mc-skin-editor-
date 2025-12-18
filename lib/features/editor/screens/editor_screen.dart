import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image/image.dart' as img;
import '../providers/skin_provider.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late WebViewController _controller;
  bool _isLoaded = false;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1a2a3a))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {
          _handleWebMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => _isLoaded = true);
            _loadSkinToWeb();
          },
          onWebResourceError: (error) {
            debugPrint('Web Resource Error: ${error.description}');
          },
        ),
      )
      ..loadFlutterAsset('assets/web/skin_editor.html');
  }

  void _handleWebMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'skin_update') {
        final base64Data = data['data'] as String;
        final bytes = base64Decode(base64Data);
        final image = img.decodeImage(bytes);
        if (image != null) {
          context.read<SkinProvider>().loadSkin(image);
        }
      }
    } catch (e) {
      debugPrint('Error parsing web message: $e');
    }
  }

  void _loadSkinToWeb() {
    if (!_isLoaded) return;
    
    final provider = context.read<SkinProvider>();
    if (provider.skinImage == null) return;
    
    final pngBytes = img.encodePng(provider.skinImage!);
    final base64Data = base64Encode(pngBytes);
    
    _controller.runJavaScript('loadSkin("$base64Data")');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2a3a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1a26),
        title: const Text('Skin Editor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                // Call JavaScript saveImage() function
                final result = await _controller.runJavaScriptReturningResult('saveImage()');
                
                if (result is String && result.isNotEmpty) {
                  // Remove quotes from string result
                  final base64Data = result.replaceAll('"', '');
                  final bytes = base64Decode(base64Data);
                  final image = img.decodeImage(bytes);
                  
                  if (image != null) {
                    context.read<SkinProvider>().loadSkin(image);
                    final success = await context.read<SkinProvider>().saveToGallery();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ Saved to Gallery!' : '❌ Failed to save'),
                          backgroundColor: success ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ No image to save'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Save error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Save failed'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.save),
            tooltip: 'Save to Gallery',
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
