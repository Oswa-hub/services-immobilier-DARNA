import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../properties/domain/entities/property.dart';
import '../domain/conversation.dart';
import '../domain/message_validator.dart';

enum ConversationFailureType { notSignedIn, ownListing, unavailable, empty, tooLong, permissionDenied, network, unknown }

/// What happened to a message the user just sent.
enum SendOutcome {
  /// Acknowledged by the server.
  sent,

  /// Saved locally and waiting for the connection; Firestore delivers it later.
  queued,
}

class ConversationFailure implements Exception {
  const ConversationFailure(this.type);
  final ConversationFailureType type;

  String get message => switch (type) {
        ConversationFailureType.notSignedIn => 'Connectez-vous pour envoyer des messages.',
        ConversationFailureType.ownListing => 'C\'est votre propre annonce.',
        ConversationFailureType.unavailable => 'Ce bien n\'est plus disponible.',
        ConversationFailureType.empty => 'Écrivez un message avant de l\'envoyer.',
        ConversationFailureType.tooLong => 'Votre message est trop long (${MessageValidator.maxLength} caractères maximum).',
        ConversationFailureType.permissionDenied => 'Cette conversation n\'est pas accessible.',
        ConversationFailureType.network => 'Impossible d\'envoyer le message. Vérifiez votre connexion et réessayez.',
        ConversationFailureType.unknown => 'Une erreur est survenue. Réessayez.',
      };

  @override
  String toString() => 'ConversationFailure($type)';
}

/// Messaging repository (Module 11), shared with "Contact agent" and the agent's
/// Inquiries page. One thread per (property, user); two participants.
class ConversationRepository {
  ConversationRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const maxMessageLength = MessageValidator.maxLength;

  /// Messages loaded per page (the newest ones first).
  static const messagesPageSize = 30;

  /// Firestore queues writes while offline and only acknowledges them once the
  /// server answers. Past this delay the message is reported as [SendOutcome.queued].
  static const sendAckTimeout = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> get _conversations => _db.collection('conversations');

  String get _uid {
    final id = _auth.currentUser?.uid;
    if (id == null) throw const ConversationFailure(ConversationFailureType.notSignedIn);
    return id;
  }

  static String idFor(String propertyId, String userId) => '${propertyId}_$userId';

  /// Who receives the inquiry: the responsible professional, else the owner.
  static String recipientOf(Property p) => (p.agentId != null && p.agentId!.isNotEmpty) ? p.agentId! : p.ownerId;

  ConversationFailure _map(Object e) {
    if (e is ConversationFailure) return e;
    if (e is TimeoutException) return const ConversationFailure(ConversationFailureType.network);
    if (e is FirebaseException) {
      debugPrint('Conversation error [${e.code}]: ${e.message}');
      return ConversationFailure(switch (e.code) {
        'permission-denied' => ConversationFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => ConversationFailureType.network,
        _ => ConversationFailureType.unknown,
      });
    }
    debugPrint('Conversation unexpected error: $e');
    return const ConversationFailure(ConversationFailureType.unknown);
  }

