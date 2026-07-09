import '../../../core/controllers/global_status_poller.dart';
import '../models/smart_rack_console_snapshot.dart';

class SmartRackConsoleRepository {
  SmartRackConsoleRepository._();

  static final instance = SmartRackConsoleRepository._();

  SmartRackConsoleSnapshot currentSnapshot() {
    return SmartRackConsoleSnapshot.fromPoller(GlobalStatusPoller.instance);
  }
}
