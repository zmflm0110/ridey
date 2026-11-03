import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';

/// 지도 앱의 기본 꼴: [map] 이 화면을 채우고, [children] 은 아래 시트에 담는다.
/// 시트는 낮게·중간·높게 멈추고, 높이와 상관없이 뒤의 지도를 만질 수 있다.
/// 홈(시민)과 구별 현황(직원)이 같은 모양을 쓴다.
class RideyMapSheet extends StatelessWidget {
  const RideyMapSheet({
    super.key,
    required this.map,
    required this.children,
    this.onRefresh,
  });

  final Widget map;
  final List<Widget> children;

  /// 시트를 끝까지 올린 뒤 아래로 당기면 새로 받는다.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: map),
        DraggableScrollableSheet(
          initialChildSize: .52,
          minChildSize: .22,
          maxChildSize: .94,
          snap: true,
          snapSizes: const [.22, .52, .94],
          builder: (context, scroll) {
            final c = context.ridey;
            Widget body = SingleChildScrollView(
              controller: scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, rideyTabClearance),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: '목록 높이 바꾸기',
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 14),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  ...children,
                ],
              ),
            );
            if (onRefresh != null) {
              body = RefreshIndicator.adaptive(
                color: c.signal,
                onRefresh: onRefresh!,
                child: body,
              );
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: body,
            );
          },
        ),
      ],
    );
  }
}
