import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
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
    
    // Listen to SkinProvider changes and load skin to WebView when it changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SkinProvider>();
      provider.addListener(_onSkinChanged);
    });
  }
  
  void _onSkinChanged() {
    debugPrint('🟢 _onSkinChanged called! Listener triggered.');
    // When skin changes (user imports from gallery), load it to WebView
    _loadSkinToWeb();
  }
  
  @override
  void dispose() {
    try {
      final provider = context.read<SkinProvider>();
      provider.removeListener(_onSkinChanged);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
            debugPrint('🟢 WebView page finished loading');
            
            // CRITICAL: If there's already a skin in the provider (imported from home screen),
            // load it now that WebView is ready
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                final provider = context.read<SkinProvider>();
                if (provider.skinImage != null) {
                  debugPrint('🟢 Found existing skin in provider, loading to WebView...');
                  _loadSkinToWeb();
                }
              }
            });
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
    debugPrint('🟢 _loadSkinToWeb called');
    if (!_isLoaded) {
      debugPrint('🔴 WebView not loaded yet! Cannot send skin.');
      return;
    }
    
    final provider = context.read<SkinProvider>();
    
    // If skinImage is null, don't load anything - canvas stays empty
    if (provider.skinImage == null) {
      debugPrint('🔴 No skin to load (skinImage is null)');
      return;
    }
    
    debugPrint('🟢 Encoding skin image: ${provider.skinImage!.width}x${provider.skinImage!.height}');
    final pngBytes = img.encodePng(provider.skinImage!);
    final base64Data = base64Encode(pngBytes);
    debugPrint('🟢 Base64 data length: ${base64Data.length}');
    debugPrint('🟢 Calling JavaScript loadSkin()...');
    
    _controller.runJavaScript('loadSkin("$base64Data")');
    debugPrint('🟢 JavaScript loadSkin() called!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NO backgroundColor - let WebView's HTML background show through!
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
              debugPrint('🔴 IMPORT BUTTON CLICKED');
              try {
                debugPrint('🔴 Opening file picker...');
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                debugPrint('🔴 File picker result: ${result != null ? "GOT RESULT" : "NULL"}');
                
                if (result != null && result.files.single.path != null) {
                  debugPrint('🔴 File selected, path: ${result.files.single.path}');
                  
                  // Read bytes from file path (works on all platforms)
                  final file = File(result.files.single.path!);
                  final bytes = await file.readAsBytes();
                  debugPrint('🔴 Bytes read from file, length: ${bytes.length}');
                  
                  debugPrint('🔴 Decoding image...');
                  final image = img.decodeImage(bytes);
                  debugPrint('🔴 Image decoded: ${image != null ? "${image.width}x${image.height}" : "NULL"}');
                  
                  if (image != null && context.mounted) {
                    debugPrint('🔴 Loading skin to provider...');
                    context.read<SkinProvider>().loadSkin(image);
                    debugPrint('🔴 Skin loaded to provider! Listener should trigger now.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Skin loaded!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    debugPrint('🔴 Image is null or context not mounted');
                  }
                } else {
                  debugPrint('🔴 No file selected or path is null');
                }
              } catch (e, stackTrace) {
                debugPrint('🔴 Import error: $e');
                debugPrint('🔴 Stack trace: $stackTrace');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Failed to import skin'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Gallery',
          ),
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
