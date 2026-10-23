import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/field/field_verdict.dart';

class FieldRecordsPage extends StatefulWidget {
  const FieldRecordsPage({super.key, required this.repository});

  final FieldVerificationRepository repository;

  @override
  State<FieldRecordsPage> createState() => _FieldRecordsPageState();
}

class _FieldRecordsPageState extends State<FieldRecordsPage> {
  late Future<List<FieldVerificationRecord>> _records;
  var _syncing = false;
  VerificationSyncResult? _lastSync;

  @override
  void initState() {
    super.initState();
    _records = widget.repository.pendingRecords();
  }

  Future<void> _refresh() async {
    setState(() => _records = widget.repository.pendingRecords());
    await _records;
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await widget.repository.sync();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastSync = result;
      _records = widget.repository.pendingRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FieldVerificationRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _RecordsFailure(onRetry: _refresh);
        }
        return _RecordsContent(
          records: snapshot.requireData,
          syncing: _syncing,
          lastSync: _lastSync,
          onRefresh: _refresh,
          onSync: _sync,
        );
      },
    );
  }
}

class _RecordsContent extends StatelessWidget {
  const _RecordsContent({
    required this.records,
    required this.syncing,
    required this.lastSync,
    required this.onRefresh,
    required this.onSync,
  });

  final List<FieldVerificationRecord> records;
  final bool syncing;
  final VerificationSyncResult? lastSync;
  final RefreshCallback onRefresh;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = records.where((record) => !record.needsAttention).toList();
    final attention =
        records.where((record) => record.needsAttention).toList();

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
        children: [
          Text('현장 기록', style: context.rideyPageTitle),
          const SizedBox(height: 12),
          Text(
            '연결이 끊겼을 때 기기에 보관한 현장 확인 기록이에요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.ridey.muted,
            ),
          ),
          const SizedBox(height: 28),
          if (records.isEmpty)
            const _NoPendingRecords()
          else ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text('전송 대기 ${pending.length}건'),
                subtitle: Text(
                  attention.isEmpty
                      ? '연결되면 자동 전송되며, 지금 다시 시도할 수도 있어요.'
                      : '확인이 필요한 기록 ${attention.length}건이 있어요.',
                ),
                trailing: TextButton(
                  onPressed: pending.isEmpty || syncing ? null : onSync,
                  child: syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('동기화'),
                ),
              ),
            ),
            if (lastSync != null) ...[
              const SizedBox(height: 10),
              Text(
                '최근 동기화: 전송 ${lastSync!.sent}건 · 확인 필요 ${lastSync!.rejected}건',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (attention.isNotEmpty) ...[
              Text('확인이 필요한 기록', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ...attention.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecordCard(record: record, needsAttention: true),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text('전송 대기', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ...pending.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecordCard(record: record),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, this.needsAttention = false});

  final FieldVerificationRecord record;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          needsAttention
              ? Icons.error_outline_rounded
              : Icons.cloud_upload_outlined,
          color: needsAttention ? context.ridey.signalText : context.ridey.calm,
        ),
        title: Text(record.bikeId),
        subtitle: Text(
          needsAttention
              ? '${record.verdict.label} · 전송 형식을 확인해 주세요.'
              : '${record.verdict.label} · ${record.day}',
        ),
      ),
    );
  }
}

class _NoPendingRecords extends StatelessWidget {
  const _NoPendingRecords();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_done_outlined),
            const SizedBox(height: 16),
            Text(
              '전송 대기 중인 기록이 없어요.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '현장 확인 결과는 연결이 되지 않을 때만 이곳에 안전하게 보관됩니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsFailure extends StatelessWidget {
  const _RecordsFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
    );
  }
}
