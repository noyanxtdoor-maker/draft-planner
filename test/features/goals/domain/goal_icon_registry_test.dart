import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';

void main() {
  const registry = GoalIconRegistry.instance;

  test('the production registry contains exactly the approved pilot', () {
    expect(
      GoalIconRegistry.allIcons.map((definition) => definition.id),
      GoalIconRegistry.approvedIconIds,
    );
    expect(GoalIconRegistry.allIcons, hasLength(6));
    expect(
      GoalIconRegistry.allIcons.map((definition) => definition.id).toSet(),
      hasLength(6),
    );
    expect(
      GoalIconRegistry.allIcons
          .map((definition) => definition.assetPath)
          .toSet(),
      hasLength(6),
    );
    expect(
      GoalIconRegistry.allIcons.every((definition) {
        return definition.displayName.trim().isNotEmpty &&
            definition.semanticsLabel.trim().isNotEmpty &&
            definition.category.trim().isNotEmpty;
      }),
      isTrue,
    );
    expect(
      GoalIconRegistry.allIcons.every((definition) {
        final normalized = definition.keywords
            .map((keyword) => keyword.trim().toLowerCase())
            .toList(growable: false);
        return normalized.length == definition.keywords.length &&
            normalized.toSet().length == normalized.length &&
            normalized.every(
              (keyword) => keyword == keyword.replaceAll(' ', ''),
            );
      }),
      isTrue,
    );
    expect(registry.validate(), isEmpty);
    expect(
      registry.validate(
        availableAssetPaths: GoalIconRegistry.allIcons.map(
          (definition) => definition.assetPath,
        ),
      ),
      isEmpty,
    );
  });

  test('the six copied SVGs match the protected source hashes exactly', () {
    const expected = <String, String>{
      'work_briefcase.svg':
          '43bdc3cf177ff6879050ad8ae88db15ac25128fceea80123a1c4b6905ee0b0ea',
      'learning_open_book.svg':
          '0775dbc2446f28d47d03d99de4e8b47b17bad6c1b0d4cb2729633521de28256a',
      'finance_wallet.svg':
          'd719990b6b28625ed6a8fef8c76fa7bced6236ccbcfbfaae2829892143b62c42',
      'social_two_people.svg':
          'ac9e58f8a481781dcf0c0e65c399010158ae181ec39d0e52751f467e5f562f69',
      'spiritual_temple.svg':
          'ba24daffe284874e7dada3bf3579ed58554499b9b36979ca6f85688e2b9f9eae',
      'marriage_rings.svg':
          '3630690e5a215bfb36f0af63e831c35dff672d0f85066c822f093fea7cf94ff3',
    };

    for (final definition in GoalIconRegistry.allIcons) {
      final file = File(definition.assetPath);
      expect(file.existsSync(), isTrue, reason: definition.assetPath);
      final source = file.readAsBytesSync();
      expect(
        sha256.convert(source).toString(),
        expected[definition.assetPath.split('/').last],
        reason: definition.assetPath,
      );
      expect(
        GoalIconRegistry.validateSvg(String.fromCharCodes(source)),
        isEmpty,
      );
    }
  });

  test('registry validation rejects duplicate, missing, and blank metadata', () {
    final duplicate = <GoalIconDefinition>[
      ...GoalIconRegistry.allIcons,
      GoalIconRegistry.allIcons.first,
    ];
    expect(
      registry.validate(definitions: duplicate),
      contains('Duplicate icon ID: work_briefcase'),
    );

    expect(
      registry.validate(
        availableAssetPaths: GoalIconRegistry.allIcons
            .skip(1)
            .map((definition) => definition.assetPath),
      ),
      contains(
        'Missing registered asset: ${GoalIconRegistry.allIcons.first.assetPath}',
      ),
    );

    final first = GoalIconRegistry.allIcons.first;
    final blankSemantics = <GoalIconDefinition>[
      GoalIconDefinition(
        id: first.id,
        displayName: first.displayName,
        category: first.category,
        keywords: first.keywords,
        assetPath: first.assetPath,
        semanticsLabel: '',
      ),
      ...GoalIconRegistry.allIcons.skip(1),
    ];
    expect(
      registry.validate(definitions: blankSemantics),
      contains('Icon metadata contains a blank required field.'),
    );
  });

  test('SVG validation rejects executable and external content', () {
    const unsafe = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
     stroke-linecap="round" stroke-linejoin="round" stroke="#9DC8CF"
     stroke="#D7A06E" stroke-width="1.8">
  <script>window.alert('unsafe')</script>
  <image href="https://example.invalid/icon.png" />
</svg>
''';
    final errors = GoalIconRegistry.validateSvg(unsafe);
    expect(errors, contains('SVG contains forbidden content: <script'));
    expect(errors, contains('SVG contains forbidden content: <image'));
    expect(errors, contains('SVG contains forbidden content: href='));
  });

  test('SVG validation rejects malformed XML and unsupported geometry', () {
    const malformed = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
     fill="none" stroke="#9DC8CF" stroke-width="2">
  <path d="M1 1" />
''';
    final errors = GoalIconRegistry.validateSvg(malformed);
    expect(errors, contains('SVG XML parse failed.'));
    expect(
      errors,
      contains('SVG is missing required spec token: stroke-width="1.8"'),
    );

    const unsupported = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
     fill="none" stroke="#9DC8CF" stroke-linecap="round"
     stroke-linejoin="round" stroke-width="1.8">
  <rect width="24" height="24" fill="#000000" />
  <path d="M1 1" stroke="#123456" />
</svg>
''';
    final unsupportedErrors = GoalIconRegistry.validateSvg(unsupported);
    expect(
      unsupportedErrors,
      contains('SVG contains a full-background rectangle tile.'),
    );
    expect(
      unsupportedErrors,
      contains('SVG contains an unsupported stroke color.'),
    );
  });

  test(
    'lookup and search cover display, semantics, categories, and keywords',
    () {
      expect(registry.findById('learning_open_book')?.displayName, 'Open Book');
      expect(registry.findById(null), isNull);
      expect(registry.findById('not-a-pilot-icon'), isNull);
      expect(registry.search('open book').single.id, 'learning_open_book');
      expect(
        registry.search('LEARNING AND STUDY').single.id,
        'learning_open_book',
      );
      expect(registry.search('money-budgeting').single.id, 'finance_wallet');
      expect(registry.search('APPLICATION').single.id, 'work_briefcase');
      expect(registry.search('not-a-real-icon'), isEmpty);
      expect(
        registry.search('').map((definition) => definition.id),
        GoalIconRegistry.approvedIconIds,
      );
    },
  );

  test(
    'suggestions are local, whole-word, deterministic, and capped at three',
    () {
      final examples = <String, String>{
        'Scripture Study': 'learning_open_book',
        'Apply for Jobs': 'work_briefcase',
        'Monthly Budget': 'finance_wallet',
        'Meet New Friends': 'social_two_people',
        'Temple Attendance': 'spiritual_temple',
        'Wedding Anniversary': 'marriage_rings',
      };
      for (final entry in examples.entries) {
        expect(
          registry.suggestForGoalTitle(entry.key)?.iconId,
          entry.value,
          reason: entry.key,
        );
      }
      expect(registry.suggestForGoalTitle('Unrelated Gardening'), isNull);
      expect(registry.suggestForGoalTitle('bookkeeper'), isNull);
      expect(registry.suggestForGoalTitle('budgeting'), isNull);
      expect(registry.suggestionsForGoalTitle(''), isEmpty);
      expect(
        registry
            .suggestionsForGoalTitle('career study')
            .map((item) => item.iconId),
        <String>['work_briefcase', 'learning_open_book'],
      );
      expect(registry.suggestionsForGoalTitle('career study'), hasLength(2));
    },
  );
}
