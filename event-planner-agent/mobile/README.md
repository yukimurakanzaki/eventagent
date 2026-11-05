# Wargakas mobile app

Flutter app (Android, iOS and web) for a transparent shared cashbook for community events. Navigation:

`Acara Saya → Ringkasan | Peserta | Uang | Laporan`

## What it does

- Offline-first: every change is saved on the phone and queued for sync; conflicts are never merged silently.
- 13 languages (follow the phone or pick one in Settings; Arabic is right-to-left), 40+ currencies stored in each currency's minor unit, locale-aware dates and numbers.
- Personal settings per device: language, light/dark/automatic theme, text size, accent colour, high contrast, reduced motion, default currency. First-run welcome screen.
- Participants and committee members in one list (the committee pays too), optional WhatsApp number for personal payment reminders (never printed in reports or the share link), search for large groups.
- Expenses with categories and optional receipt photos (uploaded to a private Supabase bucket); expenses without a receipt are labelled "tanpa nota" so gaps are visible.
- Sponsor money may be added or changed at any time; every change is in the audit history and the per-person target is recalculated.
- Reports: PDF (embedded Noto fonts for Latin, Vietnamese, Thai, Arabic, Devanagari; CJK font fetched on demand), WhatsApp text with per-transaction detail, CSV for Excel, and a revocable read-only web link for participants (no account needed).
- Roles: treasurer (manages access and events), chairperson, committee. In-app account deletion.
- Reminders use the phone's own timezone.

Roadmap evidence and decisions live in `../source-of-truth`; go-live steps in `../docs/production-runbook.md`.

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

## Build the signed pilot APK

Create the stable pilot key once. The keystore is stored under local application data and `android/key.properties` is ignored by Git:

```powershell
.\setup-pilot-signing.ps1
.\run-phone.ps1 -BuildPilotApk
```

The configured release APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Back up both the external keystore and ignored key properties securely; losing them prevents future in-place upgrades. The permanent application ID is `io.wargakas.mobile`. Existing builds using the old example ID require one intentional reinstall, then future pilot APKs can use `adb install -r`.
