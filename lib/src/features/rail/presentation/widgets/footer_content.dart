import 'rail_board_texts.dart';

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
  appName: RailBoardTexts.footerAppName,
  tagline: RailBoardTexts.footerTagline,
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
      title: RailBoardTexts.aboutSectionTitle,
      paragraphs: [
        RailBoardTexts.footerAboutParagraphOne,
        RailBoardTexts.footerAboutParagraphTwo,
      ],
    ),
  ],
);
