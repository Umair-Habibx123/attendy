import 'data/attendance_repository.dart';
import 'data/auth_service.dart';
import 'data/connectivity_service.dart';
import 'data/leave_repository.dart';
import 'data/settings_repository.dart';
import 'data/user_repository.dart';
import 'reports/report_export.dart';

/// The app's services, created once. Screens read them from here.
class Services {
  Services._();
  static final auth = AuthService();
  static final users = UserRepository();
  static final attendance = AttendanceRepository();
  static final leave = LeaveRepository();
  static final settings = SettingsRepository();
  static final connectivity = ConnectivityService();
  static const reports = ReportExporter();
}
