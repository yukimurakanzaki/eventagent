import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthOperation { signIn, signUp, resend, reset, updatePassword, session }

String? validateAuthEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Masukkan email Anda.';
  if (email.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$').hasMatch(email)) {
    return 'Masukkan email lengkap, misalnya nama@gmail.com.';
  }
  final local = email.split('@').first;
  if (local.length > 64 ||
      local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..')) {
    return 'Periksa kembali penulisan email Anda.';
  }
  return null;
}

String? validateNewPassword(String password, String confirmation) {
  if (password.trim().isEmpty || password.length < 6) {
    return 'Kata sandi minimal 6 karakter. Gunakan kata sandi yang sulit ditebak.';
  }
  if (password != confirmation) return 'Ulangan kata sandi belum sama.';
  return null;
}

bool isAuthRateLimit(Object error) =>
    error is AuthException &&
    (error.statusCode == '429' ||
        const {
          'over_email_send_rate_limit',
          'over_request_rate_limit',
        }.contains(error.code));

bool isExpiredAuthSession(Object error) =>
    error is AuthSessionMissingException ||
    (error is AuthException &&
        const {
          'session_not_found',
          'session_expired',
          'refresh_token_not_found',
          'refresh_token_already_used',
          'user_not_found',
          'user_banned',
        }.contains(error.code));

String authErrorMessage(
  Object error, {
  AuthOperation operation = AuthOperation.session,
}) {
  final code = error is AuthException ? error.code : null;
  // Only recognize specific legacy messages. "invalid credentials" is not
  // an invalid email link, and server internals must never become UI copy.
  final message = error is AuthException ? error.message.toLowerCase() : '';
  if (code == 'invalid_credentials' || message == 'invalid login credentials') {
    return 'Email atau kata sandi tidak cocok. Periksa kembali, atau pilih Lupa kata sandi?';
  }
  if (code == 'email_not_confirmed' || message == 'email not confirmed') {
    return 'Email belum dikonfirmasi. Buka email konfirmasi terbaru atau kirim ulang di bawah.';
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      message == 'user already registered') {
    return 'Email ini sudah terdaftar. Pilih Masuk, atau Lupa kata sandi? jika tidak ingat kata sandi lama.';
  }
  if (code == 'otp_expired' ||
      code == 'otp_disabled' ||
      error.toString().contains('otp_expired')) {
    return 'Link email sudah kedaluwarsa atau tidak valid. Minta link baru, lalu coba lagi. Buka hanya email terbaru di perangkat yang meminta link.';
  }
  if (error is AuthPKCEGrantCodeExchangeError ||
      const {
            'flow_state_not_found',
            'flow_state_expired',
            'bad_code_verifier',
            'validation_failed',
          }.contains(code) &&
          operation == AuthOperation.session) {
    return 'Link tidak dapat dibuka di perangkat ini atau sudah digunakan. Minta link baru dari aplikasi ini, lalu buka email terbaru di perangkat yang sama.';
  }
  if (isExpiredAuthSession(error)) {
    return 'Sesi sudah berakhir. Masuk kembali atau minta link pemulihan baru.';
  }
  if (isAuthRateLimit(error)) {
    return 'Terlalu banyak permintaan. Tunggu sebelum mencoba lagi. Jika email tetap dibatasi, coba lagi nanti; batas pengiriman berlaku untuk seluruh aplikasi.';
  }
  if (code == 'email_address_invalid' || code == 'validation_failed') {
    return 'Email atau isian belum valid. Periksa kembali data Anda.';
  }
  if (code == 'email_address_not_authorized' ||
      message.contains('error sending confirmation') ||
      message.contains('error sending recovery')) {
    return 'Layanan email belum dapat mengirim ke alamat ini. Hubungi pengelola Wargakas untuk memeriksa pengaturan pengiriman email.';
  }
  if (code == 'signup_disabled' || code == 'email_provider_disabled') {
    return 'Pendaftaran atau masuk dengan email sedang dinonaktifkan. Hubungi pengelola Wargakas.';
  }
  if (code == 'weak_password' || error is AuthWeakPasswordException) {
    return 'Kata sandi belum memenuhi aturan keamanan. Gunakan kata sandi lebih panjang dengan huruf besar, huruf kecil, angka, dan simbol; hindari kata sandi umum.';
  }
  if (code == 'same_password') {
    return 'Kata sandi baru harus berbeda dari kata sandi lama.';
  }
  if (code == 'reauthentication_needed' ||
      code == 'reauthentication_not_valid') {
    return 'Verifikasi ulang diperlukan. Minta link pemulihan baru sebelum mengganti kata sandi.';
  }
  if (code == 'captcha_failed') {
    return 'Verifikasi keamanan belum berhasil. Coba lagi atau hubungi pengelola Wargakas.';
  }
  if (error is TimeoutException) {
    return 'Koneksi terlalu lama. Hasil permintaan belum dapat dipastikan. Periksa email atau coba Masuk sebelum mengulangi permintaan.';
  }
  if (error is AuthRetryableFetchException || error is! AuthException) {
    return 'Tidak dapat terhubung. Periksa koneksi internet, lalu coba lagi.';
  }
  return 'Permintaan belum berhasil. Coba lagi nanti. Jika tetap gagal, hubungi pengelola Wargakas.';
}

const authEmailHelp =
    'Periksa folder Spam. Gunakan link dari email terbaru dan buka di perangkat yang meminta link. Jangan hapus data aplikasi sebelum membuka link.';

const signupAcceptedMessage =
    'Permintaan diproses. Jika email ini belum terdaftar, periksa email untuk konfirmasi. Jika sudah punya akun, pilih Masuk dengan kata sandi lama atau Lupa kata sandi?.';
const resetAcceptedMessage =
    'Permintaan diproses. Jika alamat ini memiliki akun yang dapat dipulihkan, Anda akan menerima email pemulihan. Jika belum punya akun, pilih Buat akun.';
const resendAcceptedMessage =
    'Permintaan diproses. Jika akun masih menunggu konfirmasi, Anda akan menerima email baru. Jika sudah dikonfirmasi, pilih Masuk.';
