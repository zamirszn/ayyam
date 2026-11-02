import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class NocturneField extends StatefulWidget {
  const NocturneField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;

  @override
  State<NocturneField> createState() => _NocturneFieldState();
}

class _NocturneFieldState extends State<NocturneField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
    widget.controller.addListener(_handleText);
  }

  @override
  void didUpdateWidget(NocturneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleText);
      widget.controller.addListener(_handleText);
    }
  }

  void _handleFocus() => setState(() => _focused = _focusNode.hasFocus);

  void _handleText() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_handleText);
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final error = widget.error;
    final borderColor = error != null
        ? theme.missed
        : (_focused ? theme.lineStrong : theme.line);

    return Semantics(
      textField: true,
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.label.toUpperCase(),
            style: NocturneType.label(theme.muted),
          ),
          const SizedBox(height: NocturneSpace.x2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusNode.requestFocus,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.glass,
                borderRadius: BorderRadius.circular(NocturneRadius.small),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NocturneSpace.x4,
                  vertical: 13,
                ),
                child: Stack(
                  children: <Widget>[
                    if (widget.controller.text.isEmpty && widget.hint != null)
                      IgnorePointer(
                        child: Text(
                          widget.hint!,
                          style: NocturneType.body(theme.faint),
                        ),
                      ),
                    EditableText(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      style: NocturneType.body(theme.ink),
                      cursorColor: theme.accent,
                      backgroundCursorColor: theme.faint,
                      selectionColor: theme.pending.withValues(alpha: 0.32),
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      obscureText: widget.obscureText,
                      obscuringCharacter: '•',
                      inputFormatters: <TextInputFormatter>[
                        if (widget.maxLength case final maxLength?)
                          LengthLimitingTextInputFormatter(maxLength),
                      ],
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      autofocus: widget.autofocus,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null || widget.helper != null) ...<Widget>[
            const SizedBox(height: NocturneSpace.x2),
            Text(
              error ?? widget.helper!,
              style: NocturneType.caption(
                error == null ? theme.faint : theme.missed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
