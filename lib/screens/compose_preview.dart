import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_notice.dart';
import '../core/theme.dart';

/// Review surface for Dokploy's rendered Compose output and demo examples.
class ComposePreviewDialog extends StatefulWidget {
  const ComposePreviewDialog({
    super.key,
    required this.content,
    this.isDemo = false,
  });

  final String content;
  final bool isDemo;

  @override
  State<ComposePreviewDialog> createState() => _ComposePreviewDialogState();
}

class _ComposePreviewDialogState extends State<ComposePreviewDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    DployGoNotice.show(
      context,
      message: 'Compose configuration copied to clipboard.',
      tone: DployGoNoticeTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 840, maxHeight: height * .86),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.preview_outlined, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isDemo
                              ? 'Compose preview'
                              : 'Rendered Compose',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.isDemo
                              ? 'Example configuration'
                              : 'Dokploy generated configuration',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: DokployTheme.mutedOf(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (widget.isDemo) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: DokployTheme.info.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DokployTheme.info.withValues(alpha: .25),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.science_outlined,
                          color: DokployTheme.info, size: 19),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo sample only. This configuration is illustrative and was not fetched from a Dokploy server.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DokployTheme.borderOf(context)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: DokployTheme.borderOf(context),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                size: 17, color: DokployTheme.mutedOf(context)),
                            const SizedBox(width: 8),
                            Text(
                              'docker-compose.yml',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _copy,
                              icon: Icon(
                                _copied ? Icons.check : Icons.copy_outlined,
                                size: 17,
                              ),
                              label: Text(_copied ? 'Copied' : 'Copy'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText.rich(
                                _highlightYaml(widget.content, colors),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightYaml(String source, ColorScheme colors) {
    const codeStyle =
        TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.55);
    final lines = source.split('\n');
    return TextSpan(
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          ..._highlightLine(lines[index], colors, codeStyle),
          if (index < lines.length - 1) const TextSpan(text: '\n'),
        ],
      ],
    );
  }

  List<InlineSpan> _highlightLine(
    String line,
    ColorScheme colors,
    TextStyle base,
  ) {
    if (line.trimLeft().startsWith('#')) {
      return [
        TextSpan(
          text: line,
          style: base.copyWith(color: DokployTheme.mutedOf(context)),
        ),
      ];
    }

    final keyLine =
        RegExp(r'^(\s*(?:-\s*)?)([^:#][^:]*?)(\s*:\s*)(.*)$').firstMatch(line);
    if (keyLine != null) {
      final value = keyLine.group(4)!;
      final commentStart = value.indexOf(' #');
      final valuePart =
          commentStart < 0 ? value : value.substring(0, commentStart);
      final commentPart = commentStart < 0 ? '' : value.substring(commentStart);
      return [
        TextSpan(text: keyLine.group(1), style: base),
        TextSpan(
          text: keyLine.group(2),
          style: base.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: keyLine.group(3),
          style: base.copyWith(color: DokployTheme.mutedOf(context)),
        ),
        if (valuePart.isNotEmpty)
          TextSpan(
            text: valuePart,
            style: base.copyWith(color: _yamlValueColor(valuePart, colors)),
          ),
        if (commentPart.isNotEmpty)
          TextSpan(
            text: commentPart,
            style: base.copyWith(color: DokployTheme.mutedOf(context)),
          ),
      ];
    }

    final trimmed = line.trimLeft();
    if (trimmed.startsWith('- ')) {
      final indentLength = line.length - trimmed.length;
      final prefix = line.substring(0, indentLength + 2);
      final value = trimmed.substring(2);
      return [
        TextSpan(text: prefix, style: base.copyWith(color: colors.secondary)),
        TextSpan(
            text: value,
            style: base.copyWith(color: _yamlValueColor(value, colors))),
      ];
    }
    return [
      TextSpan(text: line, style: base.copyWith(color: colors.onSurface))
    ];
  }

  Color _yamlValueColor(String value, ColorScheme colors) {
    final token = value.trim();
    if (token.startsWith('"') ||
        token.startsWith("'") ||
        token.contains(r'${')) {
      return DokployTheme.success;
    }
    if (RegExp(r'^(true|false|null|yes|no|on|off)(\s|$)', caseSensitive: false)
        .hasMatch(token)) {
      return DokployTheme.info;
    }
    if (RegExp(r'^-?\d+(\.\d+)?(\s|$)').hasMatch(token)) {
      return DokployTheme.warning;
    }
    return colors.onSurface;
  }
}
