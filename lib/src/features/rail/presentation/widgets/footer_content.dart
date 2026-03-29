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
    required this.privacyUrl,
    required this.termsUrl,
    required this.sections,
  });

  final String appName;
  final String tagline;
  final String author;
  final String authorUrl;
  final String publisher;
  final String publisherUrl;
  final String privacyUrl;
  final String termsUrl;
  final List<FooterContentSection> sections;
}

const railFooterContent = FooterContent(
  appName: 'Narayanganj Commuter',
  tagline:
      'Schedule-first commuter board with optional anonymous community status.',
  author: 'Zed',
  authorUrl: 'https://imzihad21.github.io/about/',
  publisher: 'DevInsightForge',
  publisherUrl: 'https://devinsightforge.github.io/about/',
  privacyUrl:
      'https://devinsightforge.github.io/privacy#narayanganj-rail-schedule-app',
  termsUrl:
      'https://devinsightforge.github.io/terms#narayanganj-rail-schedule-app',
  sections: [
    FooterContentSection(
      title: 'About',
      paragraphs: [
        'Narayanganj Commuter helps riders check the Dhaka-Narayanganj commuter schedule quickly, with official timetable data kept as the baseline view.',
        'Community arrival reporting is optional and is shown as a secondary signal so riders can understand likely delay conditions without replacing the published timetable.',
      ],
    ),
  ],
);
