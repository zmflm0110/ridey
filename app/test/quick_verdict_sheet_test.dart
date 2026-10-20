import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/field/quick_verdict_sheet.dart';

void main() {
  testWidgets('submits the selected common verdict', (tester) async {
    final remote = _FakeRemote();
    final repository = FieldVerificationRepository(
      remote: remote,
      queue: _MemoryQueue(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: Scaffold(
          body: QuickVerdictSheet(bikeId: 'SPB-69683', repository: repository),
        ),
      ),
    );

    expect(find.text('문제 없음'), findsOneWidget);
    await tester.tap(find.text('타이어'));
    await tester.pump();
    await tester.tap(find.text('확인 결과 남기기'));
    await tester.pumpAndSettle();

    expect(remote.records.single.bikeId, 'SPB-69683');
    expect(remote.records.single.verdict, FieldVerdict.tire);
    expect(find.text('확인 결과를 기록했어요.'), findsOneWidget);
  });
}

class _MemoryQueue implements FieldVerificationQueue {
  @override
  Future<List<FieldVerificationRecord>> load() async => const [];

  @override
  Future<void> save(List<FieldVerificationRecord> records) async {}
}

class _FakeRemote implements FieldVerificationRemote {
  final records = <FieldVerificationRecord>[];

  @override
  Future<CheckedVerdicts> fetchChecked() async => {};

  @override
  Future<void> record(FieldVerificationRecord record) async {
    records.add(record);
  }
}
