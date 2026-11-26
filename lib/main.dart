import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lock.dart';
import 'notif.dart';
import 'prefs.dart';
import 'sfx.dart';
import 'theme.dart';
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

class ViemosApp extends StatefulWidget {
  const ViemosApp({super.key});
  @override
  State<ViemosApp> createState() => _ViemosAppState();
}

class _ViemosAppState extends State<ViemosApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mode "ikuti sistem": saat tema HP berubah, app ikut (dengan pudar halus).
  @override
  void didChangePlatformBrightness() {
    if (Pal.mode != 0) return;
    final was = Pal.dark;
    Pal.refresh();
    if (Pal.dark == was) return;
    Pal.dark = was; // kembalikan dulu; perubahan sebenarnya terjadi di dalam ThemeFx
    ThemeFx.change(Pal.refresh);
  }

  ThemeData _theme() {
    final dark = Pal.dark;
    final scheme = dark
        ? ColorScheme.dark(primary: kOrange, surface: kBg)
        : ColorScheme.light(primary: kOrange, surface: kBg);
    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: scheme,
      dividerColor: kBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ikon status bar & navigasi harus kontras dengan latar (gelap <-> terang)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Pal.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: kBg,
      systemNavigationBarIconBrightness: Pal.dark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      title: 'Viemos',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      themeAnimationDuration: Duration.zero, // animasinya diurus ThemeFx
      builder: (context, child) => ThemeFx(key: ThemeFx.key, child: child ?? const SizedBox()),
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
            // RepaintBoundary: aplikasi digambar sekali lalu cuma "digeser" sebagai
            // layer saat ditarik masuk (tidak digambar ulang tiap frame -> mulus)
            child: const RepaintBoundary(child: Shell()),
            builder: (_, c, child) {
              final z = introDone
                  ? 1.0
                  : const Interval(kIntroZoomAt, 1.0, curve: Curves.easeOutCubic).transform(c);
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
            RepaintBoundary(
              child: Intro(progress: _intro, onDone: () => setState(() => introDone = true)),
            ),
        ],
      ),
    );
  }
}
