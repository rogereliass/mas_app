/// Centralized TTL durations for lightweight in-memory repository caches.
///
/// Keep these values configurable in one place so fetch freshness can be tuned
/// without editing multiple services.
class CacheTtl {
  CacheTtl._();

  /// Meetings list used by Meetings tab, Attendance selector, and Points selector.
  static const Duration meetingsList = Duration(minutes: 5);

  /// Attendance member roster for a troop.
  static const Duration attendanceMembers = Duration(minutes: 3);

  /// Attendance rows for a selected meeting.
  static const Duration attendanceRecords = Duration(minutes: 2);

  /// Points rows for a selected meeting.
  static const Duration meetingPoints = Duration(minutes: 2);

  /// Notifications list and unread badge data.
  static const Duration notificationsList = Duration(minutes: 2);

  /// Reference lookup data for Points tab.
  static const Duration patrols = Duration(minutes: 30);
  static const Duration pointCategories = Duration(minutes: 30);
  static const Duration troopPointsVisibility = Duration(minutes: 5);
}
