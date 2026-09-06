# Wargakas mobile shell

This is the Android-first Flutter app slice for the community-trip cashbook. It provides a large-touch-target Dieng flow for validating the fixed information architecture and stores the current event locally on the device:

`Acara Saya → Ringkasan | Peserta | Uang | Laporan`

Changes are written to a local JSON snapshot and recorded in a pending sync queue. Future reminders are scheduled as local Android notifications and restored after app startup or device reboot. When Supabase configuration is supplied, the app adds email/password login, shared event state, optimistic queue replay, and server-side audit writes. Hosted mode is the default; the offline demo must be enabled explicitly with `WARGAKAS_APP_MODE=demo` so a release/test build cannot silently bypass authentication.

The notification slice currently uses the fixed Indonesian timezone and inexact Android scheduling for this scenario. Production should derive the device timezone and validate battery-optimization behavior on target phones. The hosted slice still needs a linked Supabase project and live RLS/conflict testing; the treasurer-controlled chairperson access flow is implemented for an existing Supabase account.

Email confirmation returns to `io.wargakas.mobile://auth-callback/`. Keep this URL in Supabase Authentication → URL Configuration → Redirect URLs. The Flutter client passes it as `emailRedirectTo` during account creation. Android disables Flutter's competing default deep-link handler so `supabase_flutter` can process the PKCE callback.

The authentication screen keeps responses private and accurate. Supabase may deliberately return an obfuscated success when an address already belongs to a confirmed account, so the app does not claim that a new account or email was created. It instead offers `Masuk`, `Lupa kata sandi?`, and `Kirim ulang email konfirmasi`, with a shared cooldown for email requests. Server errors are translated into actionable Indonesian guidance without exposing raw backend details.

Password recovery uses the same callback and PKCE flow. Request the link from the target device, open only the newest email on that device, and do not clear the app's data between requesting and opening the link. Token refresh and user-update events keep the new-password screen open until the user explicitly continues.

Supabase's built-in email sender is suitable only for initial testing and may restrict recipients or apply a very low project-wide limit. Configure custom SMTP before testing arbitrary external addresses or releasing the app. Until custom SMTP is verified, a locally passing recovery flow does not prove real email delivery.

## Run locally

From this directory:

```bash
flutter pub get
flutter analyze
flutter test
```

To run the authenticated hosted slice, provide the Supabase project URL and publishable key without committing them:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

To run the local demo explicitly:

```bash
flutter run --dart-define=WARGAKAS_APP_MODE=demo
```

## Test on a physical Android phone

1. On the phone, enable Developer options and USB debugging, connect the USB cable, and accept the computer authorization prompt.
2. From this directory, confirm the phone is listed as `device` rather than `offline`:

```powershell
adb devices
flutter devices
```

3. Use PowerShell 7. Set the hosted Supabase values for this session, then start the attached Flutter run:

```powershell
$env:SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co'
$env:SUPABASE_PUBLISHABLE_KEY = 'YOUR_PUBLISHABLE_KEY'
.\run-phone.ps1 -DeviceId YOUR_DEVICE_ID
```

Alternatively, save the two values in `supabase.local.json` in this directory (ignored by Git):

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY"
}
```

The script loads this file automatically; session environment variables override it. Use only the public publishable key, never a secret or service-role key. The script works from any directory when invoked by its path.

Flutter installs the debug app once, keeps the process connected, and updates Dart changes with hot reload when you press `r` in the terminal. Press `R` for a hot restart. Native Android/plugin changes may require stopping and starting the command again; this still updates the existing app without asking you to uninstall it.

If you need a standalone APK update, use `adb install -r` after rebuilding. The `-r` flag upgrades the existing installation and preserves its local data; do not use `adb uninstall` unless you intentionally want to erase the local test account/data.

The current debug APK is produced at `build/app/outputs/flutter-apk/app-debug.apk` after:

```powershell
.\run-phone.ps1 -BuildApk
```

Always use the configured build command above for a hosted APK. A plain `flutter build apk --debug` omits the Supabase values and displays “Aplikasi belum dikonfigurasi untuk login.” Replace that APK with the configured build; hot reload cannot add missing compile-time settings to an installed APK.
