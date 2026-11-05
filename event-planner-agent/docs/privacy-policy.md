# Wargakas Privacy Policy

Last updated: [Effective date, e.g. 2026-11-05]
Operator (data controller): [Operator name], [Operator address], [Country]
Contact: [Support email - replace before store submission]. Until then: https://github.com/yukimurakanzaki/eventagent/issues (do not post personal data in public issues).

Wargakas is a shared cashbook for community events such as trips and gatherings. This policy explains what we collect, why, and your choices. It is written to meet the EU/UK GDPR, the California CCPA/CPRA, and Indonesia's Personal Data Protection Law (UU No. 27 Tahun 2022, "UU PDP").

## 1. Summary

- We collect only what the app needs to work: your account, the event data you type in, and optional receipt photos.
- No ads. No analytics or tracking SDKs. We do not sell or rent your data.
- Everyone in an event can see that event's data. That is the purpose of the app (transparency).
- You can export your data (PDF/CSV) and delete your account inside the app.

## 2. What we collect

| Data | Source | Purpose | Who can see it |
|---|---|---|---|
| Email address and password (stored only as a hash by Supabase Auth) | You, at sign-up | Sign-in, account recovery, email confirmation | You; the service operator for support |
| Event data: event name, dates, budget, currency | You | Run the cashbook | Event members |
| Participant names | You | Track who paid | Event members; also anyone with the public share link |
| Participant phone numbers (optional) | You | Used on your device to open WhatsApp reminders. They are stored inside the shared event data, so **event members can see them**. They are **not** included in reports (PDF/CSV/text) and are **not** meant for the public share link. | Event members |
| Transactions: description, amount, date, category | You | Cashbook | Event members; share link viewers (descriptions and amounts) |
| Receipt photos (optional) | You | Evidence for an expense | Event members only (private storage; not in the share link) |
| Audit trail: who changed what and when (linked to your account id) | Generated | Accountability and conflict handling | Event members |
| Personal settings: language, theme, text size, default currency, accent colour | You | Personalise the app | Stored **only on your device** |
| Reminder schedule | You | Local notifications | Stored on your device |

We do not collect your location, contacts, advertising ID, or device identifiers for tracking. The app asks for camera/gallery access only when you add a receipt, and notification permission only for reminders.

Participants may be people who never created an account. If you enter someone's name or phone number, you are responsible for having a good reason and, where required, their agreement.

## 3. Legal basis (GDPR Art. 6 / UU PDP Art. 20)

- **Contract / providing the service**: account, event data, sync, share link, audit trail.
- **Consent**: optional phone numbers, receipt photos, and notification permission. You can withdraw by removing the data or turning the permission off.
- **Legitimate interests**: security, abuse prevention, keeping an accurate group audit trail.
- **Legal obligation**: when the law requires us to keep or disclose data.

## 4. Where data is stored

- On your device: a cached copy of your events (app storage) so the app works offline, plus your personal settings.
- In the cloud: Supabase (Postgres database, Auth, private file Storage) in the region **[Supabase region, e.g. Singapore (ap-southeast-1)]**. Data may therefore be processed outside your country. Where required we rely on appropriate safeguards (such as standard contractual clauses) with our processor.

## 5. Sharing

- **Supabase** acts as our processor (hosting, database, authentication, storage). **[Email provider, if custom SMTP is used, e.g. Resend/SendGrid]** sends account emails as a processor.
- **Event members** see the event's data as described above.
- **Public share link**: anyone who has the link can view, without an account, the event totals, participant names and payment status, and transactions (descriptions, amounts). They cannot see phone numbers or receipt photos. The treasurer can revoke the link at any time; revoked links stop working immediately. Only share the link with people you trust: anyone you give it to can pass it on.
- **Reports you export** (PDF/CSV/WhatsApp text) leave the app when you share them. We do not control where you send them.
- We do not sell or share personal data for advertising (CCPA: we do not "sell" or "share" personal information).
- We may disclose data if legally required.

## 6. Retention

- Account and event data are kept while your account and the event workspace exist.
- When you delete your account: your email and login are deleted; if you are the treasurer, the treasurer role passes to another member, or the whole workspace (events, transactions, receipts) is deleted if nobody else is a member; your user id is cleared from shared history, so past entries remain for the group but are no longer linked to you.
- Receipt files of a deleted workspace are removed in routine cleanup within [30] days. Backups are overwritten within [retention period of the Supabase plan, e.g. 7-30] days.
- Locally cached data stays on your device until you clear app data or uninstall.

