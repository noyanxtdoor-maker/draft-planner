import 'package:xml/xml.dart' as xml;

/// The single source of truth for goal icons (Stage-1.1 corrected library).
///
/// Goals store the icon ID, never an asset path or a display label, so a
/// label rename cannot silently change a manually selected icon. Stage 1.1
/// exposes exactly 41 selectable icons: every production asset has a
/// transparent canvas (no baked white/black backdrop), the approved
/// replacements (learning_open_book / spiritual_temple / marriage_rings)
/// render under their original stable IDs, and the legacy Briefcase / Wallet
/// visuals are retired behind the same stable IDs (work_briefcase now shows
/// the Find Job visual, finance_wallet the Pie Chart visual).
///
/// find_job and finance_pie_chart are RETIRED ALIASES (non-selectable): a
/// stored 'find_job' or 'finance_pie_chart' Goal.iconId resolves to the
/// canonical definition (work_briefcase / finance_wallet) with no data
/// rewrite, so backup/import semantics stay raw-string identical.
///
/// social_two_people is intentionally NOT selectable (its old mockup visual
/// is retired and the approved replacement asset is not yet render-ready).
/// Stored Goal.iconId values are never rewritten: an existing
/// 'social_two_people' value resolves through the safe unknown-ID fallback
/// until Stage 2 restores the same stable ID.
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

  /// Non-selectable compatibility aliases for Stage-1 IDs retired by the
  /// Stage-1.1 correction (find_job -> Find Job visual under work_briefcase,
  /// finance_pie_chart -> Pie Chart visual under finance_wallet). Stored
  /// Goal.iconId values are never rewritten; aliases resolve through
  /// [findById] and never appear in [allIcons].
  static const Map<String, String> legacyAliases = <String, String>{
    'find_job': 'work_briefcase',
    'finance_pie_chart': 'finance_wallet',
  };

  static const List<String> approvedIconIds = <String>[
    // Work & Learning
    'work_briefcase',
    'career_growth',
    'document_check',
    'handshake',
    'id_badge',
    'office_building',
    'resume',
    'checklist',
    'idea',
    'learning_open_book',
    // Money & Home
    'finance_wallet',
    'stacked_coins',
    // Health & Daily Life
    'brain',
    'heartbeat',
    'jogging',
    'shield',
    'weight',
    'yoga',
    'fire',
    'habit',
    'target_arrow',
    // People & Relationships
    'baby',
    'dating',
    'engagement_ring',
    'marriage_rings',
    'social_dating',
    'wedding',
    // Faith & Service
    'calendar_date',
    'church',
    'commitment',
    'commitment_101',
    'elders',
    'learning_101',
    'notes',
    'prayer',
    'sisters',
    'temple_marriage',
    'spiritual_temple',
    // Travel & Interests
    'airplane',
    'map_pin',
    'suitcase',
  ];

  static const Set<String> approvedCategories = <String>{
    'Work & Learning',
    'Money & Home',
    'Health & Daily Life',
    'People & Relationships',
    'Faith & Service',
    'Travel & Interests',
  };

  /// Display-only Stage-1.2 category labels. Internal registry values stay
  /// byte-stable (zero data/schema impact); the picker chip row renders these
  /// user-facing labels via [displayCategoryLabel].
  static const Map<String, String> categoryDisplayLabels = <String, String>{
    'Work & Learning': 'Career & Learning',
    'Money & Home': 'Finance & Home',
    'Health & Daily Life': 'Health',
    'People & Relationships': 'Social',
    'Faith & Service': 'Spiritual',
    'Travel & Interests': 'Travel',
  };

  /// Resolves an internal category value to its user-facing label; unknown
  /// values pass through unchanged.
  static String displayCategoryLabel(String internalCategory) =>
      categoryDisplayLabels[internalCategory] ?? internalCategory;

  static const List<GoalIconDefinition> allIcons = <GoalIconDefinition>[
    // ------------------------------------------------------------------ Work
    GoalIconDefinition(
      id: 'work_briefcase',
      displayName: 'Find Job',
      category: 'Work & Learning',
      keywords: <String>[
        'job',
        'career',
        'application',
        'interview',
        'employment',
        'business',
        'search',
        'hiring',
        'job hunt',
        'apply',
      ],
      assetPath: '${assetPrefix}work_briefcase.svg',
      semanticsLabel: 'Job search and applications',
    ),
    GoalIconDefinition(
      id: 'career_growth',
      displayName: 'Career Growth',
      category: 'Work & Learning',
      keywords: <String>[
        'career',
        'growth',
        'promotion',
        'advancement',
        'progress',
        'success',
      ],
      assetPath: '${assetPrefix}career_growth.svg',
      semanticsLabel: 'Career growth and advancement',
    ),
    GoalIconDefinition(
      id: 'document_check',
      displayName: 'Document Check',
      category: 'Work & Learning',
      keywords: <String>[
        'document',
        'checklist',
        'verify',
        'approval',
        'paperwork',
        'review',
        'approved',
      ],
      assetPath: '${assetPrefix}document_check.svg',
      semanticsLabel: 'Document approval and review',
    ),
    GoalIconDefinition(
      id: 'handshake',
      displayName: 'Handshake',
      category: 'Work & Learning',
      keywords: <String>[
        'handshake',
        'deal',
        'agreement',
        'business',
        'partnership',
        'hire',
        'contract',
      ],
      assetPath: '${assetPrefix}handshake.svg',
      semanticsLabel: 'Business agreement and partnership',
    ),
    GoalIconDefinition(
      id: 'id_badge',
      displayName: 'ID Badge',
      category: 'Work & Learning',
      keywords: <String>[
        'id',
        'badge',
        'identity',
        'employee',
        'access',
        'pass',
        'credential',
        'work',
      ],
      assetPath: '${assetPrefix}id_badge.svg',
      semanticsLabel: 'Employee identification and credentials',
    ),
    GoalIconDefinition(
      id: 'office_building',
      displayName: 'Office Building',
      category: 'Work & Learning',
      keywords: <String>[
        'office',
        'building',
        'workplace',
        'corporate',
        'company',
        'work',
        'business',
      ],
      assetPath: '${assetPrefix}office_building.svg',
      semanticsLabel: 'Office and workplace',
    ),
    GoalIconDefinition(
      id: 'resume',
      displayName: 'Resume',
      category: 'Work & Learning',
      keywords: <String>[
        'resume',
        'cv',
        'application',
        'experience',
        'document',
        'profile',
        'career',
      ],
      assetPath: '${assetPrefix}resume.svg',
      semanticsLabel: 'Resume and CV',
    ),
    GoalIconDefinition(
      id: 'checklist',
      displayName: 'Checklist',
      category: 'Work & Learning',
      keywords: <String>[
        'checklist',
        'tasks',
        'planning',
        'organize',
        'progress',
        'list',
      ],
      assetPath: '${assetPrefix}checklist.svg',
      semanticsLabel: 'Checklist and organized progress',
    ),
    GoalIconDefinition(
      id: 'idea',
      displayName: 'Idea',
      category: 'Work & Learning',
      keywords: <String>[
        'idea',
        'creativity',
        'brainstorm',
        'innovation',
        'lightbulb',
      ],
      assetPath: '${assetPrefix}idea.svg',
      semanticsLabel: 'Ideas and creativity',
    ),
    GoalIconDefinition(
      id: 'learning_open_book',
      displayName: 'Learning',
      category: 'Work & Learning',
      keywords: <String>[
        'learning',
        'study',
        'education',
        'book',
        'scripture',
        'reading',
      ],
      assetPath: '${assetPrefix}learning_open_book.svg',
      semanticsLabel: 'Learning and study',
    ),
    // ----------------------------------------------------------------- Money
    GoalIconDefinition(
      id: 'finance_wallet',
      displayName: 'Pie Chart',
      category: 'Money & Home',
      keywords: <String>[
        'money',
        'budget',
        'saving',
        'expense',
        'income',
        'wallet',
        'finance',
        'chart',
        'planning',
        'spending',
        'allocation',
      ],
      assetPath: '${assetPrefix}finance_wallet.svg',
      semanticsLabel: 'Budgeting and financial planning',
    ),
    GoalIconDefinition(
      id: 'stacked_coins',
      displayName: 'Stacked Coins',
      category: 'Money & Home',
      keywords: <String>[
        'coins',
        'savings',
        'money',
        'finance',
        'income',
        'budget',
        'wealth',
      ],
      assetPath: '${assetPrefix}stacked_coins.svg',
      semanticsLabel: 'Savings and money',
    ),
    // ----------------------------------------------------------------- Health
    GoalIconDefinition(
      id: 'brain',
      displayName: 'Brain',
      category: 'Health & Daily Life',
      keywords: <String>[
        'brain',
        'mind',
        'mental',
        'learning',
        'thinking',
        'focus',
      ],
      assetPath: '${assetPrefix}brain.svg',
      semanticsLabel: 'Mental growth and learning',
    ),
    GoalIconDefinition(
      id: 'heartbeat',
      displayName: 'Heartbeat',
      category: 'Health & Daily Life',
      keywords: <String>[
        'heart',
        'health',
        'wellness',
        'cardio',
        'heartbeat',
      ],
      assetPath: '${assetPrefix}heartbeat.svg',
      semanticsLabel: 'Heart health and wellness',
    ),
    GoalIconDefinition(
      id: 'jogging',
      displayName: 'Jogging',
      category: 'Health & Daily Life',
      keywords: <String>[
        'jogging',
        'run',
        'running',
        'cardio',
        'exercise',
        'fitness',
      ],
      assetPath: '${assetPrefix}jogging.svg',
      semanticsLabel: 'Running and cardio exercise',
    ),
    GoalIconDefinition(
      id: 'shield',
      displayName: 'Shield',
      category: 'Health & Daily Life',
      keywords: <String>[
        'shield',
        'protection',
        'safety',
        'wellbeing',
        'health',
      ],
      assetPath: '${assetPrefix}shield.svg',
      semanticsLabel: 'Protection and wellbeing',
    ),
    GoalIconDefinition(
      id: 'weight',
      displayName: 'Weights',
      category: 'Health & Daily Life',
      keywords: <String>[
        'weight',
        'weights',
        'strength',
        'gym',
        'lifting',
        'fitness',
        'exercise',
      ],
      assetPath: '${assetPrefix}weight.svg',
      semanticsLabel: 'Strength and fitness',
    ),
    GoalIconDefinition(
      id: 'yoga',
      displayName: 'Yoga',
      category: 'Health & Daily Life',
      keywords: <String>[
        'yoga',
        'stretch',
        'stretching',
        'flexibility',
        'mindfulness',
        'fitness',
      ],
      assetPath: '${assetPrefix}yoga.svg',
      semanticsLabel: 'Yoga and flexibility',
    ),
    GoalIconDefinition(
      id: 'fire',
      displayName: 'Fire',
      category: 'Health & Daily Life',
      keywords: <String>[
        'fire',
        'motivation',
        'streak',
        'momentum',
        'passion',
        'drive',
      ],
      assetPath: '${assetPrefix}fire.svg',
      semanticsLabel: 'Motivation and momentum',
    ),
    GoalIconDefinition(
      id: 'habit',
      displayName: 'Habit',
      category: 'Health & Daily Life',
      keywords: <String>[
        'habit',
        'routine',
        'consistency',
        'daily',
        'repeat',
      ],
      assetPath: '${assetPrefix}habit.svg',
      semanticsLabel: 'Habits and routines',
    ),
    GoalIconDefinition(
      id: 'target_arrow',
      displayName: 'Target',
      category: 'Health & Daily Life',
      keywords: <String>[
        'target',
        'goal',
        'aim',
        'achievement',
        'progress',
        'arrow',
      ],
      assetPath: '${assetPrefix}target_arrow.svg',
      semanticsLabel: 'Targets and achievement',
    ),
    // ----------------------------------------------------------------- People
    GoalIconDefinition(
      id: 'baby',
      displayName: 'Baby',
      category: 'People & Relationships',
      keywords: <String>[
        'baby',
        'infant',
        'child',
        'family',
        'parenting',
        'childcare',
      ],
      assetPath: '${assetPrefix}baby.svg',
      semanticsLabel: 'Baby and child care',
    ),
    GoalIconDefinition(
      id: 'dating',
      displayName: 'Dating',
      category: 'People & Relationships',
      keywords: <String>[
        'dating',
        'relationship',
        'date',
        'couple',
        'romance',
      ],
      assetPath: '${assetPrefix}dating.svg',
      semanticsLabel: 'Dating and relationships',
    ),
    GoalIconDefinition(
      id: 'engagement_ring',
      displayName: 'Engagement Ring',
      category: 'People & Relationships',
      keywords: <String>[
        'engagement',
        'ring',
        'proposal',
        'fiance',
        'wedding',
        'marriage',
      ],
      assetPath: '${assetPrefix}engagement_ring.svg',
      semanticsLabel: 'Engagement and proposal',
    ),
    GoalIconDefinition(
      id: 'marriage_rings',
      displayName: 'Marriage Rings',
      category: 'People & Relationships',
      keywords: <String>[
        'marriage',
        'rings',
        'wedding',
        'spouse',
        'partnership',
        'couple',
      ],
      assetPath: '${assetPrefix}marriage_rings.svg',
      semanticsLabel: 'Marriage and partnership',
    ),
    GoalIconDefinition(
      id: 'social_dating',
      displayName: 'Social Dating',
      category: 'People & Relationships',
      keywords: <String>[
        'social',
        'dating',
        'relationship',
        'connection',
        'couple',
        'friendship',
      ],
      assetPath: '${assetPrefix}social_dating.svg',
      semanticsLabel: 'Social connection and dating',
    ),
    GoalIconDefinition(
      id: 'wedding',
      displayName: 'Wedding',
      category: 'People & Relationships',
      keywords: <String>[
        'wedding',
        'marriage',
        'ceremony',
        'bride',
        'groom',
        'planning',
      ],
      assetPath: '${assetPrefix}wedding.svg',
      semanticsLabel: 'Wedding and marriage preparation',
    ),
    // ----------------------------------------------------------------- Faith
    GoalIconDefinition(
      id: 'calendar_date',
      displayName: 'Calendar Date',
      category: 'Faith & Service',
      keywords: <String>[
        'calendar',
        'date',
        'schedule',
        'church',
        'appointment',
        'commitment',
      ],
      assetPath: '${assetPrefix}calendar_date.svg',
      semanticsLabel: 'Important spiritual dates and commitments',
    ),
    GoalIconDefinition(
      id: 'church',
      displayName: 'Church',
      category: 'Faith & Service',
      keywords: <String>[
        'church',
        'worship',
        'attendance',
        'congregation',
        'chapel',
      ],
      assetPath: '${assetPrefix}church.svg',
      semanticsLabel: 'Church attendance and worship',
    ),
    GoalIconDefinition(
      id: 'commitment',
      displayName: 'Commitment',
      category: 'Faith & Service',
      keywords: <String>[
        'commitment',
        'covenant',
        'promise',
        'devotion',
        'faith',
      ],
      assetPath: '${assetPrefix}commitment.svg',
      semanticsLabel: 'Commitment and covenant',
    ),
    GoalIconDefinition(
      id: 'commitment_101',
      displayName: 'Commitment 101',
      category: 'Faith & Service',
      keywords: <String>[
        'commitment',
        'promise',
        'follow through',
        'devotion',
        'covenant',
      ],
      assetPath: '${assetPrefix}commitment_101.svg',
      semanticsLabel: 'Commitment and follow-through',
    ),
    GoalIconDefinition(
      id: 'elders',
      displayName: 'Elders',
      category: 'Faith & Service',
      keywords: <String>[
        'elders',
        'missionaries',
        'missionary',
        'teaching',
        'service',
        'men',
      ],
      assetPath: '${assetPrefix}elders.svg',
      semanticsLabel: 'Elder missionaries and teaching',
    ),
    GoalIconDefinition(
      id: 'learning_101',
      displayName: 'Learning 101',
      category: 'Faith & Service',
      keywords: <String>[
        'learning',
        'study',
        'scripture',
        'gospel',
        'reading',
        'church',
      ],
      assetPath: '${assetPrefix}learning_101.svg',
      semanticsLabel: 'Spiritual learning and study',
    ),
    GoalIconDefinition(
      id: 'notes',
      displayName: 'Notes',
      category: 'Faith & Service',
      keywords: <String>[
        'notes',
        'journal',
        'study',
        'record',
        'writing',
        'lesson',
      ],
      assetPath: '${assetPrefix}notes.svg',
      semanticsLabel: 'Notes and study records',
    ),
    GoalIconDefinition(
      id: 'prayer',
      displayName: 'Prayer',
      category: 'Faith & Service',
      keywords: <String>[
        'prayer',
        'pray',
        'devotion',
        'faith',
        'worship',
      ],
      assetPath: '${assetPrefix}prayer.svg',
      semanticsLabel: 'Prayer and devotion',
    ),
    GoalIconDefinition(
      id: 'sisters',
      displayName: 'Sisters',
      category: 'Faith & Service',
      keywords: <String>[
        'sisters',
        'missionaries',
        'missionary',
        'teaching',
        'service',
        'women',
      ],
      assetPath: '${assetPrefix}sisters.svg',
      semanticsLabel: 'Sister missionaries and teaching',
    ),
    GoalIconDefinition(
      id: 'temple_marriage',
      displayName: 'Temple Marriage',
      category: 'Faith & Service',
      keywords: <String>[
        'temple',
        'marriage',
        'sealing',
        'wedding',
        'covenant',
        'family',
      ],
      assetPath: '${assetPrefix}temple_marriage.svg',
      semanticsLabel: 'Temple marriage and sealing',
    ),
    GoalIconDefinition(
      id: 'spiritual_temple',
      displayName: 'Temple',
      category: 'Faith & Service',
      keywords: <String>[
        'temple',
        'worship',
        'faith',
        'church',
        'ordinance',
      ],
      assetPath: '${assetPrefix}spiritual_temple.svg',
      semanticsLabel: 'Temple worship and spiritual goals',
    ),
    // ----------------------------------------------------------------- Travel
    GoalIconDefinition(
      id: 'airplane',
      displayName: 'Airplane',
      category: 'Travel & Interests',
      keywords: <String>[
        'airplane',
        'plane',
        'flight',
        'travel',
        'trip',
        'aviation',
      ],
      assetPath: '${assetPrefix}airplane.svg',
      semanticsLabel: 'Air travel',
    ),
    GoalIconDefinition(
      id: 'map_pin',
      displayName: 'Map Pin',
      category: 'Travel & Interests',
      keywords: <String>[
        'map',
        'pin',
        'location',
        'place',
        'destination',
        'travel',
      ],
      assetPath: '${assetPrefix}map_pin.svg',
      semanticsLabel: 'Places and destinations',
    ),
    GoalIconDefinition(
      id: 'suitcase',
      displayName: 'Suitcase',
      category: 'Travel & Interests',
      keywords: <String>[
        'suitcase',
        'luggage',
        'travel',
        'trip',
        'vacation',
      ],
      assetPath: '${assetPrefix}suitcase.svg',
      semanticsLabel: 'Travel and trips',
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
    final canonicalId = legacyAliases[iconId];
    if (canonicalId == null) {
      return null;
    }
    for (final definition in allIcons) {
      if (definition.id == canonicalId) {
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
      errors.add(
        'The Stage-1 registry must contain exactly '
        '${approvedIconIds.length} icons.',
      );
    }
    for (var position = 0; position < registered.length; position++) {
      final definition = registered[position];
      if (position >= approvedIconIds.length ||
          definition.id != approvedIconIds[position]) {
        errors.add('Icon order or ID is outside the locked Stage-1 manifest.');
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

  /// Security/spec checks used by tests and the handoff audit for the
  /// expanded owner-approved SVG family.
  ///
  /// Stage-1 assets are the locked owner package (hash-gated by tests); this
  /// validator guards the safety surface: valid XML with an svg root, a
  /// positive viewBox, and NO executable/external/animated content. Native
  /// approved teal/gold colors, mixed viewBoxes, and fill+stroke artwork are
  /// allowed (the D1 24x24 / two-stroke / stroke-width 1.8 rules do not apply
  /// to the expanded family).
  static List<String> validateSvg(String source) {
    final errors = <String>[];
    // An optional XML declaration before the root is allowed for the
    // owner-approved assets (e.g. "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    // followed by <svg>).
    final body = source.trimLeft().replaceFirst(
      RegExp(r'^<\?xml[^?]*\?>\s*', caseSensitive: false),
      '',
    );
    final lower = body.toLowerCase();
    if (!body.startsWith('<svg')) {
      errors.add('SVG must begin with an svg root.');
    }
    if (!body.contains('xmlns="http://www.w3.org/2000/svg"')) {
      errors.add('SVG namespace is missing.');
    }
    final viewBoxMatch = RegExp(
      r'viewBox="\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*"',
    ).firstMatch(body);
    if (viewBoxMatch == null) {
      errors.add('SVG viewBox is missing or invalid.');
    } else {
      final width = double.tryParse(viewBoxMatch.group(3)!);
      final height = double.tryParse(viewBoxMatch.group(4)!);
      if (width == null || height == null || width <= 0 || height <= 0) {
        errors.add('SVG viewBox is missing or invalid.');
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
      '<animatemotion',
      '<animatetransform',
      '<set',
      'javascript:',
      'href=',
      'xlink:href=',
      'data:image',
      'url(',
    ]) {
      if (lower.contains(forbidden)) {
        errors.add('SVG contains forbidden content: $forbidden');
      }
    }
    // Event-handler attributes (onclick, onload, ...) are forbidden; a bare
    // ' on' substring would false-positive on CSS content inside the
    // approved stacked_coins style block.
    if (RegExp(r'\son[a-z]+\s*=').hasMatch(lower)) {
      errors.add('SVG contains forbidden content: event handler attribute');
    }
    if (!body.trimRight().endsWith('</svg>')) {
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

    // Stage-1.1: reject baked full-canvas white/off-white backdrops. The app
    // owns the tile background; every production asset must have a
    // transparent canvas. A white path/rect covering ~the whole viewBox is
    // the audited baked-backdrop pattern.
    if (viewBoxMatch != null) {
      final viewBoxWidth = double.parse(viewBoxMatch.group(3)!);
      final viewBoxHeight = double.parse(viewBoxMatch.group(4)!);
      for (final element in document.descendantElements) {
        final elementName = element.localName.toLowerCase();
        if (elementName != 'path' && elementName != 'rect') {
          continue;
        }
        final fill = (element.getAttribute('fill') ?? '').trim().toLowerCase();
        if (!const <String>{
          '#fefefe',
          '#ffffff',
          '#fff',
          'white',
        }.contains(fill)) {
          continue;
        }
        double left = double.infinity;
        double top = double.infinity;
        double right = double.negativeInfinity;
        double bottom = double.negativeInfinity;
        if (elementName == 'rect') {
          final x = double.tryParse(element.getAttribute('x') ?? '0') ?? 0;
          final y = double.tryParse(element.getAttribute('y') ?? '0') ?? 0;
          final width =
              double.tryParse(element.getAttribute('width') ?? '0') ?? 0;
          final height =
              double.tryParse(element.getAttribute('height') ?? '0') ?? 0;
          left = x;
          top = y;
          right = x + width;
          bottom = y + height;
        } else {
          final d = element.getAttribute('d') ?? '';
          final numbers = <double>[];
          for (final match in RegExp(r'-?\d+\.?\d*').allMatches(d)) {
            numbers.add(double.parse(match.group(0)!));
          }
          if (numbers.length < 4) {
            continue;
          }
          for (var i = 0; i + 1 < numbers.length; i += 2) {
            final x = numbers[i];
            final y = numbers[i + 1];
            if (x < left) {
              left = x;
            }
            if (x > right) {
              right = x;
            }
            if (y < top) {
              top = y;
            }
            if (y > bottom) {
              bottom = y;
            }
          }
        }
        if (left.isFinite &&
            right - left >= viewBoxWidth * 0.97 &&
            bottom - top >= viewBoxHeight * 0.97) {
          errors.add('SVG contains a baked full-canvas background.');
          break;
        }
      }
    }

    const forbiddenElements = <String>{
      'script',
      'style',
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
        if (attributeName == 'background' ||
            attributeName == 'background-color') {
          errors.add('SVG must not include a baked background.');
        }
      }
      // Stage-1.2: reject drawables that rely ONLY on class styling with no
      // inline stroke/fill (the Stacked-Coins blank-icon failure class —
      // flutter_svg ignores <style> CSS classes).
      if (const <String>{
        'path',
        'ellipse',
        'rect',
        'circle',
        'line',
        'polyline',
        'polygon',
      }.contains(elementName) &&
          element.getAttribute('class') != null &&
          element.getAttribute('stroke') == null &&
          element.getAttribute('fill') == null) {
        errors.add(
          'SVG drawable relies on class-only styling without an inline '
          'stroke or fill.',
        );
      }
    }
    return errors;
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
