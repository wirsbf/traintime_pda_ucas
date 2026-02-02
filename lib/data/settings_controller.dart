import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const String _keyRobInterval = 'robInterval';
  static const String _keyTermStartDate = 'termStartDate';
  static const String _keyWeekOffset = 'weekOffset';
  static const String _keySemesterLength = 'semesterLength';

  int _semesterLength;
  int _robInterval;

  final SharedPreferences _prefs;
  DateTime _termStartDate;
  int _weekOffset;

  DateTime get termStartDate => _termStartDate;
  int get weekOffset => _weekOffset;
  int get semesterLength => _semesterLength;
  int get robInterval => _robInterval;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateText = prefs.getString(_keyTermStartDate);
    final storedStartDate = startDateText != null
        ? DateTime.tryParse(startDateText)
        : null;
    // Default: 2026-03-02
    final defaultStart = DateTime(2026, 3, 2);

    final termStartDate = storedStartDate ?? defaultStart;
    final weekOffset = prefs.getInt(_keyWeekOffset) ?? 0;
    final semesterLength = prefs.getInt(_keySemesterLength) ?? 20;
    final robInterval = prefs.getInt(_keyRobInterval) ?? 1000;

    final username = prefs.getString(_keyUsername) ?? '';
    final password = prefs.getString(_keyPassword) ?? '';

    return SettingsController._(
      prefs,
      termStartDate: termStartDate,
      weekOffset: weekOffset,
      semesterLength: semesterLength,
      robInterval: robInterval,
      username: username,
      password: password,
    );
  }

  SettingsController._(
    this._prefs, {
    required DateTime termStartDate,
    required int weekOffset,
    required int semesterLength,
    required int robInterval,
    required String username,
    required String password,
  }) : _termStartDate = termStartDate,
       _weekOffset = weekOffset,
       _semesterLength = semesterLength,
       _robInterval = robInterval,
       _username = username,
       _password = password;

  // ... existing update methods ...

  // ... existing update methods ...

  void updateRobInterval(int ms) {
    if (ms < 100) ms = 100; // Minimum safety limit
    _robInterval = ms;
    _prefs.setInt(_keyRobInterval, ms);
    notifyListeners();
  }


  static const String _keyUsername = 'username';
  static const String _keyPassword = 'password';

  String _username;
  String _password;

  String get username => _username;
  String get password => _password;

  void updateUsername(String value) {
    _username = value;
    _prefs.setString(_keyUsername, value);
    notifyListeners();
  }

  void updatePassword(String value) {
    _password = value;
    _prefs.setString(_keyPassword, value);
    notifyListeners();
  }

  int currentWeek() {
    final now = DateTime.now();
    final deltaDays = now.difference(_termStartDate).inDays;
    final baseWeek = deltaDays >= 0 ? (deltaDays ~/ 7) + 1 : 1;
    final computed = baseWeek + _weekOffset;
    return computed.clamp(1, _semesterLength);
  }

  void updateTermStartDate(DateTime date) {
    _termStartDate = DateTime(date.year, date.month, date.day);
    _prefs.setString(_keyTermStartDate, _termStartDate.toIso8601String());
    notifyListeners();
  }

  void updateWeekOffset(int offset) {
    _weekOffset = offset;
    _prefs.setInt(_keyWeekOffset, offset);
    notifyListeners();
  }

  void updateSemesterLength(int length) {
    final safeLength = length < 1 ? 1 : length;
    _semesterLength = safeLength;
    _prefs.setInt(_keySemesterLength, safeLength);
    notifyListeners();
  }
}
