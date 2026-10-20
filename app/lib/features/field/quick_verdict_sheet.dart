import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';

Future<VerificationSubmission?> showQuickVerdictSheet(
  BuildContext context, {
  required String bikeId,
  required FieldVerificationRepository repository,
}) {
  return showModalBottomSheet<VerificationSubmission>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickVerdictSheet(bikeId: bikeId, repository: repository),
  );
}

class QuickVerdictSheet extends StatefulWidget {
  const QuickVerdictSheet({
    super.key,
    required this.bikeId,
    required this.repository,
  });

  final String bikeId;
  final FieldVerificationRepository repository;

  @override
  State<QuickVerdictSheet> createState() => _QuickVerdictSheetState();
}

class _QuickVerdictSheetState extends State<QuickVerdictSheet> {
  FieldVerdict? _verdict;
  VerificationSubmission? _result;
  var _submitting = false;

  Future<void> _submit() async {
    final verdict = _verdict;
    if (verdict == null || _submitting) return;

    setState(() => _submitting = true);
    final result = await widget.repository.submit(
      FieldVerificationRecord(
        bikeId: widget.bikeId,
        verdict: verdict,
        day: fieldVerificationDay(DateTime.now()),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: result == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현장에서 확인하기', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(widget.bikeId, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    '이 결과는 업무 우선순위에 현장 확인 상태로 반영돼요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.ridey.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ...FieldVerdict.values.map(
                    (verdict) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VerdictChoice(
                        verdict: verdict,
                        selected: _verdict == verdict,
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _verdict = verdict),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _verdict == null || _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('확인 결과 남기기'),
                  ),
                ],
              )
            : _SubmissionResult(
                result: result,
                onClose: () => Navigator.of(context).pop(result),
              ),
      ),
    );
  }
}

class _VerdictChoice extends StatelessWidget {
  const _VerdictChoice({
    required this.verdict,
    required this.selected,
    required this.onPressed,
  });

  final FieldVerdict verdict;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(56),
        backgroundColor: selected ? context.ridey.signalSoft : null,
        side: BorderSide(
          color: selected ? context.ridey.signal : context.ridey.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? context.ridey.signalText : context.ridey.muted,
          ),
          const SizedBox(width: 12),
          Text(verdict.label),
        ],
      ),
    );
  }
}

class _SubmissionResult extends StatelessWidget {
  const _SubmissionResult({required this.result, required this.onClose});

  final VerificationSubmission result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (icon, headline, message) = switch (result.status) {
      VerificationSubmissionStatus.sent => (
        Icons.check_circle_outline_rounded,
        '확인 결과를 기록했어요.',
        '다음 자전거를 확인하거나 대여소 작업으로 돌아갈 수 있어요.',
      ),
      VerificationSubmissionStatus.queued => (
        Icons.cloud_off_outlined,
        '기기에 안전하게 보관했어요.',
        '연결되면 자동으로 전송해요. 대기 중인 기록 ${result.pendingCount}건',
      ),
      VerificationSubmissionStatus.rejected => (
        Icons.error_outline_rounded,
        '기록하지 못했어요.',
        '입력 형식 또는 전송 제한을 확인한 뒤 다시 시도해 주세요.',
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 40, color: context.ridey.calm),
        const SizedBox(height: 18),
        Text(headline, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onClose, child: const Text('대여소로 돌아가기')),
      ],
    );
  }
}
