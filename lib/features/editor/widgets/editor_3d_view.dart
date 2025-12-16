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
            _updateColor();
          },
        ),
      )
      ..loadHtmlString(_htmlContent!);
  }

  void _handleWebMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'paint') {
        final x = data['x'] as int;
        final y = data['y'] as int;
        context.read<SkinProvider>().paintPixel(x, y);
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
    
    _controller.runJavaScript('updateSkin("$base64Data")');
  }

  void _updateColor() {
    if (!_isLoaded) return;
    
    final provider = context.read<SkinProvider>();
    final color = provider.currentColor;
    final hexColor = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    
    _controller.runJavaScript('setColor("$hexColor")');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinProvider>(
      builder: (context, provider, child) {
        // Update texture when provider changes
        if (_isLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateSkinTexture();
            _updateColor();
          });
        }
        
        if (_htmlContent == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return WebViewWidget(controller: _controller);
      },
    );
  }
}
