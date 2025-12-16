import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image/image.dart' as img;
import '../providers/skin_provider.dart';

class Editor3DView extends StatefulWidget {
  const Editor3DView({super.key});

  @override
  State<Editor3DView> createState() => _Editor3DViewState();
}

class _Editor3DViewState extends State<Editor3DView> {
  late WebViewController _controller;
  bool _isLoaded = false;
  String? _htmlContent;
  EditorTool? _lastTool;

  @override
  void initState() {
    super.initState();
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('assets/web/skin_viewer.html');
    setState(() {
      _htmlContent = html;
    });
    _initWebView();
  }

  void _initWebView() {
    if (_htmlContent == null) return;
    
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
            _updateSkinTexture();
            _updateDrawMode();
            _updateColor();
          },
        ),
      )
      ..loadHtmlString(_htmlContent!);
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

  void _updateSkinTexture() {
    if (!_isLoaded) return;
    
    final provider = context.read<SkinProvider>();
    if (provider.skinImage == null) return;
    
    final pngBytes = img.encodePng(provider.skinImage!);
    final base64Data = base64Encode(pngBytes);
    
    _controller.runJavaScript('loadSkin("$base64Data")');
  }

  void _updateDrawMode() {
    if (!_isLoaded) return;
    
    final provider = context.read<SkinProvider>();
    final isDrawMode = provider.currentTool != EditorTool.rotate;
    _controller.runJavaScript('setDrawMode($isDrawMode)');
  }

  void _updateColor() {
    if (!_isLoaded) return;
    
    final provider = context.read<SkinProvider>();
    final color = provider.currentColor;
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    _controller.runJavaScript('setColor("$hex")');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinProvider>(
      builder: (context, provider, child) {
        // Update mode when tool changes
        if (_isLoaded && _lastTool != provider.currentTool) {
          _lastTool = provider.currentTool;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateDrawMode();
            _updateColor();
          });
        }
        
        // Update skin when it changes
        if (_isLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateSkinTexture();
          });
        }
        
        if (_htmlContent == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final isRotateMode = provider.currentTool == EditorTool.rotate;
        
        return Stack(
          children: [
            WebViewWidget(controller: _controller),
            
            // Mode indicator
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isRotateMode ? Colors.blue.withOpacity(0.7) : Colors.green.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRotateMode ? Icons.rotate_left : Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRotateMode ? 'ROTATE MODE' : 'DRAW MODE',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            // Help text
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isRotateMode 
                        ? 'Drag to rotate • Use pencil tool to draw'
                        : 'Tap on model to paint',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
