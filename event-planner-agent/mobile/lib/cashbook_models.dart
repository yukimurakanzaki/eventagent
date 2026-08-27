enum ParticipantState { active, cancelled }

enum RefundPolicy { undecided, none, partial, full }

enum TransactionType {
  participantPayment,
  sponsor,
  additionalContribution,
  expense,
  refund,
  refundReversal,
}

class EventRecord {
  const EventRecord({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.participantCapacity,
    required this.finalBudget,
    required this.sponsorName,
    required this.sponsorContribution,
    required this.openingBalance,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int participantCapacity;
  final int finalBudget;
  final String sponsorName;
  final int sponsorContribution;
  final int openingBalance;

  EventRecord copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? participantCapacity,
    int? finalBudget,
    String? sponsorName,
    int? sponsorContribution,
    int? openingBalance,
  }) {
    return EventRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      participantCapacity: participantCapacity ?? this.participantCapacity,
      finalBudget: finalBudget ?? this.finalBudget,
      sponsorName: sponsorName ?? this.sponsorName,
      sponsorContribution: sponsorContribution ?? this.sponsorContribution,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'participantCapacity': participantCapacity,
        'finalBudget': finalBudget,
        'sponsorName': sponsorName,
        'sponsorContribution': sponsorContribution,
        'openingBalance': openingBalance,
      };

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      participantCapacity: (json['participantCapacity'] as num).toInt(),
      finalBudget: (json['finalBudget'] as num).toInt(),
      sponsorName: json['sponsorName'] as String,
      sponsorContribution: (json['sponsorContribution'] as num).toInt(),
      openingBalance: (json['openingBalance'] as num).toInt(),
    );
  }
}

class ParticipantRecord {
  const ParticipantRecord({
    required this.id,
    required this.name,
    this.state = ParticipantState.active,
    this.refundPolicy = RefundPolicy.undecided,
    this.replacementForId,
    this.cancelledAt,
  });

  final String id;
  final String name;
  final ParticipantState state;
  final RefundPolicy refundPolicy;
  final String? replacementForId;
  final DateTime? cancelledAt;

  ParticipantRecord copyWith({
    String? name,
    ParticipantState? state,
    RefundPolicy? refundPolicy,
    String? replacementForId,
    DateTime? cancelledAt,
  }) {
    return ParticipantRecord(
      id: id,
      name: name ?? this.name,
      state: state ?? this.state,
      refundPolicy: refundPolicy ?? this.refundPolicy,
      replacementForId: replacementForId ?? this.replacementForId,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'state': state.name,
        'refundPolicy': refundPolicy.name,
        'replacementForId': replacementForId,
        'cancelledAt': cancelledAt?.toIso8601String(),
      };

  factory ParticipantRecord.fromJson(Map<String, dynamic> json) {
    return ParticipantRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      state: ParticipantState.values.byName(json['state'] as String),
      refundPolicy: RefundPolicy.values.byName(json['refundPolicy'] as String),
      replacementForId: json['replacementForId'] as String?,
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
    );
  }
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.participantId,
    this.relatedTransactionId,
  });

  final String id;
  final TransactionType type;
  final int amount;
  final String description;
  final DateTime createdAt;
  final String? participantId;
  final String? relatedTransactionId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'participantId': participantId,
        'relatedTransactionId': relatedTransactionId,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toInt(),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      participantId: json['participantId'] as String?,
      relatedTransactionId: json['relatedTransactionId'] as String?,
    );
  }
}

class ReminderRecord {
  const ReminderRecord({
    required this.id,
    required this.title,
    required this.dueAt,
    this.note = '',
    this.isDone = false,
  });

  final String id;
  final String title;
  final DateTime dueAt;
  final String note;
  final bool isDone;

  ReminderRecord copyWith({String? title, DateTime? dueAt, String? note, bool? isDone}) {
    return ReminderRecord(
      id: id,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueAt': dueAt.toIso8601String(),
        'note': note,
        'isDone': isDone,
      };

  factory ReminderRecord.fromJson(Map<String, dynamic> json) {
    return ReminderRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      note: json['note'] as String? ?? '',
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.createdAt,
    required this.payload,
    this.attempts = 0,
  });

  final String id;
  final String entity;
  final String entityId;
  final String action;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final int attempts;

