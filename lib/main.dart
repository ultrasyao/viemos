import 'package:flutter/material.dart';

void main() => runApp(const ViemosApp());

class ViemosApp extends StatelessWidget {
  const ViemosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viemos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0D0E),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFFB066)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Viemos',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
