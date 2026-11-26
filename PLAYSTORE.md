# Panduan rilis Viemos ke Play Store (dari HP: Termux + GitHub)

## 1. Buat kunci tanda tangan (sekali seumur hidup)
Di Termux:
```
pkg install openjdk-17 git gh
cd ~
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```
- Pakai password HURUF + ANGKA saja (tanpa simbol aneh).
- **Simpan `upload-keystore.jks` + password di 2 tempat aman** (mis. Drive pribadi + catatan password). Hilang = tidak bisa update app.
- **Jangan pernah commit file ini ke GitHub.**

## 2. Masukkan ke GitHub Secrets
```
gh auth login
cd ~/viemos        # folder repo kamu
base64 -w0 ~/upload-keystore.jks | gh secret set KEYSTORE_BASE64
gh secret set KEYSTORE_PASSWORD     # ketik passwordnya
gh secret set KEY_ALIAS             # ketik: upload
gh secret set KEY_PASSWORD          # password key (sama dgn di atas kalau tadi tidak dibedakan)
```
(Alternatif tanpa gh: GitHub → repo → Settings → Secrets and variables → Actions → New secret.)

## 3. Upload kode
```
cd ~/viemos
git rm -r -q --cached node_modules ci/debug.keystore 2>/dev/null
git add -A
git commit -m "Viemos 0.6.0: keamanan, 3D, keyboard sendiri"
git push
```
Workflow jalan otomatis. Download artifact:
- `viemos-aab-playstore` → file `.aab` untuk Play Store
- `viemos-apk` → APK untuk dipasang di HP
- `viemos-debug-symbols` → simpan (untuk membaca crash report)

> Catatan: APK/AAB ini ditandatangani kunci BARU, jadi tidak bisa menimpa instalan lama yang memakai debug.keystore. Backup data dulu (Setting → Download backup), uninstall, pasang yang baru, lalu Pulihkan.

## 4. Play Console
1. Daftar developer ($25 sekali bayar), buat app baru.
2. Biarkan **Play App Signing** aktif (default). Kunci yang kamu buat = *upload key*.
3. Upload `.aab` ke **Internal testing** dulu.
4. Isi: Kebijakan Privasi (URL halaman `PRIVACY.md`, mis. GitHub Pages / halaman blob GitHub), **Data safety** (tidak mengumpulkan & tidak membagikan data), rating konten, target audiens, deklarasi fitur finansial (app ini hanya pencatat).
5. Ikon 512×512: `store/icon-512.png`. Screenshot & feature graphic (1024×500) kamu siapkan sendiri.
6. Akun developer pribadi baru biasanya wajib **closed testing dengan ±12 penguji selama 14 hari** sebelum produksi — cek syarat terbaru di Play Console.