  SyncOperation copyWith({int? attempts}) {
    return SyncOperation(
      id: id,
      entity: entity,
      entityId: entityId,
      action: action,
      createdAt: createdAt,
      payload: payload,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity': entity,
        'entityId': entityId,
        'action': action,
        'createdAt': createdAt.toIso8601String(),
        'payload': payload,
        'attempts': attempts,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entity: json['entity'] as String,
      entityId: json['entityId'] as String,
      action: json['action'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class CashbookSnapshot {
  const CashbookSnapshot({
    required this.event,
    required this.participants,
    required this.transactions,
    required this.reminders,
    required this.pendingOperations,
    this.syncVersion = 0,
  });

  final EventRecord event;
  final List<ParticipantRecord> participants;
  final List<TransactionRecord> transactions;
  final List<ReminderRecord> reminders;
  final List<SyncOperation> pendingOperations;
  final int syncVersion;

  CashbookSnapshot copyWith({
    EventRecord? event,
    List<ParticipantRecord>? participants,
    List<TransactionRecord>? transactions,
    List<ReminderRecord>? reminders,
    List<SyncOperation>? pendingOperations,
    int? syncVersion,
  }) {
    return CashbookSnapshot(
      event: event ?? this.event,
      participants: participants ?? this.participants,
      transactions: transactions ?? this.transactions,
      reminders: reminders ?? this.reminders,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'event': event.toJson(),
        'participants': participants.map((item) => item.toJson()).toList(),
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'reminders': reminders.map((item) => item.toJson()).toList(),
        'pendingOperations': pendingOperations.map((item) => item.toJson()).toList(),
        'syncVersion': syncVersion,
      };

  factory CashbookSnapshot.fromJson(Map<String, dynamic> json) {
    return CashbookSnapshot(
      event: EventRecord.fromJson(Map<String, dynamic>.from(json['event'] as Map)),
      participants: (json['participants'] as List)
          .map((item) => ParticipantRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      transactions: (json['transactions'] as List)
          .map((item) => TransactionRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      reminders: (json['reminders'] as List)
          .map((item) => ReminderRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      pendingOperations: (json['pendingOperations'] as List)
          .map((item) => SyncOperation.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      syncVersion: (json['syncVersion'] as num?)?.toInt() ?? 0,
    );
  }

  factory CashbookSnapshot.demo() {
    final now = DateTime.now();
    return CashbookSnapshot(
      event: EventRecord(
        id: 'event-dieng-2026',
        name: 'Wisata Dieng',
        startDate: DateTime(2026, 9, 12),
        endDate: DateTime(2026, 9, 14),
        participantCapacity: 18,
        finalBudget: 40300000,
        sponsorName: 'Koperasi Warga',
        sponsorContribution: 5000000,
        openingBalance: 2000000,
      ),
      participants: const [
        ParticipantRecord(id: 'p-sari', name: 'Ibu Sari'),
        ParticipantRecord(id: 'p-budi', name: 'Pak Budi'),
        ParticipantRecord(
          id: 'p-rina',
          name: 'Ibu Rina',
          state: ParticipantState.cancelled,
          refundPolicy: RefundPolicy.none,
          cancelledAt: null,
        ),
        ParticipantRecord(
          id: 'p-rina-replacement',
          name: 'Pengganti Ibu Rina',
          replacementForId: 'p-rina',
        ),
      ],
      transactions: [
        TransactionRecord(
          id: 'tx-sari',
          type: TransactionType.participantPayment,
          amount: 1850000,
          description: 'Pembayaran tahap 1',
          participantId: 'p-sari',
          createdAt: now,
        ),
        TransactionRecord(
          id: 'tx-budi',
          type: TransactionType.participantPayment,
          amount: 1000000,
          description: 'Pembayaran tahap 1',
          participantId: 'p-budi',
          createdAt: now,
        ),
        TransactionRecord(
          id: 'tx-rina',
          type: TransactionType.participantPayment,
          amount: 1850000,
          description: 'Pembayaran sebelum pembatalan',
          participantId: 'p-rina',
          createdAt: now,
        ),
        TransactionRecord(
          id: 'tx-bus',
          type: TransactionType.expense,
          amount: 9950000,
          description: 'Uang muka bus',
          createdAt: now,
        ),
      ],
      reminders: [
        ReminderRecord(
          id: 'reminder-collection',
          title: 'Pengumpulan tahap 2',
          dueAt: DateTime(2026, 8, 28, 9),
          note: 'Kirim pengingat peserta yang belum lunas.',
        ),
      ],
      pendingOperations: const [],
      syncVersion: 0,
    );
  }
}
