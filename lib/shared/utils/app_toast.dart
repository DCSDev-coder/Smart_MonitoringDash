import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';

enum ToastType { success, error, info, warning }

class _ToastData {
  final String id;
  final String message;
  final ToastType type;
  _ToastData(this.id, this.message, this.type);
}

class AppToast {
  static OverlayEntry? _overlayEntry;
  static final GlobalKey<_ToastOverlayState> _overlayKey = GlobalKey<_ToastOverlayState>();
  static String? _reconnectingToastId;

  static void setReconnecting(BuildContext context, bool isReconnecting) {
    if (isReconnecting) {
      if (_reconnectingToastId == null) {
        _reconnectingToastId = show(
          context,
          'Data source reconnecting...',
          type: ToastType.warning,
          duration: null,
        );
      }
    } else {
      if (_reconnectingToastId != null) {
        remove(_reconnectingToastId!);
        _reconnectingToastId = null;
        showSuccess(context, 'Data source reconnected');
      }
    }
  }

  static String show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration? duration = const Duration(seconds: 3),
  }) {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _ToastOverlay(key: _overlayKey),
      );
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    }
    
    return _overlayKey.currentState?.addMessage(message, type, duration) ?? '';
  }

  static void remove(String id) {
    _overlayKey.currentState?.removeMessage(id);
  }

  static String showSuccess(BuildContext context, String message, {Duration? duration = const Duration(seconds: 3)}) {
    return show(context, message, type: ToastType.success, duration: duration);
  }

  static String _sanitizeError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('invalid credentials') || lower.contains('incorrect password')) {
      return 'Incorrect Password';
    }
    if (lower.contains('failed to fetch') || lower.contains('socketexception') || lower.contains('connection refused')) {
      return 'Connection Error. Please check your network.';
    }
    if (lower.contains('failed to unlock door via api') || lower.contains('token has expired') || lower.contains('unauthorized') || lower.contains('not authorized')) {
      return 'Access Denied';
    }
    if (lower.contains('session expired')) {
      return 'Session Expired. Please sign in again.';
    }
    
    // Clean up generic exceptions
    return error.replaceAll('Exception: ', '').replaceAll('ClientException: ', '').trim();
  }

  static String showError(BuildContext context, String message, {Duration? duration = const Duration(seconds: 3)}) {
    return show(context, _sanitizeError(message), type: ToastType.error, duration: duration);
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({super.key});

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_ToastData> _messages = [];

  String addMessage(String message, ToastType type, Duration? duration) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final data = _ToastData(id, message, type);
    
    _messages.insert(0, data);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    
    if (duration != null) {
      Future.delayed(duration, () {
        removeMessage(id);
      });
    }
    return id;
  }

  void removeMessage(String id) {
    if (!mounted) return;
    final index = _messages.indexWhere((e) => e.id == id);
    if (index != -1) {
      final removedData = _messages.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildItem(removedData, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _buildItem(_ToastData data, Animation<double> animation) {
    return _ToastItemWidget(
      data: data,
      animation: animation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = AppConstants.headerClearance(context);
    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: IgnorePointer( // Let touches pass through the entire overlay
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: AnimatedList(
              key: _listKey,
              shrinkWrap: true,
              initialItemCount: _messages.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(_messages[index], animation);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastItemWidget extends StatelessWidget {
  final _ToastData data;
  final Animation<double> animation;

  const _ToastItemWidget({
    required this.data,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData iconData;

    switch (data.type) {
      case ToastType.success:
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        iconData = Icons.check_circle_outline;
        break;
      case ToastType.error:
        bgColor = const Color(0xFFFFEBEE);
        iconColor = const Color(0xFFC62828);
        iconData = Icons.error_outline;
        break;
      case ToastType.warning:
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFE65100);
        iconData = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
      default:
        bgColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF1565C0);
        iconData = Icons.info_outline;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      switch (data.type) {
        case ToastType.success:
          bgColor = const Color(0xFF1B5E20);
          iconColor = const Color(0xFFA5D6A7);
          break;
        case ToastType.error:
          bgColor = const Color(0xFFb71c1c);
          iconColor = const Color(0xFFEF9A9A);
          break;
        case ToastType.warning:
          bgColor = const Color(0xFFE65100).withValues(alpha: 0.3);
          iconColor = const Color(0xFFFFCC80);
          break;
        case ToastType.info:
        default:
          bgColor = const Color(0xFF0D47A1);
          iconColor = const Color(0xFF90CAF9);
          break;
      }
    }

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      data.message,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
