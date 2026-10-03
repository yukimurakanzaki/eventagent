import 'cashbook_models.dart';

class EventSummary {
  const EventSummary({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.archived,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool archived;
}

class NewEventDraft {
  const NewEventDraft({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.capacity,
    required this.budget,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int capacity;
  final int budget;

  /// Mirrors the server checks so errors show before a network round trip.
  String? validate() {
    if (name.trim().isEmpty) return 'Nama acara wajib diisi.';
    if (name.trim().length > 120) return 'Nama acara maksimal 120 karakter.';
    if (endDate.isBefore(startDate)) {
      return 'Tanggal selesai tidak boleh sebelum tanggal mulai.';
    }
    if (capacity <= 0) return 'Kapasitas harus lebih dari 0.';
    if (budget < 0) return 'Anggaran tidak boleh negatif.';
    return null;
  }

  CashbookSnapshot toSnapshot() => CashbookSnapshot.blank().copyWith(
    event: CashbookSnapshot.blank().event.copyWith(
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      participantCapacity: capacity,
      finalBudget: budget,
    ),
  );
}

/// What the event picker needs from the hosted account. `select` and
/// `create` swap the open event; the host reloads the screen.
abstract interface class EventDirectory {
  String get currentEventId;

  /// Only the treasurer may create, archive, or restore events.
  bool get canManage;

  Future<List<EventSummary>> list();

  Future<void> select(String eventId);

  Future<void> create(NewEventDraft draft);

  Future<void> setArchived(String eventId, bool archived);
}
