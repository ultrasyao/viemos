#!/usr/bin/env python3
"""Patch folder android/ hasil `flutter create` supaya siap rilis (Play Store).
Aman dijalankan berulang (idempotent). Yang dilakukan:
  1. Manifest: izin notifikasi, BUANG izin internet & penyimpanan, allowBackup=false
  2. MainActivity: FLAG_SECURE (blokir screenshot / pratinjau app terbaru)
  3. build.gradle: core library desugaring + tanda tangan rilis dari key.properties
"""
import glob
import pathlib
import re
import sys

root = pathlib.Path('android')

# ---------------------------------------------------------------- manifest
mf = root / 'app/src/main/AndroidManifest.xml'
s = mf.read_text()

if 'xmlns:tools' not in s:
    s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

add_perms = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
]
# izin yang DIJAMIN tidak ada di APK akhir, walau plugin mana pun memintanya
remove_perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.MANAGE_EXTERNAL_STORAGE',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
]
lines = ''
for p in add_perms:
    if f'"{p}"' not in s:
        lines += f'    <uses-permission android:name="{p}"/>\n'
for p in remove_perms:
    if f'"{p}"' not in s:
        lines += f'    <uses-permission android:name="{p}" tools:node="remove"/>\n'
if lines:
    s = s.replace('<application', lines + '    <application', 1)


def app_attr(text, name, val):
    if re.search(rf'android:{name}="[^"]*"', text):
        return re.sub(rf'android:{name}="[^"]*"', f'android:{name}="{val}"', text, count=1)
    return text.replace('<application', f'<application android:{name}="{val}"', 1)


s = s.replace('android:requestLegacyExternalStorage="true"', '')
s = app_attr(s, 'allowBackup', 'false')          # data tidak ikut backup cloud / adb
s = app_attr(s, 'usesCleartextTraffic', 'false')

if 'ScheduledNotificationReceiver' not in s:
    receivers = '''
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    '''
    s = s.replace('</application>', receivers + '</application>', 1)
mf.write_text(s)

# ------------------------------------------------------------ MainActivity
acts = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
if not acts:
    sys.exit('MainActivity.kt tidak ketemu')
act = pathlib.Path(acts[0])
m = re.search(r'^package\s+([\w.]+)', act.read_text(), re.M)
if not m:
    sys.exit('package MainActivity tidak terbaca')
act.write_text(f'''package {m.group(1)}

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        // aman secara default; Dart bisa mematikannya lewat Setting
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }}

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "viemos/secure")
            .setMethodCallHandler {{ call, result ->
                if (call.method == "set") {{
                    val on = call.argument<Boolean>("on") ?: true
                    runOnUiThread {{
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }}
                    result.success(null)
                }} else {{
                    result.notImplemented()
                }}
            }}
    }}
}}
''')

# ------------------------------------------------------------------ gradle
g = None
for name in ('build.gradle.kts', 'build.gradle'):
    cand = root / 'app' / name
    if cand.exists():
        g = cand
        break
if g is None:
    sys.exit('android/app/build.gradle(.kts) tidak ketemu')

txt = g.read_text()
kts = g.name.endswith('.kts')

# core library desugaring (wajib utk flutter_local_notifications)
if 'coreLibraryDesugaring' not in txt:
    flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    txt, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        ' + flag, txt, count=1)
    if n == 0:
        sys.exit('blok compileOptions tidak ketemu di ' + str(g))
    dep = (
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        if kts
        else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    )
    txt += '\ndependencies {\n    ' + dep + '\n}\n'

# tanda tangan rilis dari android/key.properties (dibuat oleh workflow)
if 'viemosRelease' not in txt:
    if kts:
        txt = 'import java.util.Properties\nimport java.io.FileInputStream\n\n' + txt
        block = '''android {
    signingConfigs {
        create("viemosRelease") {
            val kp = Properties()
            val kf = rootProject.file("key.properties")
            if (kf.exists()) kp.load(FileInputStream(kf))
            keyAlias = kp.getProperty("keyAlias")
            keyPassword = kp.getProperty("keyPassword")
            storeFile = kp.getProperty("storeFile")?.let { file(it) }
            storePassword = kp.getProperty("storePassword")
        }
    }
'''
        txt, n = re.subn(r'\bandroid\s*\{', lambda _: block, txt, count=1)
        sub = r'signingConfig\s*=?\s*signingConfigs(\.getByName\("debug"\)|\.debug|\["debug"\])'
        txt, n2 = re.subn(sub, 'signingConfig = signingConfigs.getByName("viemosRelease")', txt)
    else:
        txt = '''def keystoreProperties = new Properties()
def keystoreFile = rootProject.file('key.properties')
if (keystoreFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystoreFile))
}

''' + txt
        block = '''android {
    signingConfigs {
        viemosRelease {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
'''
        txt, n = re.subn(r'\bandroid\s*\{', lambda _: block, txt, count=1)
        sub = r'signingConfig\s+signingConfigs\.debug'
        txt, n2 = re.subn(sub, 'signingConfig signingConfigs.viemosRelease', txt)
    if n == 0 or n2 == 0:
        sys.exit('GAGAL memasang tanda tangan rilis di ' + str(g) + ' — jangan lanjut build!')
g.write_text(txt)

print('android patched')
