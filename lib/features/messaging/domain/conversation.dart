/// SHARED conversation model (`conversations/{id}`, spec §6.6). The Agent module
/// reads it; it never keeps a second messaging database for agents.
///
/// Conversation id is deterministic: `{propertyId}_{userId}` -> one thread per
/// user per listing, and "open or create" needs no query.
class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.userId,
    required this.recipientId,
    required this.propertyId,
    this.userName,
    this.recipientName,
    this.propertyTitle,
    this.propertyImage,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastReadAt = const {},
    this.createdAt,
  });

  final String id;

  /// Exactly `[userId, recipientId]`; drives every access rule.
  final List<String> participants;

  /// The user who initiated the contact.
  final String userId;

  /// The professional (property.agentId) or the owner (property.ownerId).
  final String recipientId;
  final String propertyId;

  /// Public display snapshots, so lists need no extra reads.
  final String? userName;

  /// Display name of the professional / owner (copied from the listing when the
  /// thread is created). Absent on threads created before Module 11.
  final String? recipientName;
  final String? propertyTitle;
  final String? propertyImage;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, DateTime> lastReadAt;
  final DateTime? createdAt;

  /// A conversation opened but never written to is not an inquiry yet.
  bool get hasMessages => (lastMessage ?? '').isNotEmpty;

  String otherParticipant(String me) => me == userId ? recipientId : userId;

  /// Name of the person on the other side, seen from [me].
  String partnerNameFor(String me) => me == userId ? (recipientName ?? 'Annonceur') : (userName ?? 'Utilisateur intéressé');

  /// True when [uid] has opened the conversation at or after [at]. Used for the
  /// "Seen" indicator under the sender's latest message.
  bool wasReadBy(String uid, DateTime at) {
    final read = lastReadAt[uid];
    return read != null && !read.isBefore(at);
  }

  /// Unread for [me] when the last message is from the other side and newer
  /// than my last read time.
  bool isUnreadFor(String me) {
    if (!hasMessages || lastSenderId == null || lastSenderId == me) return false;
    final read = lastReadAt[me];
    final last = lastMessageAt;
    if (last == null) return true;
    return read == null || last.isAfter(read);
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final String text;

  /// Null while the server timestamp is still being resolved.
  final DateTime? createdAt;

  /// Written locally, not yet acknowledged by the server (offline / slow link).
  final bool pending;
}

/// Result of the conversation-list query. [fromCache] is true while the data
/// comes from the local cache only (typically: no connection).
class ConversationList {
  const ConversationList({required this.items, this.fromCache = false});

  final List<Conversation> items;
  final bool fromCache;

  int unreadCountFor(String me) => items.where((c) => c.isUnreadFor(me)).length;
}
