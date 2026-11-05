import 'dart:ui' as ui;

// 번호판 읽기(카메라 글자 인식): 따릉이 번호표의 번호는 'SPB-' 없이 숫자만, 위에서 아래로 한 글자씩
// 세로로 찍혀 있다(7/2/6/2/7). 글자 인식은 이것을 숫자 하나짜리 줄 여러 개로 돌려주므로 위에서 아래 순서로 잇는다.

/// 인식된 글자에서 숫자만: 흔히 헷갈리는 글자는 숫자로 바꾼다(O→0, I·l·|→1, S→5, B→8, Z→2).
String digitsOf(String text) {
  const swap = {
    'O': '0',
    'o': '0',
    'D': '0',
    'Q': '0',
    'I': '1',
    'l': '1',
    'i': '1',
    'S': '5',
    's': '5',
    'B': '8',
    'Z': '2',
    'z': '2',
    'G': '6',
    'b': '6',
    'g': '9',
    'q': '9',
    'T': '7',
  };
  final buf = StringBuffer();
  for (final ch in text.split('')) {
    if (RegExp(r'\d').hasMatch(ch)) {
      buf.write(ch);
    } else if (swap.containsKey(ch)) {
      buf.write(swap[ch]);
    }
  }
  return buf.toString();
}

/// 4~6자리 숫자면 자전거 번호('SPB-' + 5자리 이상).
String? bikeIdFromDigits(String digits, {int? expected}) {
  if (digits.length < 4 || digits.length > 6) return null;
  if (expected != null && digits.length != expected) return null;
  return 'SPB-${digits.padLeft(5, '0')}';
}

/// 세로로 한 글자씩 놓인 숫자(번호판 읽기 화면에서 그대로 읽힌 경우): 줄마다 숫자 하나이고,
/// 가로 위치가 비슷하게 위에서 아래로 놓였으면 이어 붙인다.
String? bikeIdFromStackedLines(List<(String, ui.Rect)> lines) {
  final singles = [
    for (final (text, box) in lines)
      if (digitsOf(text).length == 1) (digitsOf(text), box),
  ];
  if (singles.length < 4) return null;
  // 가장 많이 겹치는 세로 줄(가로 가운데가 글자 폭 안에서 같은 것들)을 고른다.
  List<(String, ui.Rect)> best = const [];
  for (final (_, anchor) in singles) {
    final column = [
      for (final s in singles)
        if ((s.$2.center.dx - anchor.center.dx).abs() < anchor.width * .8) s,
    ]..sort((a, b) => a.$2.top.compareTo(b.$2.top));
    if (column.length > best.length) best = column;
  }
  return bikeIdFromDigits(best.map((s) => s.$1).join());
}
