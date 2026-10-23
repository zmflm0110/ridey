enum FieldVerdict {
  tire('타이어'),
  chainAndGear('체인·기어'),
  saddleAndHandle('안장·핸들'),
  noProblem('문제 없음');

  const FieldVerdict(this.label);

  final String label;

  /// The established `rescue.verdict` contract uses this value for a bike
  /// that had no problem at the time of a field check.
  String get apiValue => this == FieldVerdict.noProblem ? '멀쩡함' : label;

  static FieldVerdict? fromApiValue(String value) {
    return switch (value) {
      '타이어' => FieldVerdict.tire,
      '체인·기어' => FieldVerdict.chainAndGear,
      '안장·핸들' => FieldVerdict.saddleAndHandle,
      '멀쩡함' => FieldVerdict.noProblem,
      _ => null,
    };
  }
}

class FieldVerificationRecord {
  const FieldVerificationRecord({
    required this.bikeId,
    required this.verdict,
    required this.day,
    this.needsAttention = false,
  });

  final String bikeId;
  final FieldVerdict verdict;
  final String day;
  final bool needsAttention;

  Map<String, dynamic> toJson() => {
    'bike': bikeId,
    'verdict': verdict.apiValue,
    'day': day,
  };

  Map<String, dynamic> toQueueJson() => {
    ...toJson(),
    'needs_attention': needsAttention,
  };

  FieldVerificationRecord copyWith({bool? needsAttention}) {
    return FieldVerificationRecord(
      bikeId: bikeId,
      verdict: verdict,
      day: day,
      needsAttention: needsAttention ?? this.needsAttention,
    );
  }

  factory FieldVerificationRecord.fromJson(Map<String, dynamic> json) {
    final bike = json['bike'];
    final verdict = json['verdict'];
    final day = json['day'];
    if (bike is! String || verdict is! String || day is! String) {
      throw const FormatException('현장 확인 대기 기록 형식이 올바르지 않습니다.');
    }
    final parsedVerdict = FieldVerdict.fromApiValue(verdict);
    if (parsedVerdict == null) {
      throw const FormatException('현장 확인 판정을 읽을 수 없습니다.');
    }
    return FieldVerificationRecord(
      bikeId: bike,
      verdict: parsedVerdict,
      day: day,
      needsAttention: json['needs_attention'] == true,
    );
  }
}

String fieldVerificationDay(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

typedef CheckedVerdicts = Map<String, Map<FieldVerdict, int>>;

class VerificationSyncResult {
  const VerificationSyncResult({
    required this.sent,
    required this.rejected,
    required this.pending,
  });

  final int sent;
  final int rejected;
  final int pending;
}

enum VerificationSubmissionStatus { sent, queued, rejected }

class VerificationSubmission {
  const VerificationSubmission(this.status, {this.pendingCount = 0});

  final VerificationSubmissionStatus status;
  final int pendingCount;
}
