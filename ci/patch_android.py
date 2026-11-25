#!/usr/bin/env python3
"""Patch folder android/ hasil `flutter create` supaya notifikasi pengingat jalan.
Aman dijalankan berulang (idempotent)."""
import pathlib
import re
import sys

root = pathlib.Path('android')

# ---------- AndroidManifest.xml: izin + receiver notifikasi terjadwal
mf = root / 'app/src/main/AndroidManifest.xml'
s = mf.read_text()

perms = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
]
add = ''.join(
    f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in s
)
if add:
    s = s.replace('<application', add + '    <application', 1)

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

# ---------- build.gradle(.kts): core library desugaring (wajib utk flutter_local_notifications)
g = None
for name in ('build.gradle.kts', 'build.gradle'):
    cand = root / 'app' / name
    if cand.exists():
        g = cand
        break
if g is None:
    sys.exit('android/app/build.gradle(.kts) tidak ketemu')

txt = g.read_text()
if 'coreLibraryDesugaring' not in txt:
    kts = g.name.endswith('.kts')
    flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    new, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        ' + flag, txt, count=1)
    if n == 0:
        sys.exit('blok compileOptions tidak ketemu di ' + str(g))
    dep = (
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        if kts
        else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    )
    new += '\ndependencies {\n    ' + dep + '\n}\n'
    g.write_text(new)

print('android patched')
