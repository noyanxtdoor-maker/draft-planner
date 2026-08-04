import 'package:xml/xml.dart' as xml;

/// The D1 pilot's single source of truth for goal icons.
///
/// The registry deliberately contains only the six approved IDs.  Goals store
/// the ID, never an asset path or a display label, so a label rename cannot
/// silently change a manually selected icon.
final class GoalIconDefinition {
  const GoalIconDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.keywords,
    required this.assetPath,
    required this.semanticsLabel,
  });

  final String id;
  final String displayName;
  final String category;
  final List<String> keywords;
  final String assetPath;
  final String semanticsLabel;
}

final class GoalIconSuggestion {
  const GoalIconSuggestion({
    required this.definition,
    required this.score,
    required this.matchedWordCount,
  });

  final GoalIconDefinition definition;
  final int score;
  final int matchedWordCount;

  String get iconId => definition.id;
}

final class GoalIconRegistry {
  const GoalIconRegistry._();

  static const GoalIconRegistry instance = GoalIconRegistry._();

  static const String assetPrefix = 'assets/icons/goals/';
  static const String primaryColor = '#9DC8CF';
  static const String accentColor = '#D7A06E';

  static const List<String> approvedIconIds = <String>[
    'work_briefcase',
    'learning_open_book',
    'finance_wallet',
    'social_two_people',
    'spiritual_temple',
    'marriage_rings',
  ];

  static const Set<String> approvedCategories = <String>{
    'work',
    'learning',
    'finance',
    'social',
    'spiritual',
    'marriage',
  };

  static const List<GoalIconDefinition> allIcons = <GoalIconDefinition>[
    GoalIconDefinition(
      id: 'work_briefcase',
      displayName: 'Briefcase',
      category: 'work',
      keywords: <String>[
        'job',
        'career',
        'application',
        'interview',
        'employment',
        'business',
      ],
      assetPath: '${assetPrefix}work_briefcase.svg',
      semanticsLabel: 'Work and career',
    ),
    GoalIconDefinition(
      id: 'learning_open_book',
      displayName: 'Open Book',
      category: 'learning',
      keywords: <String>[
        'school',
        'study',
        'learning',
        'course',
        'scripture',
        'reading',
      ],
      assetPath: '${assetPrefix}learning_open_book.svg',
      semanticsLabel: 'Learning and study',
    ),
    GoalIconDefinition(
      id: 'finance_wallet',
      displayName: 'Wallet',
      category: 'finance',
      keywords: <String>[
        'money',
        'budget',
        'saving',
        'expense',
        'income',
        'wallet',
      ],
      assetPath: '${assetPrefix}finance_wallet.svg',
      semanticsLabel: 'Money and budgeting',
    ),
    GoalIconDefinition(
      id: 'social_two_people',
      displayName: 'Two People',
      category: 'social',
      keywords: <String>[
        'people',
        'friend',
        'connection',
        'social',
        'relationship',
        'meet',
      ],
      assetPath: '${assetPrefix}social_two_people.svg',
      semanticsLabel: 'People and relationships',
    ),
    GoalIconDefinition(
      id: 'spiritual_temple',
      displayName: 'Temple',
      category: 'spiritual',
      keywords: <String>[
        'temple',
        'church',
        'worship',
        'attendance',
        'ordinance',
        'faith',
      ],
      assetPath: '${assetPrefix}spiritual_temple.svg',
      semanticsLabel: 'Faith and worship',
    ),
    GoalIconDefinition(
      id: 'marriage_rings',
      displayName: 'Rings',
      category: 'marriage',
      keywords: <String>[
        'marriage',
        'wedding',
        'rings',
        'spouse',
        'commitment',
        'anniversary',
      ],
      assetPath: '${assetPrefix}marriage_rings.svg',
      semanticsLabel: 'Marriage and commitment',
    ),
  ];

  GoalIconDefinition? findById(String? iconId) {
    if (iconId == null || iconId.isEmpty) {
      return null;
    }
    for (final definition in allIcons) {
      if (definition.id == iconId) {
        return definition;
      }
    }
    return null;
  }

  bool contains(String? iconId) => findById(iconId) != null;

