import '../../../core/config/app_config.dart';
import '../../../core/controllers/global_status_poller.dart';
import '../models/smart_rack_console_snapshot.dart';
import 'smart_rack_demo_session.dart';

class SmartRackConsoleRepository {
  SmartRackConsoleRepository._();

  static final instance = SmartRackConsoleRepository._();

  SmartRackConsoleSnapshot currentSnapshot() {
    if (AppConfig.isDemoMode) {
      return SmartRackDemoSession.instance.currentSnapshot();
    }
    return SmartRackConsoleSnapshot.fromPoller(GlobalStatusPoller.instance);
  }
}
