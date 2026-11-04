import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

String duaShareText(Dua dua) {
  final sources = dua.sources.map((source) => source.displayLabel).join('\n');
  return '''${dua.arabic}

${dua.transliteration}

${dua.translation}

Source${dua.sources.length == 1 ? '' : 's'}:
$sources

Shared from Ayyam''';
}

Future<void> shareDua(BuildContext context, Dua dua) async {
  final renderBox = context.findRenderObject();
  final origin = renderBox is RenderBox
      ? renderBox.localToGlobal(Offset.zero) & renderBox.size
      : null;
  await SharePlus.instance.share(
    ShareParams(
      subject: 'A dua from Ayyam',
      text: duaShareText(dua),
      sharePositionOrigin: origin,
    ),
  );
}
