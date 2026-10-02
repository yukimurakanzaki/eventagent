import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/event_directory.dart';
import 'package:wargakas_mobile/main.dart';

class FakeDirectory implements EventDirectory {
  FakeDirectory({this.canManage = true});

  @override
  final bool canManage;
  @override
  String currentEventId = 'a';
  final events = [
    EventSummary(
      id: 'a',
      name: 'Wisata Dieng',
      startDate: DateTime(2026, 9, 12),
      endDate: DateTime(2026, 9, 14),
      archived: false,
    ),
    EventSummary(
      id: 'b',
      name: 'Rapat Akbar',
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 1),
      archived: false,
    ),
    EventSummary(
      id: 'c',
      name: 'Pesta Lama',
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 2),
      archived: true,
    ),
  ];
  NewEventDraft? created;
  final archiveCalls = <String>[];

  @override
  Future<List<EventSummary>> list() async => List.of(events);

  @override
  Future<void> select(String eventId) async => currentEventId = eventId;

  @override
  Future<void> create(NewEventDraft draft) async => created = draft;

  @override
  Future<void> setArchived(String eventId, bool archived) async {
    archiveCalls.add('$eventId:$archived');
    final index = events.indexWhere((item) => item.id == eventId);
    final old = events[index];
    events[index] = EventSummary(
      id: old.id,
      name: old.name,
      startDate: old.startDate,
      endDate: old.endDate,
      archived: archived,
    );
  }
}

Future<void> openPicker(WidgetTester tester, FakeDirectory directory) async {
  await tester.pumpWidget(
    WargakasApp(
      controller: CashbookController.forTesting(),
      eventDirectory: directory,
    ),
  );
  await tester.tap(find.text('Wisata Dieng'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists active events and tucks archived ones away', (
    tester,
  ) async {
    await openPicker(tester, FakeDirectory());

    expect(find.text('Rapat Akbar'), findsOneWidget);
    expect(find.text('Diarsipkan (1)'), findsOneWidget);
    expect(find.text('Pesta Lama'), findsNothing);
    await tester.tap(find.text('Diarsipkan (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Pesta Lama'), findsOneWidget);
    expect(find.text('Pulihkan'), findsOneWidget);
  });

  testWidgets('selecting another event switches to it', (tester) async {
    final directory = FakeDirectory();
    await openPicker(tester, directory);

    await tester.tap(find.text('Rapat Akbar'));
    await tester.pumpAndSettle();

    expect(directory.currentEventId, 'b');
    expect(find.text('Buat acara baru'), findsNothing);
  });

  testWidgets('creates an event from the form and validates first', (
    tester,
  ) async {
    final directory = FakeDirectory();
    await openPicker(tester, directory);

    await tester.tap(find.text('Buat acara baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat acara'));
    await tester.pumpAndSettle();
    expect(find.text('Nama acara wajib diisi.'), findsOneWidget);
    expect(directory.created, isNull);

    await tester.enterText(find.byType(TextField).first, 'Outing Kantor');
    await tester.tap(find.text('Buat acara'));
    await tester.pumpAndSettle();

    expect(directory.created?.name, 'Outing Kantor');
    expect(directory.created?.capacity, 20);
    expect(find.text('Acara baru'), findsNothing);
  });

  testWidgets('archives only after confirmation, restores directly', (
    tester,
  ) async {
    final directory = FakeDirectory();
    await openPicker(tester, directory);

    await tester.tap(find.text('Arsipkan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(directory.archiveCalls, isEmpty);

    await tester.tap(find.text('Arsipkan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
    await tester.pumpAndSettle();
    expect(directory.archiveCalls, ['b:true']);

    await tester.tap(find.text('Diarsipkan (2)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pulihkan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulihkan').last);
    await tester.pumpAndSettle();
    expect(directory.archiveCalls, ['b:true', 'c:false']);
  });

  testWidgets('non-treasurers can switch but not create or archive', (
    tester,
  ) async {
    await openPicker(tester, FakeDirectory(canManage: false));

    expect(find.text('Rapat Akbar'), findsOneWidget);
    expect(find.text('Buat acara baru'), findsNothing);
    expect(find.text('Arsipkan'), findsNothing);
  });

  test('draft validation mirrors the server checks', () {
    NewEventDraft draft({
      String name = 'X',
      DateTime? end,
      int capacity = 5,
      int budget = 0,
    }) => NewEventDraft(
      name: name,
      startDate: DateTime(2026, 5, 2),
      endDate: end ?? DateTime(2026, 5, 2),
      capacity: capacity,
      budget: budget,
    );

    expect(draft().validate(), isNull);
    expect(draft(name: '  ').validate(), isNotNull);
    expect(draft(name: 'x' * 121).validate(), isNotNull);
    expect(draft(end: DateTime(2026, 5, 1)).validate(), isNotNull);
    expect(draft(capacity: 0).validate(), isNotNull);
    expect(draft().toSnapshot().event.name, 'X');
  });
}