  List<GoalIconDefinition> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return allIcons;
    }
    final queryTokens = _tokens(normalizedQuery);
    return <GoalIconDefinition>[
      for (final definition in allIcons.where(
        (definition) => _matches(definition, queryTokens),
      ))
        definition,
    ];
  }

  GoalIconSuggestion? suggestForGoalTitle(String title) {
    final suggestions = suggestionsForGoalTitle(title);
    return suggestions.isEmpty ? null : suggestions.first;
  }

  /// Returns the deterministic top three matches used by the picker.
  ///
  /// The sort is deliberately explicit instead of relying on a map/set: score
  /// wins first, then the number of matched whole words, then the immutable
  /// registry order.
  List<GoalIconSuggestion> suggestionsForGoalTitle(String title) {
    final normalizedTitle = _normalize(title);
    final titleTokens = _tokens(normalizedTitle);
    if (titleTokens.isEmpty) {
      return const <GoalIconSuggestion>[];
    }
    final ranked = <GoalIconSuggestion>[];
    for (final definition in allIcons) {
      final scored = _score(definition, normalizedTitle, titleTokens);
      if (scored == null) {
        continue;
      }
      ranked.add(
        GoalIconSuggestion(
          definition: definition,
          score: scored.$1,
          matchedWordCount: scored.$2,
        ),
      );
    }
    ranked.sort((left, right) {
      final scoreOrder = right.score.compareTo(left.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      final wordOrder = right.matchedWordCount.compareTo(left.matchedWordCount);
      if (wordOrder != 0) {
        return wordOrder;
      }
      return allIcons
          .indexOf(left.definition)
          .compareTo(allIcons.indexOf(right.definition));
    });
    return ranked.take(3).toList(growable: false);
  }

  /// Validates registry invariants. Asset bytes are validated separately by
  /// the focused SVG tests so this method stays usable without asset I/O.
  /// Passing [availableAssetPaths] also validates that every registered asset
  /// is present in the declared Flutter asset bundle.
  List<String> validate({
    Iterable<String>? availableAssetPaths,
    Iterable<GoalIconDefinition>? definitions,
  }) {
    final errors = <String>[];
    final registered = definitions?.toList(growable: false) ?? allIcons;
    final ids = <String>{};
    final paths = <String>{};
    final available = availableAssetPaths?.toSet();
    if (registered.length != approvedIconIds.length) {
      errors.add('The D1 registry must contain exactly six icons.');
    }
    for (var position = 0; position < registered.length; position++) {
      final definition = registered[position];
      if (position >= approvedIconIds.length ||
          definition.id != approvedIconIds[position]) {
        errors.add('Icon order or ID is outside the approved D1 pilot.');
      }
      if (!ids.add(definition.id)) {
        errors.add('Duplicate icon ID: ${definition.id}');
      }
      if (!paths.add(definition.assetPath)) {
        errors.add('Duplicate icon asset path: ${definition.assetPath}');
      }
      if (definition.id.trim().isEmpty ||
          definition.displayName.trim().isEmpty ||
          definition.category.trim().isEmpty ||
          definition.semanticsLabel.trim().isEmpty) {
        errors.add('Icon metadata contains a blank required field.');
      }
      if (definition.keywords.isEmpty ||
          definition.keywords.any((keyword) => _normalize(keyword).isEmpty)) {
        errors.add('Icon ${definition.id} has invalid keywords.');
      }
      final normalizedKeywords = <String>[];
      for (final keyword in definition.keywords) {
        final normalized = _normalize(keyword);
        normalizedKeywords.add(normalized);
        if (normalized != keyword) {
          errors.add('Icon ${definition.id} has unnormalized keywords.');
        }
      }
      if (normalizedKeywords.toSet().length != normalizedKeywords.length) {
        errors.add('Icon ${definition.id} has duplicate keywords.');
      }
      if (!approvedCategories.contains(definition.category)) {
        errors.add('Icon ${definition.id} has an unsupported category.');
      }
      if (!definition.assetPath.startsWith(assetPrefix) ||
          !definition.assetPath.endsWith('.svg')) {
        errors.add('Icon ${definition.id} has an unsupported asset path.');
      }
      if (position < allIcons.length &&
          definition.assetPath != allIcons[position].assetPath) {
        errors.add('Icon ${definition.id} has an unexpected asset path.');
      }
      if (available != null && !available.contains(definition.assetPath)) {
        errors.add('Missing registered asset: ${definition.assetPath}');
      }
    }
    return errors;
  }

  /// Security/spec checks used by tests and the handoff audit.
  ///
  /// These checks intentionally parse the XML before applying the small set of
  /// D1 policy checks. A string-only check can be fooled by malformed markup,
  /// namespace aliases, or a forbidden attribute hidden on a nested element.
  /// The source bytes remain untouched; this only validates them.
  static List<String> validateSvg(String source) {
    final errors = <String>[];
    final lower = source.toLowerCase();
    if (!source.trimLeft().startsWith('<svg')) {
      errors.add('SVG must begin with an svg root.');
    }
    if (!source.contains('xmlns="http://www.w3.org/2000/svg"')) {
      errors.add('SVG namespace is missing.');
    }
    if (!source.contains('viewBox="0 0 24 24"')) {
      errors.add('SVG viewBox must be 0 0 24 24.');
    }
    for (final required in <String>[
      'fill="none"',
      'stroke-linecap="round"',
      'stroke-linejoin="round"',
      'stroke="#9DC8CF"',
      'stroke="#D7A06E"',
      'stroke-width="1.8"',
    ]) {
      if (!source.contains(required)) {
        errors.add('SVG is missing required spec token: $required');
      }
    }
    for (final forbidden in <String>[
      '<script',
      '<foreignobject',
      '<image',
      '<filter',
      '<lineargradient',
      '<radialgradient',
      '<pattern',
      '<animate',
      '<set',
      'javascript:',
      ' on',
      'href=',
      'xlink:href=',
      'url(',
      'style=',
    ]) {
      if (lower.contains(forbidden)) {
        errors.add('SVG contains forbidden content: $forbidden');
      }
    }
    if (RegExp(
      r'<rect[^>]*width="(?:100%|24)"[^>]*height="(?:100%|24)"',
      caseSensitive: false,
    ).hasMatch(source)) {
      errors.add('SVG contains a full-background rectangle tile.');
    }
    if (RegExp(
      r'<circle[^>]*(?:r="(?:12|12\.0)"|cx="12"[^>]*cy="12"[^>]*r="1[01])',
      caseSensitive: false,
    ).hasMatch(source)) {
      errors.add('SVG contains a circular tile.');
    }
    if (!source.trimRight().endsWith('</svg>')) {
      errors.add('SVG must close its root element.');
    }

    xml.XmlDocument? document;
    try {
      document = xml.XmlDocument.parse(source);
    } on Object {
      errors.add('SVG XML parse failed.');
      return errors;
    }

    final root = document.rootElement;
    if (root.localName != 'svg') {
      errors.add('SVG root element must be svg.');
    }
    if (root.getAttribute('xmlns') != 'http://www.w3.org/2000/svg') {
      errors.add('SVG namespace must be the W3C SVG namespace.');
    }
    if (root.getAttribute('viewBox') != '0 0 24 24') {
      errors.add('SVG viewBox must be 0 0 24 24.');
    }

    const forbiddenElements = <String>{
      'script',
      'foreignobject',
      'image',
      'filter',
      'lineargradient',
      'radialgradient',
      'pattern',
      'animate',
      'animatemotion',
      'animatetransform',
      'set',
      'font',
      'font-face',
    };
    const allowedStrokeColors = <String>{
      '#9dc8cf',
      '#d7a06e',
      'none',
    };
    var accentStrokeCount = 0;
    for (final element in document.descendantElements) {
      final elementName = element.localName.toLowerCase();
      if (forbiddenElements.contains(elementName)) {
        errors.add('SVG contains forbidden element: $elementName.');
      }
      for (final attribute in element.attributes) {
        final attributeName = attribute.localName.toLowerCase();
        final attributeValue = attribute.value.trim();
        final attributeLower = attributeValue.toLowerCase();
        if (attributeName == 'href' ||
            attributeName == 'src' ||
            attributeName == 'style' ||
            attributeName.startsWith('on') ||
            attributeName == 'xlink:href') {
          errors.add('SVG contains forbidden attribute: $attributeName.');
        }
        if (attributeName != 'xmlns' &&
            (attributeLower.contains('javascript:') ||
            attributeLower.contains('data:') ||
            attributeLower.contains('://') ||
            attributeLower.contains('url('))) {
          errors.add('SVG contains an external or executable URL.');
        }
        if (attributeName == 'stroke') {
          final normalizedStroke = attributeLower;
          if (!allowedStrokeColors.contains(normalizedStroke)) {
            errors.add('SVG contains an unsupported stroke color.');
          }
          if (normalizedStroke == accentColor.toLowerCase()) {
            accentStrokeCount++;
          }
        }
        if (attributeName == 'stroke-width' && attributeValue != '1.8') {
          errors.add('SVG contains an unsupported stroke width.');
        }
        if (attributeName == 'background' || attributeName == 'background-color') {
          errors.add('SVG must not include a baked background.');
        }
      }
      if (elementName == 'rect' && _isFullBackgroundRect(element)) {
        errors.add('SVG contains a full-background rectangle tile.');
      }
      if (elementName == 'circle' && _isCircularTile(element)) {
        errors.add('SVG contains a circular tile.');
      }
    }
    if (accentStrokeCount != 1) {
      errors.add('SVG must use exactly one meaningful accent stroke.');
    }
    return errors;
  }

  static bool _isFullBackgroundRect(xml.XmlElement element) {
    final width = element.getAttribute('width')?.toLowerCase();
    final height = element.getAttribute('height')?.toLowerCase();
    return (width == '100%' || width == '24' || width == '24.0') &&
        (height == '100%' || height == '24' || height == '24.0');
  }

  static bool _isCircularTile(xml.XmlElement element) {
    final cx = element.getAttribute('cx');
    final cy = element.getAttribute('cy');
    final radius = double.tryParse(element.getAttribute('r') ?? '');
    return cx == '12' && cy == '12' && radius != null && radius >= 10.5;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _tokens(String value) {
    if (value.trim().isEmpty) {
      return const <String>[];
    }
    return value
        .split(' ')
        .map(_tokenKey)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static String _tokenKey(String token) {
    final normalized = _normalize(token);
    if (normalized.length > 3 &&
        normalized.endsWith('s') &&
        !normalized.endsWith('ss')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static bool _matches(
    GoalIconDefinition definition,
    List<String> queryTokens,
  ) {
    final searchable = <String>{
      ..._tokens(_normalize(definition.displayName)),
      ..._tokens(_normalize(definition.category)),
      ..._tokens(_normalize(definition.semanticsLabel)),
      for (final keyword in definition.keywords)
        ..._tokens(_normalize(keyword)),
    };
    return queryTokens.every(searchable.contains);
  }

  static (int, int)? _score(
    GoalIconDefinition definition,
    String normalizedTitle,
    List<String> titleTokens,
  ) {
    final displayName = _normalize(definition.displayName);
    final keywordPhrases = definition.keywords
        .map(_normalize)
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
    final keywordTokens = <String>{
      for (final keyword in keywordPhrases) ..._tokens(keyword),
    };
    var score = 0;
    final matched = <String>{};
    if (normalizedTitle == displayName) {
      score += 100;
    }
    for (final keyword in keywordPhrases) {
      if (normalizedTitle == keyword) {
        score += 80;
      }
      if (keyword.contains(' ') &&
          _containsPhrase(titleTokens, _tokens(keyword))) {
        score += 60;
      }
    }
    for (final token in titleTokens) {
      if (keywordTokens.contains(token)) {
        score += 20;
        matched.add(token);
      }
    }
    if (_containsPhrase(titleTokens, _tokens(displayName)) &&
        normalizedTitle != displayName) {
      score += 10;
    }
    if (score == 0) {
      return null;
    }
    return (score, matched.length);
  }

  static bool _containsPhrase(List<String> words, List<String> phrase) {
    if (phrase.isEmpty || phrase.length > words.length) {
      return false;
    }
    for (var start = 0; start <= words.length - phrase.length; start++) {
      var matches = true;
      for (var index = 0; index < phrase.length; index++) {
        if (words[start + index] != phrase[index]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }
}
