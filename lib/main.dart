import 'package:flutter/material.dart';
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
  Notifs.init().then((_) {
    if (Prefs.reminderOn) Notifs.scheduleDaily(Prefs.reminderMin);
  });
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
  final ValueNotifier<double> _intro = ValueNotifier<double>(0);

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Aplikasi sudah ada di bawah; intro di atasnya "membuka" lalu dilepas.
    // Saat huruf intro membesar, aplikasi ikut ditarik masuk secara 3D
    // (mengecil + miring -> rata menghadap kita).
    return AppLock(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _intro,
            child: const Shell(),
            builder: (_, c, child) {
              final z = introDone
                  ? 1.0
                  : const Interval(0.66, 1.0, curve: Curves.easeOutCubic).transform(c);
              final sc = 0.9 + 0.1 * z;
              return Transform(
                alignment: Alignment.center,
                transform: persp(0.0009) *
                    Matrix4.rotationX((1 - z) * 0.18) *
                    Matrix4.diagonal3Values(sc, sc, 1.0),
                child: child,
              );
            },
          ),
          if (!introDone)
            Intro(progress: _intro, onDone: () => setState(() => introDone = true)),
        ],
      ),
    );
  }
}
