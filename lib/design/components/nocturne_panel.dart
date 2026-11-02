import 'dart:ui' show ImageFilter;

import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

class NocturnePanel extends StatelessWidget {
  const NocturnePanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NocturneRadius.sheet),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF20C0D12),
                      borderRadius: BorderRadius.circular(NocturneRadius.sheet),
                      border: Border.all(color: theme.lineStrong),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(height: 10),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.lineStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              NocturneSpace.gutter,
                              NocturneSpace.x3,
                              NocturneSpace.x4,
                              0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        title!,
                                        style: NocturneType.cardTitle(theme.ink)
                                            .copyWith(fontSize: 22),
                                      ),
                                      if (subtitle != null) ...<Widget>[
                                        const SizedBox(
                                          height: NocturneSpace.x1,
                                        ),
                                        Text(
                                          subtitle!,
                                          style: NocturneType.caption(
                                            theme.muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: NocturneSpace.x2),
                                CircleAction(
                                  glyph: NocturneGlyph.close,
                                  onTap: () => Navigator.of(context).maybePop(),
                                  semanticLabel: 'Close',
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              NocturneSpace.gutter,
                              NocturneSpace.x5,
                              NocturneSpace.gutter,
                              NocturneSpace.gutter,
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showNocturnePanel<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context)
      .push<T>(_NocturnePanelRoute<T>(builder: builder));
}

class _NocturnePanelRoute<T> extends PageRouteBuilder<T> {
  _NocturnePanelRoute({required WidgetBuilder builder})
    : super(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0xB3000000),
        barrierLabel: 'Dismiss',
        transitionDuration: NocturneDuration.base,
        reverseTransitionDuration: NocturneDuration.fast,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
