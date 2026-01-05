import 'package:flutter/material.dart';

/// A custom page route that provides:
/// 1. iOS-style swipe-back gesture (drag from left edge to go back)
/// 2. Card expansion animation (page scales up from center)
class SwipeBackPageRoute<T> extends PageRouteBuilder<T> {
  SwipeBackPageRoute({
    required this.page,
    this.enableSwipeBack = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(context, animation, secondaryAnimation, child, enableSwipeBack);
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );

  final Widget page;
  final bool enableSwipeBack;

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    bool enableSwipeBack,
  ) {
    // Card expansion: scale + fade
    final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOut),
    );

    // Slide animation for swipe back (secondary - when another page is pushed on top)
    final slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut));

    Widget result = FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        alignment: Alignment.center,
        child: child,
      ),
    );

    // Apply slide out when being covered by another page
    result = SlideTransition(position: slideOutAnimation, child: result);

    // Wrap with swipe back gesture
    if (enableSwipeBack) {
      result = _SwipeBackGestureDetector(child: result);
    }

    return result;
  }

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => Colors.black26;

  @override
  bool get barrierDismissible => false;
}

/// Gesture detector for swipe-back (drag from left edge)
class _SwipeBackGestureDetector extends StatefulWidget {
  const _SwipeBackGestureDetector({required this.child});
  final Widget child;

  @override
  State<_SwipeBackGestureDetector> createState() => _SwipeBackGestureDetectorState();
}

class _SwipeBackGestureDetectorState extends State<_SwipeBackGestureDetector> {
  double _dragOffset = 0;
  bool _isDragging = false;

  static const double _edgeWidth = 40.0; // Width of the swipe-back trigger zone
  static const double _dismissThreshold = 0.35; // 35% of screen width to trigger back

  void _handleDragStart(DragStartDetails details) {
    // Only trigger if starting from left edge
    if (details.localPosition.dx < _edgeWidth) {
      _isDragging = true;
      _dragOffset = 0;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, double.infinity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    // Pop if dragged far enough or swiped fast enough
    if (_dragOffset > screenWidth * _dismissThreshold || velocity > 500) {
      Navigator.of(context).pop();
    }

    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  void _handleDragCancel() {
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = _isDragging ? (_dragOffset / screenWidth).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragCancel,
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(_dragOffset)
          ..scale(1.0 - progress * 0.05), // Slight scale down while dragging
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: _isDragging
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2 * (1 - progress)),
                      blurRadius: 20,
                      offset: const Offset(-5, 0),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Helper extension to easily use the custom route
extension NavigatorSwipeBack on NavigatorState {
  Future<T?> pushSwipeBack<T>(Widget page, {bool enableSwipeBack = true}) {
    return push<T>(SwipeBackPageRoute<T>(page: page, enableSwipeBack: enableSwipeBack));
  }
}

/// A simple MaterialPageRoute replacement with swipe back
class SwipeBackMaterialPageRoute<T> extends MaterialPageRoute<T> {
  SwipeBackMaterialPageRoute({
    required super.builder,
    super.settings,
  });

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Use Cupertino-style slide transition for iOS feel
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));

    return SlideTransition(
      position: animation.drive(tween),
      child: _SwipeBackGestureDetector(child: child),
    );
  }
}
