part of '../main.dart';

Future<void> showReminderDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  var dueAt = DateTime.now().add(const Duration(days: 7));
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(tr('Tambah pengingat')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: tr('Yang perlu diingat')),
            ),
            TextField(
              controller: noteController,
              decoration: InputDecoration(labelText: tr('Catatan (opsional)')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                  initialDate: dueAt,
                );
                if (picked != null) {
                  setState(
                    () => dueAt = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      dueAt.hour,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                tr('Jatuh tempo {date}', {'date': formatDateTime(dueAt)}),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                await showInfo(
                  context,
                  tr('Judul belum diisi'),
                  tr('Tulis hal yang perlu diingat terlebih dahulu.'),
                );
                return;
              }
              final error = await controller.addReminder(
                title: titleController.text,
                dueAt: dueAt,
                note: noteController.text,
              );
              if (error != null) {
                if (context.mounted) {
                  await showInfo(
                    context,
                    tr('Pengingat belum disimpan'),
                    error,
                  );
                }
                return;
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(tr('Simpan pengingat')),
          ),
        ],
      ),
    ),
  );
}

Future<void> showInviteChairpersonDialog(
  BuildContext context,
  Future<void> Function(String email) onInvite,
) async {
  final emailController = TextEditingController();
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        scrollable: true,
        title: Text(tr('Tambah ketua acara')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Masukkan email akun yang sudah dibuat di Wargakas.')),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('Email ketua acara')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final email = emailController.text.trim();
                    if (!email.contains('@')) {
                      await showInfo(
                        dialogContext,
                        tr('Email belum benar'),
                        tr('Masukkan email akun ketua acara.'),
                      );
                      return;
                    }
                    setState(() => busy = true);
                    try {
                      await onInvite(email);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      await showInfo(
                        context,
                        tr('Akses diberikan'),
                        tr(
                          '{email} sekarang dapat membuka acara ini sebagai ketua acara.',
                          {'email': email},
                        ),
                      );
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      setState(() => busy = false);
                      await showInfo(
                        dialogContext,
                        tr('Belum berhasil'),
                        error.toString(),
                      );
                    }
                  },
            child: Text(busy ? tr('Menyimpan…') : tr('Berikan akses')),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAccountDialog(
  BuildContext context,
  CashbookController controller,
  Future<void> Function() onSignOut, {
  String? email,
  String? role,
}) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(tr('Akun')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Email akun')),
                    Text(
                      email ?? tr('Akun Wargakas'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(roleLabel(role)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Data acara tetap tersimpan di Supabase dan di perangkat ini untuk digunakan saat sinyal lemah.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('Tutup')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'signOut'),
          icon: const Icon(Icons.logout),
          label: Text(tr('Keluar')),
        ),
      ],
    ),
  );
  if (action != 'signOut' || !context.mounted) return;

  if (controller.pendingOperations.isNotEmpty) {
    final pendingCount = controller.pendingOperations.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(tr('Perubahan belum tersinkron')),
        content: Text(
          tr(
            '{count} perubahan masih menunggu dikirim. Jika keluar sekarang, perubahan tetap disimpan dan akan dicoba saat akun ini masuk kembali.',
            {'count': pendingCount},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Tetap di sini')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Keluar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  try {
    await onSignOut();
  } catch (error) {
    if (context.mounted) {
      await showInfo(
        context,
        tr('Belum berhasil keluar'),
        authErrorMessage(error),
      );
    }
  }
}

Future<void> showInfo(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Mengerti')),
        ),
      ],
    ),
  );
}
