class MailUserRelationModel {
  final String id;
  final String mailId;
  final String senderId;
  final String receiverId;
  final String mailType; // to, CC, BCC
  final bool important;
  final bool starred;
  final bool trash;
  final bool isSpam;
  final bool isRead;
  final DateTime createdAt;
  final String? previousMailId; // Đổi tên cho rõ ràng
  final String? tag; // Thêm trường tag

  // Các trường mới
  final bool isSocial;
  final bool isPromotions;
  final bool isUpdates;
  final bool isForums;
  final bool isOutbox;
  final bool isSnoozed;
  final DateTime? snoozedTime;

  MailUserRelationModel({
    required this.id,
    required this.mailId,
    required this.senderId,
    required this.receiverId,
    required this.mailType,
    required this.important,
    required this.starred,
    required this.trash,
    required this.isSpam,
    this.isRead = false,
    required this.createdAt,
    this.previousMailId, // Thêm vào constructor
    this.tag, // Thêm vào constructor
    this.isSocial = false,
    this.isPromotions = false,
    this.isUpdates = false,
    this.isForums = false,
    this.isOutbox = false,
    this.isSnoozed = false,
    this.snoozedTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'mailId': mailId,
        'senderId': senderId,
        'receiverId': receiverId,
        'mailType': mailType,
        'important': important,
        'starred': starred,
        'trash': trash,
        'is_spam': isSpam,
        'is_read': isRead,
        'createdAt': createdAt.toIso8601String(),
        'previousMailId': previousMailId, // Thêm vào map
        'tag': tag, // Thêm vào map
        'is_social': isSocial,
        'is_promotions': isPromotions,
        'is_updates': isUpdates,
        'is_forums': isForums,
        'is_outbox': isOutbox,
        'is_snoozed': isSnoozed,
        'snoozed_time': snoozedTime?.toIso8601String(),
      };
}