import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/editor/providers/skin_provider.dart';
import 'features/catalogue/screens/catalogue_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SkinProvider()),
      ],
      child: const MinecraftSkinMakerApp(),
    ),
  );
}

class MinecraftSkinMakerApp extends StatelessWidget {
  const MinecraftSkinMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minecraft Skin Maker',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Light grey background
        useMaterial3: true,
      ),
      home: const CatalogueScreen(),
    );
  }
}
