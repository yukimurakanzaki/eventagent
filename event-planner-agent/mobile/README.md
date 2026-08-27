# Wargakas mobile shell

This is the Android-first Flutter app slice for the community-trip cashbook. It provides a large-touch-target Dieng flow for validating the fixed information architecture and stores the current event locally on the device:

`Acara Saya → Ringkasan | Peserta | Uang | Laporan`

Changes are written to a local JSON snapshot and recorded in a pending sync queue. Future reminders are scheduled as local Android notifications and restored after app startup or device reboot. When Supabase configuration is supplied, the app adds email/password login, shared event state, optimistic queue replay, and server-side audit writes. Without configuration it remains an offline demo so local validation does not require credentials.

The notification slice currently uses the fixed Indonesian timezone and inexact Android scheduling for this scenario. Production should derive the device timezone and validate battery-optimization behavior on target phones. The hosted slice still needs a linked Supabase project and live RLS/conflict testing; the treasurer-controlled chairperson access flow is implemented for an existing Supabase account.

Email confirmation returns to `io.wargakas.mobile://auth-callback/`. Keep this URL in Supabase Authentication → URL Configuration → Redirect URLs. The Flutter client passes it as `emailRedirectTo` during account creation. Android disables Flutter's competing default deep-link handler so `supabase_flutter` can process the PKCE callback.

After account creation, the login screen also offers `Kirim ulang email konfirmasi` so an expired link can be replaced without opening the Supabase dashboard.

## Run locally

From this directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To run the authenticated hosted slice, provide the Supabase project URL and publishable key without committing them:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The current debug APK is produced at `build/app/outputs/flutter-apk/app-debug.apk` after:

```bash
flutter build apk --debug
```
