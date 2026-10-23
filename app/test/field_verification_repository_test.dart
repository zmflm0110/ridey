import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';

void main() {
  const record = FieldVerificationRecord(
    bikeId: 'SPB-69683',
    verdict: FieldVerdict.tire,
    day: '2026-10-21',
  );

  test('uses the established API value for a no-problem verdict', () {
    expect(FieldVerdict.noProblem.apiValue, '멀쩡함');
    expect(FieldVerdict.fromApiValue('멀쩡함'), FieldVerdict.noProblem);
  });

  test(
    'queues a record after a transient send failure and syncs later',
    () async {
      final queue = _MemoryQueue();
      final remote = _FakeRemote(
        error: const FieldVerificationRemoteException(500),
      );
      final repository = FieldVerificationRepository(
        remote: remote,
        queue: queue,
      );

      final submitted = await repository.submit(record);

      expect(submitted.status, VerificationSubmissionStatus.queued);
      expect(submitted.pendingCount, 1);
      expect(await repository.pendingCount(), 1);

      remote.error = null;
      final synced = await repository.sync();

      expect(synced.sent, 1);
      expect(synced.rejected, 0);
      expect(synced.pending, 0);
      expect(remote.records, [record]);
    },
  );

  test('does not queue a record the server rejects', () async {
    final repository = FieldVerificationRepository(
      remote: _FakeRemote(error: const FieldVerificationRejectedException(422)),
      queue: _MemoryQueue(),
    );

    final submitted = await repository.submit(record);

    expect(submitted.status, VerificationSubmissionStatus.rejected);
    expect(await repository.pendingCount(), 0);
  });

  test(
    'keeps rejected queued records for attention and retains records that still fail',
    () async {
      final rejected = record;
      const retry = FieldVerificationRecord(
        bikeId: 'SPB-69684',
        verdict: FieldVerdict.chainAndGear,
        day: '2026-10-21',
      );
      final queue = _MemoryQueue([rejected, retry]);
      final remote = _SequenceRemote([
        const FieldVerificationRejectedException(400),
        const FieldVerificationRemoteException(503),
      ]);
      final repository = FieldVerificationRepository(
        remote: remote,
        queue: queue,
      );

      final result = await repository.sync();

      expect(result.sent, 0);
      expect(result.rejected, 1);
      expect(result.pending, 2);
      final queued = await queue.load();
      expect(queued, hasLength(2));
      expect(queued.first.needsAttention, isTrue);
      expect(queued.last, retry);
    },
  );

  test('keeps the checked verdict counts grouped by bike', () async {
    final repository = FieldVerificationRepository(
      remote: _FakeRemote(
        checked: {
          'SPB-69683': {FieldVerdict.tire: 2, FieldVerdict.noProblem: 1},
        },
      ),
      queue: _MemoryQueue(),
    );

    expect(
      await repository.fetchChecked(),
      containsPair('SPB-69683', containsPair(FieldVerdict.tire, 2)),
    );
  });
}

class _MemoryQueue implements FieldVerificationQueue {
  _MemoryQueue([List<FieldVerificationRecord>? initial])
    : _records = [...?initial];

  List<FieldVerificationRecord> _records;

  @override
  Future<List<FieldVerificationRecord>> load() async => [..._records];

  @override
  Future<void> save(List<FieldVerificationRecord> records) async {
    _records = [...records];
  }
}

class _FakeRemote implements FieldVerificationRemote {
  _FakeRemote({this.error, CheckedVerdicts? checked})
    : _checked = checked ?? {};

  Object? error;
  final CheckedVerdicts _checked;
  final records = <FieldVerificationRecord>[];

  @override
  Future<CheckedVerdicts> fetchChecked() async => _checked;

  @override
  Future<void> record(FieldVerificationRecord record) async {
    if (error != null) throw error!;
    records.add(record);
  }
}

class _SequenceRemote implements FieldVerificationRemote {
  _SequenceRemote(this._errors);

  final List<Object> _errors;

  @override
  Future<CheckedVerdicts> fetchChecked() async => {};

  @override
  Future<void> record(FieldVerificationRecord record) async {
    throw _errors.removeAt(0);
  }
}
