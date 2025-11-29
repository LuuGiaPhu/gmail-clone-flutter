import 'package:cloud_firestore/cloud_firestore.dart';

class MailAttachmentModel {
  final String id;
  final String mailId;
  final String name;
  final String url;
  final DateTime uploadedAt;

  MailAttachmentModel({
    required this.id,
    required this.mailId,
    required this.name,
    required this.url,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'mailId': mailId,
        'name': name,
        'url': url,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  MailAttachmentModel copyWith({
    String? id,
    String? mailId,
    String? name,
    String? url,
    DateTime? uploadedAt,
  }) {
    return MailAttachmentModel(
      id: id ?? this.id,
      mailId: mailId ?? this.mailId,
      name: name ?? this.name,
      url: url ?? this.url,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  // Thêm hàm fromMap để chuyển từ Map sang MailAttachmentModel
  factory MailAttachmentModel.fromMap(Map<String, dynamic> map) {
    return MailAttachmentModel(
      id: map['id'] ?? '',
      mailId: map['mailId'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      uploadedAt: map['uploadedAt'] is Timestamp
          ? (map['uploadedAt'] as Timestamp).toDate()
          : (map['uploadedAt'] is DateTime
              ? map['uploadedAt']
              : DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ?? DateTime.now()),
    );
  }
}