import 'package:shared_preferences/shared_preferences.dart';

/// 직원이 현장에서 본 결과. 이 폰에만 하루치로 남는다(로그인 없는 읽기 전용 모드라 서버로 보내지 않는다).
enum StaffCheck {
  /// 고장이라 수거·정비로 넘김.
  pickedUp,

  /// 가서 보니 멀쩡함 — 목록에서 흐리게.
  fine,
}

/// 오늘 확인한 자전거 — 'staff_checks_2026-11-04' 에 'SPB-00001:pickedUp' 꼴로.
class StaffChecksStore {
  const StaffChecksStore();

  static String keyFor(DateTime day) =>
      'staff_checks_${day.year}-${_two(day.month)}-${_two(day.day)}';

  Future<Map<String, StaffCheck>> read(DateTime day) async {
    final preferences = await SharedPreferences.getInstance();
    final out = <String, StaffCheck>{};
    for (final item in preferences.getStringList(keyFor(day)) ?? const []) {
      final at = item.lastIndexOf(':');
      if (at <= 0) continue;
      final kind = StaffCheck.values
          .where((k) => k.name == item.substring(at + 1))
          .firstOrNull;
      if (kind != null) out[item.substring(0, at)] = kind;
    }
    return out;
  }

  Future<void> write(DateTime day, Map<String, StaffCheck> checks) async {
    final preferences = await SharedPreferences.getInstance();
    // 지난 날 기록은 지운다(하루치만).
    for (final key in preferences.getKeys().toList()) {
      if (key.startsWith('staff_checks_') && key != keyFor(day)) {
        await preferences.remove(key);
      }
    }
    await preferences.setStringList(keyFor(day), [
      for (final e in checks.entries) '${e.key}:${e.value.name}',
    ]);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
