import 'package:flutter/material.dart';

/// Monospace style that works on Android and iOS.
const monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// Text where spans wrapped in backticks (`sets`) are shown in monospace,
/// without the backticks.
class CodeText extends StatelessWidget {
  const CodeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('`');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(text: parts[i], style: i.isOdd ? monospace : null),
        ],
      ),
      style: style,
    );
  }
}
