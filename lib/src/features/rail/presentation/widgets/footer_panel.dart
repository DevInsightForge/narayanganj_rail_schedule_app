import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/runtime_env.dart';
import 'panel_shell.dart';

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

  static final Uri _websiteBaseUri = Uri.parse(
    readRuntimeEnv('WEBSITE_BASE_URL') ??
        'https://narayanganj-rail-schedule.pages.dev/',
  );
  static final Uri _privacyPolicyUri = _websiteBaseUri.resolve(
    'privacy-policy',
  );
  static final Uri _termsOfServiceUri = _websiteBaseUri.resolve(
    'terms-of-service',
  );
  static final Uri _organizationUri = Uri.parse(
    'https://github.com/DevInsightForge',
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final linkStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: const Color(0xFF171717),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF171717),
    );

    return PanelShell(
      backgroundColor: const Color(0xFFF5F5F5),
      borderColor: const Color(0x17171717),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Narayanganj Rail Schedule',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF171717),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Author: ZèD',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xAA171717),
                                fontSize: 12,
                              ),
                            ),
                            _InlineButton(
                              label: 'DevInsightForge',
                              onPressed: () => _openUri(_organizationUri),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _LinkText(
                          label: 'Privacy Policy',
                          onPressed: () => _openUri(_privacyPolicyUri),
                          style: linkStyle,
                        ),
                        const SizedBox(height: 2),
                        _LinkText(
                          label: 'Terms of Service',
                          onPressed: () => _openUri(_termsOfServiceUri),
                          style: linkStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0x1A171717)),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaText(label: 'Source', value: dataSourceLabel),
                    _MetaText(
                      label: 'Updated',
                      value: _lastUpdatedLabel(lastUpdatedAt),
                    ),
                    _MetaText(label: 'Version', value: scheduleVersion),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openUri(Uri uri) async {
    await launchUrl(uri, webOnlyWindowName: '_blank');
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
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0x99171717),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xCC171717),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback onPressed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: style),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: const Color(0xFF171717),
        ),
      ),
    );
  }
}
