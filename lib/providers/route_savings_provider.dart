import 'package:flutter/foundation.dart';
import '../models/route_alternative.dart';

/// Tracks how much time live-traffic rerouting has actually saved during
/// the current shift. Fed by RouteMapScreen every time it polls Google
/// for alternatives — this is what turns the background rerouting work
/// into something the vendor can actually see credit for.
class RouteSavingsProvider extends ChangeNotifier {
  int _totalMinutesSaved = 0;
  RouteAlternative? _lastCheckedOption;

  int get totalMinutesSaved => _totalMinutesSaved;
  RouteAlternative? get lastCheckedOption => _lastCheckedOption;

  /// Called after every Directions API check. Only counts it as a "save"
  /// if the fastest option beats the slowest by a noticeable margin —
  /// avoids the stat creeping up from noise on a 1-minute difference.
  void recordCheck(List<RouteAlternative> sortedOptions) {
    if (sortedOptions.isEmpty) return;
    _lastCheckedOption = sortedOptions.first;

    if (sortedOptions.length > 1) {
      final saved = sortedOptions.last.durationInTrafficMinutes -
          sortedOptions.first.durationInTrafficMinutes;
      if (saved >= 3) _totalMinutesSaved += saved;
    }
    notifyListeners();
  }

  /// Called when a shift starts, so yesterday's savings don't carry over.
  void resetForNewShift() {
    _totalMinutesSaved = 0;
    _lastCheckedOption = null;
    notifyListeners();
  }
}