import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffDistrictPickerPage extends StatefulWidget {
  const StaffDistrictPickerPage({
    super.key,
    required this.districts,
    this.selected = const [],
    this.allowSkip = true,
  });

  final List<String> districts;
  final List<String> selected;
  final bool allowSkip;

  @override
  State<StaffDistrictPickerPage> createState() => _StaffDistrictPickerPageState();
}

class _StaffDistrictPickerPageState extends State<StaffDistrictPickerPage> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, rideyTabClearance),
          children: [
            Text('담당하는 구를 고르세요', style: theme.textTheme.displayLarge),
            const SizedBox(height: 8),
            Text(
              '여러 곳을 고를 수 있어요. 건너뛰면 서울 전체를 보여 줍니다.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final district in widget.districts)
                  FilterChip(
                    label: Text(district),
                    selected: _selected.contains(district),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(district);
                        } else {
                          _selected.remove(district);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 28),
            RideyButton(
              label: '이 구부터 보기',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()..sort()),
            ),
            if (widget.allowSkip) ...[
              const SizedBox(height: 10),
              RideyButton.secondary(
                label: '건너뛰기',
                onPressed: () => Navigator.of(context).pop(const <String>[]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
