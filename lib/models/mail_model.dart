class MailModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhone;
  final String senderEmail;
  final String senderAvatar;
  final String input;
  final String receiverId;
  final String receiverName;
  final String receiverPhone;
  final String receiverEmail;
  final String subject;
  final String content;
  final String styleContent;
  final String cc;
  final String bcc;
  final DateTime? scheduled;
  final String tag;
  final DateTime createdAt;
  final String? trans; // Thêm trường dịch tiếng Việt
  final bool isDrafts; // Thêm trường is_drafts

  MailModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhone,
    required this.senderEmail,
    required this.senderAvatar,
    required this.input,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverEmail,
    required this.subject,
    required this.content,
    required this.styleContent,
    required this.cc,
    required this.bcc,
    required this.scheduled,
    required this.tag,
    required this.createdAt,
    this.trans, // Thêm vào constructor
    this.isDrafts = false, // Mặc định là false
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'senderEmail': senderEmail,
        'senderAvatar': senderAvatar,
        'input': input,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
        'receiverEmail': receiverEmail,
        'subject': subject,
        'content': content,
        'styleContent': styleContent,
        'cc': cc,
        'bcc': bcc,
        'scheduled': scheduled?.toIso8601String(),
        'tag': tag,
        'createdAt': createdAt.toIso8601String(),
        'trans': trans, // Thêm vào map
        'is_drafts': isDrafts, // Thêm vào map
      };
}