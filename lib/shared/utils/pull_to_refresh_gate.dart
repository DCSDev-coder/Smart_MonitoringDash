import 'package:flutter/material.dart';

/// Small stateful helper that only arms pull-to-refresh after a deliberate
/// pull distance from the top of the scroll view.
///
/// This reduces accidental refreshes when the user is simply trying to scroll
/// the page and briefly nudges downward at the top boundary.
class PullToRefreshGate {
  PullToRefreshGate({this.activationDistance = 90.0});

  final double activationDistance;

  double _pullDistance = 0.0;
  bool _armed = false;
  bool _refreshing = false;

  bool get armed => _armed;

  void beginRefresh() {
    _refreshing = true;
    _armed = false;
  }

  void endRefresh() {
    _refreshing = false;
    _pullDistance = 0.0;
    _armed = false;
  }

  bool shouldProcess(ScrollNotification notification) {
    // Let RefreshIndicator receive the full top-level gesture lifecycle.
    // If we wait until `_armed` becomes true, the indicator misses the early
    // drag/overscroll notifications it needs in order to enter refresh mode.
    return notification.depth == 0 && !_refreshing;
  }

  bool handleNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (_refreshing) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _pullDistance = 0.0;
      _armed = false;
      return false;
    }

    if (notification.metrics.extentBefore > 0) {
      _pullDistance = 0.0;
      if (notification is ScrollEndNotification) {
        _armed = false;
      }
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.metrics.extentBefore <= 0 &&
        notification.overscroll < 0) {
      _pullDistance += notification.overscroll.abs();
      if (_pullDistance >= activationDistance) {
        _armed = true;
      }
    }

    if (notification is ScrollEndNotification) {
      // RefreshIndicator only gets a single gesture window. Once the gesture
      // ends, clear the armed state so a later unrelated scroll cannot reuse
      // the previous pull distance.
      _pullDistance = 0.0;
      if (!_refreshing) {
        _armed = false;
      }
    }

    return false;
  }
}
