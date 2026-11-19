import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/messaging/domain/message_validator.dart';

void main() {
  group('MessageValidator.check', () {
    test('rejects empty and whitespace-only text', () {
      expect(MessageValidator.check(null), MessageIssue.empty);
      expect(MessageValidator.check(''), MessageIssue.empty);
      expect(MessageValidator.check('  \n\t '), MessageIssue.empty);
    });

    test('accepts normal text, trimmed or not', () {
      expect(MessageValidator.check('Bonjour'), isNull);
      expect(MessageValidator.check('  Bonjour  '), isNull);
    });

    test('enforces the maximum length after trimming', () {
      expect(MessageValidator.check('a' * MessageValidator.maxLength), isNull);
      expect(MessageValidator.check('a' * (MessageValidator.maxLength + 1)), MessageIssue.tooLong);
      expect(MessageValidator.check('  ${'a' * MessageValidator.maxLength}  '), isNull);
    });
  });

  group('MessageValidator.preview', () {
    test('keeps short text untouched', () {
      expect(MessageValidator.preview('Hello'), 'Hello');
    });

    test('cuts long text with an ellipsis', () {
      final p = MessageValidator.preview('a' * 500);
      expect(p.runes.length, MessageValidator.previewLength + 1);
      expect(p.endsWith('…'), isTrue);
    });

    test('never splits an emoji', () {
      final p = MessageValidator.preview('😀' * 300);
      expect(p.runes.length, MessageValidator.previewLength + 1);
      expect(p.runes.first, '😀'.runes.first);
    });
  });
}
