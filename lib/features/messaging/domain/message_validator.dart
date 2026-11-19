enum MessageIssue { empty, tooLong }

/// Pure rules for the text of a message (spec §12.2 / §15). Shared by the
/// repository and the UI, and mirrored by the Firestore rules.
class MessageValidator {
  const MessageValidator._();

  static const maxLength = 2000;

  /// Length of the preview stored in `conversations/{id}.lastMessage`.
  static const previewLength = 140;

  /// Null when [raw] can be sent, otherwise why it can not.
  static MessageIssue? check(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return MessageIssue.empty;
    if (text.runes.length > maxLength) return MessageIssue.tooLong;
    return null;
  }

  static String normalize(String raw) => raw.trim();

  /// Short text for lists. Cuts on code points so an emoji is never split.
  static String preview(String text) {
    final runes = text.runes;
    if (runes.length <= previewLength) return text;
    return '${String.fromCharCodes(runes.take(previewLength))}…';
  }
}