  /// Find or create the thread of ([property], current user). Idempotent and
  /// race-free: the id is deterministic and the read + create run in one
  /// transaction, so two quick taps can never create two threads.
  Future<Conversation> openOrCreate(Property property, {String? userName}) async {
    try {
      final me = _uid;
      final recipient = recipientOf(property);
      if (recipient == me) throw const ConversationFailure(ConversationFailureType.ownListing);
      if (!property.isPublic) throw const ConversationFailure(ConversationFailureType.unavailable);

      final ref = _conversations.doc(idFor(property.id, me));
      final name = _s(userName);
      // The listing only carries the OWNER's name: when an agent manages it, the
      // agent is the recipient, so no name is copied (the UI says "Annonceur").
      final recipientName = property.agentId == null ? _s(property.ownerName) : null;
      final participants = [me, recipient];

      return await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final existing = snap.data();
        if (snap.exists && existing != null) {
          final c = _fromMap(snap.id, existing);
          if (c != null) return c;
        }
        tx.set(ref, {
          'participants': participants,
          'userId': me,
          'recipientId': recipient,
          'propertyId': property.id,
          'userName': name,
          'recipientName': recipientName,
          'propertyTitle': property.title,
          'propertyImage': property.mainImage,
          'lastMessage': null,
          'lastMessageAt': null,
          'lastSenderId': null,
          'lastReadAt': <String, dynamic>{},
          'messageCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return Conversation(
          id: ref.id,
          participants: participants,
          userId: me,
          recipientId: recipient,
          propertyId: property.id,
          userName: name,
          recipientName: recipientName,
          propertyTitle: property.title,
          propertyImage: property.mainImage,
        );
      });
    } catch (e) {
      throw _map(e);
    }
  }

  Stream<Conversation?> watchConversation(String id) => _conversations.doc(id).snapshots().map((s) {
        final d = s.data();
        return (!s.exists || d == null) ? null : _fromMap(s.id, d);
      });

  /// Inquiries received by [recipientId] (agent / owner). Index:
  /// recipientId ASC, lastMessageAt DESC. Threads without messages are hidden.
  Stream<List<Conversation>> watchReceived(String recipientId, {int limit = 50}) => _conversations
      .where('recipientId', isEqualTo: recipientId)
      .orderBy('lastMessageAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?_fromMap(d.id, d.data())].where((c) => c.hasMessages).toList());

  /// Every conversation [userId] takes part in, as buyer OR as professional.
  /// Index: participants ARRAY_CONTAINS, lastMessageAt DESC. Threads without
  /// messages are hidden. [ConversationList.fromCache] tells the UI it is offline.
  Stream<ConversationList> watchMine(String userId, {int limit = 50}) => _conversations
      .where('participants', arrayContains: userId)
      .orderBy('lastMessageAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((s) => ConversationList(
            items: [for (final d in s.docs) ?_fromMap(d.id, d.data())].where((c) => c.hasMessages).toList(),
            fromCache: s.metadata.isFromCache,
          ));

  /// Newest first, so a reversed ListView shows the latest at the bottom.
  /// Pagination: raise [limit] to load older messages (the stream re-opens).
  /// Metadata changes are included so a message not yet acknowledged by the
  /// server is flagged [ChatMessage.pending].
  Stream<List<ChatMessage>> watchMessages(String conversationId, {int limit = messagesPageSize}) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((s) => [for (final d in s.docs) ?_message(d.id, d.data(), pending: d.metadata.hasPendingWrites)]);

  /// Validates, then writes the message AND the conversation summary in one
  /// batch. Throws [ConversationFailure] when nothing was saved (the UI keeps
  /// the text so the user can retry). Returns [SendOutcome.queued] when the
  /// write is stored locally and will be delivered when the connection returns.
  Future<SendOutcome> sendMessage(String conversationId, String text) async {
    try {
      final me = _uid;
      final issue = MessageValidator.check(text);
      if (issue != null) {
        throw ConversationFailure(
          issue == MessageIssue.empty ? ConversationFailureType.empty : ConversationFailureType.tooLong,
        );
      }
      final t = MessageValidator.normalize(text);

      final convo = _conversations.doc(conversationId);
      final msg = convo.collection('messages').doc();
      final batch = _db.batch()
        ..set(msg, {
          'senderId': me,
          'text': t,
          'attachments': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..update(convo, {
          'lastMessage': MessageValidator.preview(t),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': me,
          'lastReadAt.$me': FieldValue.serverTimestamp(),
        });
      try {
        await batch.commit().timeout(sendAckTimeout);
        return SendOutcome.sent;
      } on TimeoutException {
        return SendOutcome.queued;
      }
    } catch (e) {
      throw _map(e);
    }
  }

  /// Rules allow a participant to change ONLY `lastReadAt.<own uid>`.
  Future<void> markRead(String conversationId) async {
    try {
      await _conversations.doc(conversationId).update({'lastReadAt.$_uid': FieldValue.serverTimestamp()});
    } catch (_) {
      // Read receipts are best effort.
    }
  }

  // ---- mapping ----------------------------------------------------------
  static DateTime? _date(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => null,
      };

  static String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static Conversation? _fromMap(String id, Map<String, dynamic> d) {
    final user = _s(d['userId']);
    final recipient = _s(d['recipientId']);
    final property = _s(d['propertyId']);
    if (user == null || recipient == null || property == null) return null;
    final read = d['lastReadAt'];
    return Conversation(
      id: id,
      participants: d['participants'] is List ? (d['participants'] as List).whereType<String>().toList() : [user, recipient],
      userId: user,
      recipientId: recipient,
      propertyId: property,
      userName: _s(d['userName']),
      recipientName: _s(d['recipientName']),
      propertyTitle: _s(d['propertyTitle']),
      propertyImage: _s(d['propertyImage']),
      lastMessage: _s(d['lastMessage']),
      lastMessageAt: _date(d['lastMessageAt']),
      lastSenderId: _s(d['lastSenderId']),
      lastReadAt: read is Map
          ? {
              for (final e in read.entries)
                if (e.key is String && _date(e.value) != null) e.key as String: _date(e.value)!,
            }
          : const {},
      createdAt: _date(d['createdAt']),
    );
  }

  static ChatMessage? _message(String id, Map<String, dynamic> d, {bool pending = false}) {
    final sender = _s(d['senderId']);
    final text = _s(d['text']);
    if (sender == null || text == null) return null;
    return ChatMessage(id: id, senderId: sender, text: text, createdAt: _date(d['createdAt']), pending: pending);
  }
}
