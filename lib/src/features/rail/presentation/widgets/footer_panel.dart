import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'footer_content.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_primitives.dart';

class FooterPanel extends StatelessWidget {
  const FooterPanel({
    super.key,
    required this.dataSourceLabel,
    required this.lastUpdatedAt,
    required this.scheduleVersion,
  });

  final String dataSourceLabel;
  final DateTime? lastUpdatedAt;
  final String scheduleVersion;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return PanelShell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(railFooterContent.appName, style: textTheme.titleMedium),
                SizedBox(height: tokens.compactGap),
                Text(
                  'Metadata, privacy, and terms',
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.itemGap),
          OutlinedButton.icon(
            onPressed: () => _showFooterSheet(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            label: const Text('Details'),
          ),
        ],
      ),
    );
  }

  String _lastUpdatedLabel(DateTime? value) {
    if (value == null) {
      return 'Bundled';
    }
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }

  Future<void> _openUri(String value) async {
    await launchUrl(Uri.parse(value), webOnlyWindowName: '_blank');
  }

  Future<void> _showFooterSheet(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: tokens.primarySurface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.65,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                tokens.panelPadding.left,
                0,
                tokens.panelPadding.right,
                tokens.panelPadding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RailSectionHeader(
                    eyebrow: 'App details',
                    title: railFooterContent.appName,
                    subtitle: railFooterContent.tagline,
                  ),
                  SizedBox(height: tokens.sectionGap),
                  _FooterSection(section: railFooterContent.sections.first),
                  SizedBox(height: tokens.sectionGap),
                  Divider(color: tokens.border, height: 1),
                  SizedBox(height: tokens.sectionGap),
                  _FooterMetaRow(label: 'Version', value: scheduleVersion),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(label: 'Source', value: dataSourceLabel),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(
                    label: 'Updated',
                    value: _lastUpdatedLabel(lastUpdatedAt),
                  ),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(
                    label: 'Author',
                    value: railFooterContent.author,
                    linkLabel: 'View details',
                    onTap: () => _openUri(railFooterContent.authorUrl),
                  ),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(
                    label: 'Publisher',
                    value: railFooterContent.publisher,
                    linkLabel: 'View details',
                    onTap: () => _openUri(railFooterContent.publisherUrl),
                  ),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(
                    label: 'Privacy',
                    value: 'Privacy policy',
                    linkLabel: 'Open link',
                    onTap: () => _openUri(railFooterContent.privacyUrl),
                  ),
                  SizedBox(height: tokens.compactGap),
                  _FooterMetaRow(
                    label: 'Terms',
                    value: 'Terms of service',
                    linkLabel: 'Open link',
                    onTap: () => _openUri(railFooterContent.termsUrl),
                  ),
                  SizedBox(height: tokens.sectionGap),
                  Text(
                    'Always verify final travel decisions against official Bangladesh Railway notices.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FooterMetaRow extends StatelessWidget {
  const _FooterMetaRow({
    required this.label,
    required this.value,
    this.linkLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final String? linkLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final tokens = RailBoardTokens.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$label: ',
          style: textTheme.labelLarge?.copyWith(color: onSurface),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
        ),
        if (linkLabel != null && onTap != null)
          InkWell(
            onTap: onTap,
            child: Text(
              linkLabel!,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: tokens.accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection({required this.section});

  final FooterContentSection section;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: textTheme.titleMedium),
        SizedBox(height: tokens.compactGap),
        for (var i = 0; i < section.paragraphs.length; i++) ...[
          Text(
            section.paragraphs[i],
            style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
          ),
          if (i < section.paragraphs.length - 1)
            SizedBox(height: tokens.compactGap),
        ],
      ],
    );
  }
}
