import 'package:shared_preferences/shared_preferences.dart';

const staffDistrictsKey = 'staff_districts';

class StaffDistrictsStore {
  const StaffDistrictsStore();

  /// `null` when the staff has not been asked yet.
  Future<List<String>?> read() async {
    final preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey(staffDistrictsKey)) return null;
    return preferences.getStringList(staffDistrictsKey) ?? const [];
  }

  Future<void> write(List<String> districts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(staffDistrictsKey, districts);
  }
}
