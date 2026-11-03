import 'package:ayyam/design/motion/nocturne_motion.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.scale = 0.972,
    this.haptic = true,
    this.button = true,
    this.toggled,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double scale;
  final bool haptic;
  final bool button;
  final bool? toggled;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  void _activate() {
    if (widget.onTap == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _activateLongPress() {
    if (widget.onLongPress == null) return;
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final interactiveChild = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTap: widget.onTap == null ? null : _activate,
      onLongPress: widget.onLongPress == null ? null : _activateLongPress,
      child: widget.child,
    );

    final animatedChild = NocturneMotion.reduced(context)
        ? interactiveChild
        : SingleMotionBuilder(
            value: _pressed ? 1 : 0,
            from: 0,
            motion: _pressed ? NocturneMotion.press : NocturneMotion.release,
            builder: (context, value, child) => Transform.scale(
              scale: 1 - ((1 - widget.scale) * value),
              child: child,
            ),
            child: interactiveChild,
          );

    final focusableChild = FocusableActionDetector(
      enabled: _enabled,
      autofocus: widget.autofocus,
      mouseCursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onShowFocusHighlight: _setFocused,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: _focused
              ? Border.all(color: NocturneScope.of(context).accent, width: 2)
              : null,
        ),
        child: animatedChild,
      ),
    );

    return Semantics(
      button: widget.button,
      enabled: _enabled,
      focusable: _enabled,
      focused: _focused,
      label: widget.semanticLabel,
      toggled: widget.toggled,
      onTap: widget.onTap == null ? null : _activate,
      onLongPress: widget.onLongPress == null ? null : _activateLongPress,
      child: focusableChild,
    );
  }
}
