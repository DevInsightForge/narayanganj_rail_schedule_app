class FooterContentSection {
  const FooterContentSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

class FooterContent {
  const FooterContent({
    required this.appName,
    required this.tagline,
    required this.author,
    required this.authorUrl,
    required this.publisher,
    required this.publisherUrl,
    required this.sections,
  });

  final String appName;
  final String tagline;
  final String author;
  final String authorUrl;
  final String publisher;
  final String publisherUrl;
  final List<FooterContentSection> sections;
}

const railFooterContent = FooterContent(
  appName: 'Narayanganj Commuter',
  tagline:
      'Schedule-first commuter board with optional anonymous community status.',
  author: 'ZèD',
  authorUrl: 'https://imzihad21.github.io/about/',
  publisher: 'DevInsightForge',
  publisherUrl: 'https://devinsightforge.github.io/about/',
  sections: [
    FooterContentSection(
      title: 'About',
      paragraphs: [
        'Narayanganj Commuter helps riders check the Dhaka-Narayanganj commuter schedule quickly, with official timetable data kept as the baseline view.',
        'Community arrival reporting is optional and is shown as a secondary signal so riders can understand likely delay conditions without replacing the published timetable.',
      ],
    ),
    FooterContentSection(
      title: 'Privacy Policy',
      paragraphs: [
        'The app can use Firebase Anonymous Auth to create a non-personal identifier for optional community reporting features.',
        'If you submit an arrival report, the app stores the selected train session, station, submission time, and anonymous device-linked identifier needed to deduplicate reports and compute community delay signals.',
        'Schedule browsing works without submitting reports, and no profile, chat, or personal account setup is required for normal timetable use.',
      ],
    ),
    FooterContentSection(
      title: 'Terms of Service',
      paragraphs: [
        'This app is provided as an informational commuter tool. Timetable values may be bundled, cached, or remotely updated, but official Bangladesh Railway notices should be checked before travel.',
        'Community status is rider-contributed and may be unavailable, delayed, stale, or incorrect. Use it as supplementary guidance rather than guaranteed operational truth.',
        'By using the reporting feature, you agree not to submit spam, false observations, or abusive traffic that could degrade the service for other riders.',
      ],
    ),
  ],
);
