import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/main.dart';

CashbookSnapshot _bigSnapshot() {
  final demo = CashbookSnapshot.demo();
  const names = [
    'Agus',
    'Bambang',
    'Citra',
    'Dedi',
    'Eka',
    'Fajar',
    'Gita',
    'Hadi',
    'Indah',
    'Joko',
  ];
  return demo.copyWith(
    participants: [
      for (var i = 0; i < names.length; i++)
        ParticipantRecord(
          id: 'p$i',
          name: names[i],
          role: i == 0
              ? ParticipantRole.committee
              : ParticipantRole.participant,
        ),
    ],
    transactions: const [],
  );
}

Future<void> _openParticipants(
  WidgetTester tester,
  CashbookController c,
) async {
  await tester.pumpWidget(WargakasApp(controller: c));
  await tester.tap(find.text('Peserta'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    // Restore defaults if a test replaced them.
  });

  testWidgets('adding a committee member saves role and phone, shows badge', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await _openParticipants(tester, controller);

    await tester.tap(find.text('Tambah peserta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dewi');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('participant-role')),
        matching: find.text('Panitia'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('participant-phone')),
      '0812 3456',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final added = controller.participants.firstWhere((p) => p.name == 'Dewi');
    expect(added.role, ParticipantRole.committee);
    expect(added.phone, '0812 3456');
    final tile = find.ancestor(
      of: find.text('Dewi'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: tile.first, matching: find.text('Panitia')),
      findsOneWidget,
    );
  });

  testWidgets('search appears only above 8 participants and filters', (
    tester,
  ) async {
    await _openParticipants(tester, CashbookController.forTesting());
    expect(find.byKey(const Key('participant-search')), findsNothing);

    final big = CashbookController.forTesting(initial: _bigSnapshot());
    await _openParticipants(tester, big);
    expect(find.byKey(const Key('participant-search')), findsOneWidget);
    expect(find.text('Cari peserta'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('participant-search')), 'cIT');
    await tester.pumpAndSettle();
    expect(find.text('Citra'), findsOneWidget);
    expect(find.text('Agus'), findsNothing);

    // Committee filter chip narrows to committee members.
    await tester.enterText(find.byKey(const Key('participant-search')), '');
    await tester.tap(find.widgetWithText(FilterChip, 'Panitia (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Agus'), findsOneWidget);
    expect(find.text('Bambang'), findsNothing);
  });

  testWidgets('reminder action only for unpaid or partial active people', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await _openParticipants(tester, controller);
    final target = controller.contributionTarget;
    final paid = controller.participants.firstWhere(
      (p) => p.state == ParticipantState.active && p.id == 'p-sari',
    );
    // Demo: Ibu Sari paid 1.850.000; compare with the target to decide.
    final sariRemaining = target - 1850000;
    await tester.tap(find.text('Ibu Sari'));
    await tester.pumpAndSettle();
    expect(
      find.text('Kirim pengingat'),
      sariRemaining > 0 ? findsOneWidget : findsNothing,
    );
    expect(paid.name, 'Ibu Sari');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Cancelled participants never get a reminder.
    await tester.scrollUntilVisible(find.text('Ibu Rina'), 200);
    await tester.tap(find.text('Ibu Rina'));
    await tester.pumpAndSettle();
    expect(find.text('Kirim pengingat'), findsNothing);
  });

  testWidgets('reminder opens WhatsApp, falls back to share without phone', (
    tester,
  ) async {
    final snapshot = _bigSnapshot();
    final controller = CashbookController.forTesting(
      initial: snapshot.copyWith(
        participants: [
          snapshot.participants[0].copyWith(phone: '+62 812-34'),
          snapshot.participants[1],
        ],
      ),
    );
    final launched = <Uri>[];
    final shared = <String>[];
    final oldLauncher = reminderLauncher;
    final oldSharer = reminderSharer;
    reminderLauncher = (uri) async {
      launched.add(uri);
      return true;
    };
    reminderSharer = (text) async => shared.add(text);
    addTearDown(() {
      reminderLauncher = oldLauncher;
      reminderSharer = oldSharer;
    });

    await _openParticipants(tester, controller);
    await tester.tap(find.text('Agus'));
    await tester.pumpAndSettle();
    expect(find.text('Kirim pengingat'), findsOneWidget);
    await tester.tap(find.text('Kirim pengingat'));
    await tester.pumpAndSettle();
    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      startsWith('https://wa.me/6281234?text='),
    );
    expect(launched.single.queryParameters['text'], contains('Halo Agus'));
    expect(shared, isEmpty);

    await tester.ensureVisible(find.text('Bambang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bambang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim pengingat'));
    await tester.pumpAndSettle();
    expect(launched, hasLength(1));
    expect(shared.single, contains('Halo Bambang'));
  });
}
