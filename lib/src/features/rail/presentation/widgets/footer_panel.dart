import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/runtime_env.dart';
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
    final tokens = RailBoardTokens.of(context);

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: 'Release metadata',
            title: 'Narayanganj Commuter',
            subtitle:
                'Schedule-first commuter board with optional anonymous community status.',
            trailing: RailPill(label: 'Version', value: scheduleVersion),
          ),
          SizedBox(height: tokens.sectionGap),
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: [
              RailPill(label: 'Source', value: dataSourceLabel),
              RailPill(
                label: 'Updated',
                value: _lastUpdatedLabel(lastUpdatedAt),
              ),
              const RailPill(label: 'Author', value: 'Zed'),
            ],
          ),
          SizedBox(height: tokens.sectionGap),
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: [
              OutlinedButton(
                onPressed: () => _openUri(_organizationUri),
                child: const Text('DevInsightForge'),
              ),
              OutlinedButton(
                onPressed: () => _openUri(_privacyPolicyUri),
                child: const Text('Privacy Policy'),
              ),
              OutlinedButton(
                onPressed: () => _openUri(_termsOfServiceUri),
                child: const Text('Terms of Service'),
              ),
            ],
          ),
        ],
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
