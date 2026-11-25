import 'package:flutter/material.dart';
import 'sfx.dart';
import 'intro.dart';
import 'shell.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Sfx.warm();
  runApp(const ViemosApp());
}

class ViemosApp extends StatelessWidget {
  const ViemosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viemos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0D0E),
        colorScheme: const ColorScheme.dark(primary: kOrange),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool introDone = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: introDone
          ? const Shell(key: ValueKey('shell'))
          : Intro(key: const ValueKey('intro'), onDone: () => setState(() => introDone = true)),
    );
  }
}
