import 'package:flutter/material.dart';
import 'backup.dart';
import 'lock.dart';
import 'notif.dart';
import 'prefs.dart';
import 'sfx.dart';
import 'intro.dart';
import 'shell.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.load();
  Lock.locked.value = Prefs.hasPin;
  Sfx.warm();
  AutoBackup.init();
  Notifs.init().then((_) {
    if (Prefs.reminderOn) Notifs.scheduleDaily(Prefs.reminderMin);
  });
  runApp(const ViemosApp());
}

class ViemosApp extends StatelessWidget {
  const ViemosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Prefs.revision,
      builder: (context, _, __) => MaterialApp(
      title: 'Viemos',
      debugShowCheckedModeBanner: false,
      themeMode: Prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F5F2),
        colorScheme: ColorScheme.light(primary: kOrange, surface: const Color(0xFFFFFFFF)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F2EF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0D0E),
        colorScheme: const ColorScheme.dark(primary: kOrange),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      home: const Root(),
      ),
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
    // Aplikasi sudah ada di bawah; intro di atasnya "membuka" lalu dilepas.
    return AppLock(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Shell(),
          if (!introDone) Intro(onDone: () => setState(() => introDone = true)),
        ],
      ),
    );
  }
}