## 7. Your rights

Depending on where you live (GDPR, UK GDPR, CCPA/CPRA, UU PDP), you may have the right to: be informed, **access** your data, **correct** it, **export** it (portability), **delete** it, restrict or object to processing, withdraw consent, and complain to a regulator. In Indonesia you may also seek compensation for violations as provided by UU PDP. We do not discriminate against you for using these rights.

How to use them:
- **Access/export**: Reports tab, export PDF or CSV of an event. For a full copy of your account data, email us.
- **Correction**: edit the data in the app (changes are recorded in the audit trail), or email us.
- **Deletion**: Account (Akun) -> **Hapus akun** in the app. You can also email us from your registered address, or use [Account deletion web page URL, required by Google Play] .
- Other requests: email [Support email]. We reply within 30 days (GDPR) or the period required by local law.

Note: because event data is shared, deleting your account does not delete other members' records of the event, except as described in section 6.

## 8. Children

Wargakas is for a general audience and is not directed to children under 13 (or under 16 where local law requires parental consent). We do not knowingly collect data from them. If you believe a child gave us data, contact us and we will delete it.

## 9. Security

Connections use HTTPS/TLS. Passwords are hashed. Database access is restricted by row-level security so you can only read events you belong to. Receipt photos live in a private bucket with member-only access and short-lived download links. The app ships only a public client key; no administrative keys. No system is perfectly secure; tell us promptly about any concern. If a personal-data breach occurs, we will notify affected users and authorities as the law requires (for example within 72 hours under GDPR; 3x24 hours under UU PDP).

## 10. International users

If you are in the EU/UK, the controller is [Operator name]; [EU/UK representative, if required]. For UU PDP purposes, [Data protection officer / contact person, if appointed].

## 11. Changes

We may update this policy. We will change the date above and, for material changes, tell you in the app or by email.

## 12. Contact

[Operator name] - [Support email] - [Postal address]

---

## Ringkasan dalam Bahasa Indonesia

(Ringkasan ini membantu pembaca; versi lengkap berbahasa Inggris di atas berlaku jika ada perbedaan, kecuali hukum setempat menentukan lain.)

- **Pengendali data**: [Operator name]. Kontak: [Support email].
- **Data yang kami simpan**: email dan kata sandi (disimpan dalam bentuk hash), data acara yang Anda isi (nama acara, tanggal, anggaran, nama peserta, transaksi), nomor telepon peserta (opsional), foto nota (opsional), dan jejak perubahan (siapa mengubah apa).
- **Nomor telepon** dipakai di perangkat Anda untuk pengingat lewat WhatsApp, tetapi tersimpan dalam data acara bersama sehingga **dapat dilihat anggota acara**. Nomor tidak masuk laporan dan tidak tampil di tautan publik.
- **Tautan publik (hanya-baca)**: siapa pun yang memegang tautan dapat melihat total, nama peserta dan status bayar, serta transaksi. Nomor telepon dan foto nota tidak terlihat. Bendahara dapat mencabut tautan kapan saja.
- **Tanpa iklan, tanpa pelacak analitik, tidak menjual data.**
- **Penyimpanan**: di perangkat (agar bisa dipakai offline) dan di Supabase, wilayah [Supabase region]. Pengaturan pribadi (bahasa, tema, ukuran huruf) hanya di perangkat.
- **Dasar hukum**: pelaksanaan layanan, persetujuan (nomor telepon, foto, notifikasi), kepentingan yang sah (keamanan), dan kewajiban hukum, sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.
- **Hak Anda**: mengakses, memperbaiki, mengekspor (PDF/CSV), menghapus, menarik persetujuan, dan mengajukan keberatan. Hapus akun: menu Akun -> **Hapus akun**. Peran bendahara dialihkan ke anggota lain, atau ruang kerja dihapus jika tidak ada anggota lain; identitas Anda dihapus dari riwayat bersama.
- **Anak-anak**: aplikasi tidak ditujukan untuk anak di bawah 13 tahun.
- **Keamanan**: koneksi terenkripsi (HTTPS), kata sandi di-hash, akses data dibatasi per acara, foto nota disimpan privat.
- **Pertanyaan**: hubungi [Support email].
