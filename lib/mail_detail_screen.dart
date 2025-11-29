import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'compose_mail_screen.dart'; // Đảm bảo đã import ở đầu file mail_detail_screen.dart
import 'main.dart' show MailFilter;
import 'package:http/http.dart' as http;


// ...existing imports...

Future<String> suggestReplyWithGemini(String subject, String content) async {
  const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
  final prompt = '''
Hãy gợi ý nội dung trả lời phản hồi cho thư vừa gởi đến, biết rằng thư vừa gởi đến có tiêu đề là "$subject"; và nội dung của thư vừa gửi đến là "$content".
Chỉ trả về nội dung gợi ý, không giải thích gì thêm.
''';

  final body = jsonEncode({
    "contents": [
      {
        "parts": [
          {"text": prompt}
        ]
      }
    ]
  });

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      return text.trim();
    } else {
      print('Gemini API error: ${response.statusCode} - ${response.body}');
      return '';
    }
  } catch (e) {
    print('Gemini Exception: $e');
    return '';
  }
}
class MailDetailScreen extends StatefulWidget {
  final String mailId;
  final String currentUserId; // id của user đăng nhập hiện tại
  final bool isSent; // thêm biến này
  final MailFilter filter; // Thêm dòng này
  final int darkMode;

  const MailDetailScreen({
    super.key,
    required this.mailId,
    required this.currentUserId,
    this.isSent = false, // mặc định false
    required this.filter, // Thêm dòng này
    required this.darkMode,
  });

  @override
  State<MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<MailDetailScreen> {
  Map<String, dynamic>? mailData;
  Map<String, dynamic>? senderData;
  Map<String, dynamic>? mailsUserData;
  bool loading = true;
  String? mailTypeDisplay;
  List<Map<String, dynamic>> attachments = [];
  String? transContent; // Dữ liệu bản dịch
  bool showTrans = false; // Trạng thái hiển thị bản dịch
  String? summaryContent;
  bool loadingSummary = false;
  bool showSummary = false;
  final TextEditingController _tagController = TextEditingController();
  bool isOutbox = false;
  @override
  void initState() {
    super.initState();
    fetchMailDetail();
  }

    Future<void> fetchMailDetail() async {
  if (widget.isSent) {
    // Trường hợp mail đã gửi, chỉ lấy từ bảng mails
    final mailSnap = await FirebaseFirestore.instance
        .collection('mails')
        .doc(widget.mailId)
        .get();
    if (!mailSnap.exists) {
      setState(() {
        loading = false;
      });
      return;
    }
    mailData = mailSnap.data();
    transContent = mailData?['trans'];
    // Lấy file đính kèm
    attachments = [];
    final attachSnap = await FirebaseFirestore.instance
        .collection('mail_attachments')
        .where('mailId', isEqualTo: widget.mailId)
        .get();
    for (var doc in attachSnap.docs) {
      final data = doc.data();
      attachments.add({
        'name': data['name'] ?? '',
        'url': data['url'] ?? '',
      });
    }
    // Lấy thông tin input, CC, BCC để hiển thị
    final input = mailData?['input'] ?? '';
    final cc = mailData?['cc'] ?? '';
    final bcc = mailData?['bcc'] ?? '';
    String display = '';
    if (input.toString().isNotEmpty) display += 'To: $input';
    if (cc.toString().isNotEmpty) display += '${display.isNotEmpty ? '   ' : ''}CC: $cc';
    if (bcc.toString().isNotEmpty) display += '${display.isNotEmpty ? '   ' : ''}BCC: $bcc';
    setState(() {
      mailTypeDisplay = display;
      loading = false;
    });
    return;
  }

  // Trường hợp mail nhận, lấy từ bảng mails_users và mails
  final mailsUserSnap = await FirebaseFirestore.instance
      .collection('mails_users')
      .doc(widget.mailId)
      .get();

  if (!mailsUserSnap.exists) {
    setState(() {
      loading = false;
    });
    return;
  }
  mailsUserData = mailsUserSnap.data();
  // Lấy mailType
  final String? mailType = mailsUserData?['mailType'];
  final String? mailDocId = mailsUserData?['mailId'];
  // Kiểm tra nếu là mail đã gửi (outbox)
  isOutbox = mailsUserData != null && mailsUserData?['is_outbox'] == true;
  String? mailTypeResult;

  // Lấy tag từ mails_users
  String? tagValue = mailsUserData?['tag'];

  if (mailType == 'to' || mailType == 'CC') {
    if (mailDocId != null && mailDocId.isNotEmpty) {
      final mailSnap = await FirebaseFirestore.instance
          .collection('mails')
          .doc(mailDocId)
          .get();
      if (mailSnap.exists) {
        mailData = mailSnap.data();
        if (mailType == 'to') {
          mailTypeResult = "To: ${mailData?['input'] ?? ''}";
        } else if (mailType == 'CC') {
          mailTypeResult = "CC: ${mailData?['cc'] ?? ''}";
        }
        // Lấy dữ liệu bản dịch
        transContent = mailData?['trans'];
      }
    }
  } else if (mailType == 'BCC') {
    final receiverId = mailsUserData?['receiverId'];
    if (receiverId != null && receiverId.isNotEmpty) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: receiverId)
          .limit(1)
          .get();
      if (userSnap.docs.isNotEmpty) {
        final userData = userSnap.docs.first.data();
        mailTypeResult = "BCC: ${userData['email'] ?? ''}";
      }
    }
    if (mailDocId != null && mailDocId.isNotEmpty) {
      final mailSnap = await FirebaseFirestore.instance
          .collection('mails')
          .doc(mailDocId)
          .get();
      if (mailSnap.exists) {
        mailData = mailSnap.data();
        // Lấy dữ liệu bản dịch
        transContent = mailData?['trans'];
      }
    }
  }

  // Lấy thông tin người gửi
  if (mailData?['senderId'] != null && mailData!['senderId'].toString().isNotEmpty) {
    final senderSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: mailData!['senderId'])
        .limit(1)
        .get();
    if (senderSnap.docs.isNotEmpty) {
      senderData = senderSnap.docs.first.data();
    }
  }

  // Lấy danh sách file đính kèm
  attachments = [];
  if (mailDocId != null && mailDocId.isNotEmpty) {
    final attachSnap = await FirebaseFirestore.instance
        .collection('mail_attachments')
        .where('mailId', isEqualTo: mailDocId)
        .get();
    for (var doc in attachSnap.docs) {
      final data = doc.data();
      attachments.add({
        'name': data['name'] ?? '',
        'url': data['url'] ?? '',
      });
    }
  }

  // Gán tag từ mails_users vào mailData để hiển thị (nếu có)
  if (mailData != null && tagValue != null) {
    mailData!['tag'] = tagValue;
  }

  setState(() {
    mailTypeDisplay = mailTypeResult;
    loading = false;
    isOutbox = mailsUserData != null && mailsUserData?['is_outbox'] == true;
  });
}
  Future<String> summarizeWithGemini(String content) async {
    const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
    final prompt = '''
  Hãy tóm tắt nội dung sau đây bằng tiếng Việt: $content
  ''';
  
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    });
  
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return text.trim();
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return '';
      }
    } catch (e) {
      print('Gemini Exception: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (mailData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mail Detail')),
        body: const Center(child: Text('Không tìm thấy email này!')),
      );
    }

    final senderName = mailData?['senderName'] ?? '';
    final senderEmail = mailData?['senderEmail'] ?? '';
    final senderAvatar = mailData?['senderAvatar'] ?? '';
    final subject = mailData?['subject'] ?? '';
    final styleContent = mailData?['styleContent'] ?? '';
    final isTrash = mailsUserData != null && mailsUserData?['trash'] == true;
    quill.QuillController? quillController;
    try {
      final doc = quill.Document.fromJson(jsonDecode(styleContent));
      quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      quillController = null;
    }

    final createdAt = mailData?['createdAt'];
    final isStarred = mailsUserData != null && mailsUserData?['starred'] == true;
    final isImportant = mailsUserData != null && mailsUserData?['important'] == true;

    String formattedTime = '';
    if (createdAt != null) {
      try {
        final dt = createdAt is String
            ? DateTime.parse(createdAt)
            : (createdAt is Timestamp ? createdAt.toDate() : null);
        if (dt != null) {
          formattedTime =
              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}";
        }
      } catch (_) {}
    }

    return Scaffold(
            appBar: AppBar(
        title: const Text('Chi tiết Email'),
        actions: [
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              if (width < 400) {
                // Nếu màn nhỏ, chỉ hiện 1 nút PopupMenuButton
                return PopupMenuButton<int>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(isStarred ? Icons.star : Icons.star_border, color: Colors.yellow),
                          const SizedBox(width: 8),
                          const Text('Star'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(isImportant ? Icons.label_important : Icons.label_important_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Important'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(
                            mailsUserData != null && mailsUserData?['is_spam'] == true
                                ? Icons.report
                                : Icons.report_gmailerrorred_outlined,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Text('Spam'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 3,
                      child: Row(
                        children: [
                          Icon(
                            mailsUserData != null && mailsUserData?['is_read'] == true
                                ? Icons.mark_email_read
                                : Icons.mark_email_unread,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(mailsUserData != null && mailsUserData?['is_read'] == true ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 4,
                      child: Row(
                        children: [
                          Icon(
                            isTrash ? Icons.delete : Icons.delete_outline,
                            color: isTrash ? Colors.grey[400] : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(isTrash ? 'Xóa hoàn toàn' : 'Chuyển vào thùng rác'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                        value: 5,
                        child: Row(
                          children: [
                            Icon(
                              mailsUserData != null && mailsUserData?['is_snoozed'] == true
                                  ? Icons.snooze
                                  : Icons.snooze_outlined,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.filter == MailFilter.snoozed
                                  ? 'Bỏ snooze'
                                  : 'Snooze',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 6,
                        child: Row(
                          children: [
                            Icon(Icons.outbox, color: isOutbox ? Colors.deepPurple : Colors.grey),
                            const SizedBox(width: 8),
                            Text(isOutbox ? 'Bỏ khỏi Outbox' : 'Chuyển vào Outbox'),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) async {
                    // ...giữ nguyên code xử lý từng action như cũ...
                    if (value == 0) {
                      final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                      final docSnap = await docRef.get();
                      if (docSnap.exists) {
                        final currentStar = docSnap.data()?['starred'] == true;
                        await docRef.update({'starred': !currentStar});
                        setState(() {
                          mailsUserData?['starred'] = !currentStar;
                        });
                      }
                    } else if (value == 1) {
                      final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                      final docSnap = await docRef.get();
                      if (docSnap.exists) {
                        final currentImportant = docSnap.data()?['important'] == true;
                        await docRef.update({'important': !currentImportant});
                        setState(() {
                          mailsUserData?['important'] = !currentImportant;
                        });
                      }
                    } else if (value == 2) {
                      final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                      final docSnap = await docRef.get();
                      if (docSnap.exists) {
                        final currentSpam = docSnap.data()?['is_spam'] == true;
                        await docRef.update({'is_spam': !currentSpam});
                        setState(() {
                          mailsUserData?['is_spam'] = !currentSpam;
                        });
                      }
                    } else if (value == 3) {
                      final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                      final docSnap = await docRef.get();
                      if (docSnap.exists) {
                        final currentRead = docSnap.data()?['is_read'] == true;
                        await docRef.update({'is_read': !currentRead});
                        setState(() {
                          mailsUserData?['is_read'] = !currentRead;
                        });
                      }
                    } else if (value == 4) {
                      final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                      final docSnap = await docRef.get();
                      if (docSnap.exists) {
                        final currentTrash = docSnap.data()?['trash'] == true;
                        if (currentTrash && widget.filter == MailFilter.trash) {
                          final mailDocId = docSnap.data()?['mailId'];
                          if (mailDocId != null && mailDocId.toString().isNotEmpty) {
                            final mailsUsersQuery = await FirebaseFirestore.instance
                                .collection('mails_users')
                                .where('mailId', isEqualTo: mailDocId)
                                .get();
                            for (var doc in mailsUsersQuery.docs) {
                              await doc.reference.delete();
                            }
                            final attachmentsQuery = await FirebaseFirestore.instance
                                .collection('mail_attachments')
                                .where('mailId', isEqualTo: mailDocId)
                                .get();
                            for (var doc in attachmentsQuery.docs) {
                              await doc.reference.delete();
                            }
                            await FirebaseFirestore.instance.collection('mails').doc(mailDocId).delete();
                          }
                          await docRef.delete();
                        } else {
                          await docRef.update({'trash': !currentTrash});
                          setState(() {
                            mailsUserData?['trash'] = !currentTrash;
                          });
                        }
                      }
                      if (mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } else if (value == 5) {
                        // Xử lý snooze
                        if (widget.isSent) return;
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (!docSnap.exists) return;

                        if (widget.filter == MailFilter.snoozed) {
                          // Nếu đang ở filter snoozed, bỏ snooze
                          await docRef.update({'is_snoozed': false, 'snoozed_time': null});
                          if (mounted) {
                            setState(() {
                              mailsUserData?['is_snoozed'] = false;
                              mailsUserData?['snoozed_time'] = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã bỏ snooze email!')),
                            );
                            Navigator.of(context).pop(true);
                          }
                          return;
                        }

                        // Nếu không phải filter snoozed, chọn thời gian snooze
                        int? selectedSeconds;
                        TextEditingController customController = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('Snooze email'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        title: const Text('10 giây'),
                                        onTap: () { selectedSeconds = 10; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('30 giây'),
                                        onTap: () { selectedSeconds = 30; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('1 phút'),
                                        onTap: () { selectedSeconds = 60; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('5 phút'),
                                        onTap: () { selectedSeconds = 300; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('30 phút'),
                                        onTap: () { selectedSeconds = 1800; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('1 giờ'),
                                        onTap: () { selectedSeconds = 3600; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('8 giờ'),
                                        onTap: () { selectedSeconds = 28800; Navigator.pop(context); },
                                      ),
                                      const Divider(),
                                      TextField(
                                        controller: customController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Tùy chọn (phút hoặc giờ, ví dụ: 15m, 2h)',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          final input = customController.text.trim().toLowerCase();
                                          if (input.endsWith('h')) {
                                            final h = int.tryParse(input.replaceAll('h', ''));
                                            if (h != null) selectedSeconds = h * 3600;
                                          } else if (input.endsWith('m')) {
                                            final m = int.tryParse(input.replaceAll('m', ''));
                                            if (m != null) selectedSeconds = m * 60;
                                          } else {
                                            final s = int.tryParse(input);
                                            if (s != null) selectedSeconds = s;
                                          }
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Snooze'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                        if (selectedSeconds != null && selectedSeconds! > 0) {
                          final snoozedTime = DateTime.now().add(Duration(seconds: selectedSeconds!));
                          await docRef.update({'is_snoozed': true, 'snoozed_time': snoozedTime});
                          if (mounted) {
                            setState(() {
                              mailsUserData?['is_snoozed'] = true;
                              mailsUserData?['snoozed_time'] = snoozedTime;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email đã được snooze!')),
                            );
                            Navigator.of(context).pop(true);
                          }
                        }
                      }
                      else if (value == 6) {
                        if (widget.filter == MailFilter.outbox && mailsUserData != null) {
                          final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                          await docRef.update({'is_outbox': false});
                          if (mounted) {
                            setState(() {
                              mailsUserData?['is_outbox'] = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã bỏ khỏi Outbox!')),
                            );
                            Navigator.of(context).pop(true);
                          }
                        }
                      }
                  },
                );
              } else {
                // Nếu màn hình đủ rộng, hiện từng nút action riêng biệt
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(isStarred ? Icons.star : Icons.star_border, color: Colors.yellow),
                      tooltip: 'Star',
                      onPressed: () async {
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (docSnap.exists) {
                          final currentStar = docSnap.data()?['starred'] == true;
                          await docRef.update({'starred': !currentStar});
                          setState(() {
                            mailsUserData?['starred'] = !currentStar;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(isImportant ? Icons.label_important : Icons.label_important_outline, color: Colors.red),
                      tooltip: 'Important',
                      onPressed: () async {
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (docSnap.exists) {
                          final currentImportant = docSnap.data()?['important'] == true;
                          await docRef.update({'important': !currentImportant});
                          setState(() {
                            mailsUserData?['important'] = !currentImportant;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        mailsUserData != null && mailsUserData?['is_spam'] == true
                            ? Icons.report
                            : Icons.report_gmailerrorred_outlined,
                        color: Colors.orange,
                      ),
                      tooltip: 'Spam',
                      onPressed: () async {
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (docSnap.exists) {
                          final currentSpam = docSnap.data()?['is_spam'] == true;
                          await docRef.update({'is_spam': !currentSpam});
                          setState(() {
                            mailsUserData?['is_spam'] = !currentSpam;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        mailsUserData != null && mailsUserData?['is_read'] == true
                            ? Icons.mark_email_read
                            : Icons.mark_email_unread,
                        color: Colors.blueAccent,
                      ),
                      tooltip: mailsUserData != null && mailsUserData?['is_read'] == true
                          ? 'Đánh dấu chưa đọc'
                          : 'Đánh dấu đã đọc',
                      onPressed: () async {
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (docSnap.exists) {
                          final currentRead = docSnap.data()?['is_read'] == true;
                          await docRef.update({'is_read': !currentRead});
                          setState(() {
                            mailsUserData?['is_read'] = !currentRead;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isTrash ? Icons.delete : Icons.delete_outline,
                        color: isTrash
                            ? (widget.darkMode == 0 ? Colors.grey : Colors.grey[400]) // Light: xám đậm, Dark: xám nhạt
                            : (widget.darkMode == 0 ? const Color.fromARGB(255, 135, 135, 135) : Colors.white),     // Light: đỏ, Dark: trắng
                      ),
                      tooltip: isTrash ? 'Xóa hoàn toàn' : 'Chuyển vào thùng rác',
                      onPressed: () async {
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (docSnap.exists) {
                          final currentTrash = docSnap.data()?['trash'] == true;
                          if (currentTrash && widget.filter == MailFilter.trash) {
                            final mailDocId = docSnap.data()?['mailId'];
                            if (mailDocId != null && mailDocId.toString().isNotEmpty) {
                              final mailsUsersQuery = await FirebaseFirestore.instance
                                  .collection('mails_users')
                                  .where('mailId', isEqualTo: mailDocId)
                                  .get();
                              for (var doc in mailsUsersQuery.docs) {
                                await doc.reference.delete();
                              }
                              final attachmentsQuery = await FirebaseFirestore.instance
                                  .collection('mail_attachments')
                                  .where('mailId', isEqualTo: mailDocId)
                                  .get();
                              for (var doc in attachmentsQuery.docs) {
                                await doc.reference.delete();
                              }
                              await FirebaseFirestore.instance.collection('mails').doc(mailDocId).delete();
                            }
                            await docRef.delete();
                          } else {
                            await docRef.update({'trash': !currentTrash});
                            setState(() {
                              mailsUserData?['trash'] = !currentTrash;
                            });
                          }
                        }
                        if (mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                    // --- Bổ sung nút Snooze ---
                    IconButton(
                      icon: Icon(
                        mailsUserData != null && mailsUserData?['is_snoozed'] == true
                            ? Icons.snooze
                            : Icons.snooze_outlined,
                        color: Colors.orange,
                      ),
                      tooltip: widget.filter == MailFilter.snoozed ? 'Bỏ snooze' : 'Snooze',
                      onPressed: () async {
                        if (widget.isSent) return;
                        final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                        final docSnap = await docRef.get();
                        if (!docSnap.exists) return;

                        if (widget.filter == MailFilter.snoozed) {
                          // Nếu đang ở filter snoozed, bỏ snooze
                          await docRef.update({'is_snoozed': false, 'snoozed_time': null});
                          if (mounted) {
                            setState(() {
                              mailsUserData?['is_snoozed'] = false;
                              mailsUserData?['snoozed_time'] = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã bỏ snooze email!')),
                            );
                            Navigator.of(context).pop(true);
                          }
                          return;
                        }

                        // Nếu không phải filter snoozed, chọn thời gian snooze
                        int? selectedSeconds;
                        TextEditingController customController = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('Snooze email'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        title: const Text('10 giây'),
                                        onTap: () { selectedSeconds = 10; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('30 giây'),
                                        onTap: () { selectedSeconds = 30; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('1 phút'),
                                        onTap: () { selectedSeconds = 60; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('5 phút'),
                                        onTap: () { selectedSeconds = 300; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('30 phút'),
                                        onTap: () { selectedSeconds = 1800; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('1 giờ'),
                                        onTap: () { selectedSeconds = 3600; Navigator.pop(context); },
                                      ),
                                      ListTile(
                                        title: const Text('8 giờ'),
                                        onTap: () { selectedSeconds = 28800; Navigator.pop(context); },
                                      ),
                                      const Divider(),
                                      TextField(
                                        controller: customController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Tùy chọn (phút hoặc giờ, ví dụ: 15m, 2h)',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          final input = customController.text.trim().toLowerCase();
                                          if (input.endsWith('h')) {
                                            final h = int.tryParse(input.replaceAll('h', ''));
                                            if (h != null) selectedSeconds = h * 3600;
                                          } else if (input.endsWith('m')) {
                                            final m = int.tryParse(input.replaceAll('m', ''));
                                            if (m != null) selectedSeconds = m * 60;
                                          } else {
                                            final s = int.tryParse(input);
                                            if (s != null) selectedSeconds = s;
                                          }
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Snooze'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                        if (selectedSeconds != null && selectedSeconds! > 0) {
                          final snoozedTime = DateTime.now().add(Duration(seconds: selectedSeconds!));
                          await docRef.update({'is_snoozed': true, 'snoozed_time': snoozedTime});
                          if (mounted) {
                            setState(() {
                              mailsUserData?['is_snoozed'] = true;
                              mailsUserData?['snoozed_time'] = snoozedTime;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email đã được snooze!')),
                            );
                            Navigator.of(context).pop(true);
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.outbox,
                        color: isOutbox ? Colors.deepPurple : Colors.grey,
                      ),
                      tooltip: isOutbox ? 'Bỏ khỏi Outbox' : 'Chuyển vào Outbox',
                      onPressed: () async {
                        if (mailsUserData != null) {
                          final docRef = FirebaseFirestore.instance.collection('mails_users').doc(widget.mailId);
                          if (isOutbox) {
                            // Đang là Outbox, bấm để bỏ khỏi Outbox
                            await docRef.update({'is_outbox': false});
                            if (mounted) {
                              setState(() {
                                mailsUserData?['is_outbox'] = false;
                                isOutbox = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã bỏ khỏi Outbox!')),
                              );
                              if (widget.filter == MailFilter.outbox) {
                                Navigator.of(context).pop(true); // reload danh sách nếu đang ở filter outbox
                              }
                            }
                          } else {
                            // Chưa là Outbox, bấm để chuyển vào Outbox
                            await docRef.update({'is_outbox': true});
                            if (mounted) {
                              setState(() {
                                mailsUserData?['is_outbox'] = true;
                                isOutbox = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã chuyển vào Outbox!')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
      // ...rest of your code...
      // ...existing code...
      // ...existing code...
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              children: [
                Text(
                  subject,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                // Phần tag trực quan, cho phép xóa và thêm tag mới
                if (mailsUserData?['tag'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: (mailsUserData!['tag'] as String)
                              .split(',')
                              .map((tag) => tag.trim())
                              .where((tag) => tag.isNotEmpty)
                              .map((tag) => Chip(
                                    label: Text(tag, style: const TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.blueGrey,
                                    deleteIcon: const Icon(Icons.close, color: Colors.white),
                                    onDeleted: () async {
                                      // Xóa tag khỏi danh sách và cập nhật Firestore (bảng mails_users)
                                      final tags = (mailsUserData!['tag'] as String)
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty && e != tag)
                                          .toList();
                                      final newTagString = tags.join(',');
                                      await FirebaseFirestore.instance
                                          .collection('mails_users')
                                          .doc(widget.mailId)
                                          .update({'tag': newTagString});
                                      setState(() {
                                        mailsUserData!['tag'] = newTagString;
                                        if (mailData != null) mailData!['tag'] = newTagString;
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagController,
                                decoration: const InputDecoration(
                                  hintText: 'Thêm tag mới...',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final newTag = _tagController.text.trim();
                                if (newTag.isEmpty) return;
                                final currentTags = (mailsUserData!['tag'] as String)
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                if (currentTags.contains(newTag)) return;
                                currentTags.add(newTag);
                                final newTagString = currentTags.join(',');
                                await FirebaseFirestore.instance
                                    .collection('mails_users')
                                    .doc(widget.mailId)
                                    .update({'tag': newTagString});
                                setState(() {
                                  mailsUserData!['tag'] = newTagString;
                                  if (mailData != null) mailData!['tag'] = newTagString;
                                });
                                _tagController.clear();
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey[400],
                      backgroundImage: senderAvatar != null && senderAvatar != ''
                          ? NetworkImage(senderAvatar)
                          : null,
                      child: (senderAvatar == null || senderAvatar == '')
                          ? Text(
                              senderName.isNotEmpty
                                  ? senderName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(fontSize: 22, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            senderEmail,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedTime,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          if (mailTypeDisplay != null && mailTypeDisplay!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                mailTypeDisplay!,
                                style: const TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isImportant)
                      const Icon(Icons.label_important, color: Colors.red, size: 28),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                // Nút xem bản dịch
                if (transContent != null && transContent!.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.translate, color: Colors.orange),
                      label: Text(
                        showTrans ? 'Ẩn bản dịch' : 'Xem bản dịch',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          showTrans = !showTrans;
                        });
                      },
                    ),
                  ),
                // Hiển thị nội dung bản dịch nếu showTrans = true
                if (showTrans && transContent != null && transContent!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transContent!,
                      style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                quillController != null
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: quill.QuillEditor.basic(
                          configurations: quill.QuillEditorConfigurations(
                            controller: quillController,
                            scrollable: true,
                            autoFocus: false,
                            showCursor: false,
                            expands: false,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      )
                    : SelectableText(
                        styleContent,
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    "File đính kèm:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ...attachments.map((file) => ListTile(
                        leading: Icon(
                          Icons.attach_file,
                          color: widget.darkMode == 0 ? Colors.blue[800] : Colors.blueAccent,
                        ),
                        title: Text(
                          file['name'] ?? '',
                          style: TextStyle(
                            color: widget.darkMode == 0 ? Colors.black : Colors.white,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.download,
                            color: widget.darkMode == 0 ? Colors.green[700] : Colors.greenAccent,
                          ),
                          onPressed: () async {
                            final url = file['url'];
                            if (url != null && url.toString().isNotEmpty) {
                              await launchUrl(Uri.parse(url));
                            }
                          },
                        ),
                        onTap: () async {
                          final url = file['url'];
                          if (url != null && url.toString().isNotEmpty) {
                            await launchUrl(Uri.parse(url));
                          }
                        },
                      )),
                ],
                const SizedBox(height: 32),
                if (mailData?['content'] != null && (mailData?['content'] as String).isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.summarize, color: Colors.blueAccent),
                      label: Text(
                        showSummary ? 'Ẩn tóm tắt' : 'Xem tóm tắt',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        if (showSummary) {
                          setState(() {
                            showSummary = false;
                          });
                          return;
                        }
                        setState(() {
                          loadingSummary = true;
                        });
                        summaryContent = await summarizeWithGemini(mailData?['content'] ?? '');
                        setState(() {
                          loadingSummary = false;
                          showSummary = true;
                        });
                      },
                    ),
                  ),
                if (loadingSummary)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (showSummary && summaryContent != null && summaryContent!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.08),
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      summaryContent!,
                      style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          // 3 nút phía dưới
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.reply_all),
                    label: const Text('Trả lời tất cả'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 99, 131, 146),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // Hiện loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        // 1. Lấy mailType và mailId gốc
                        final mailType = mailsUserData?['mailType'];
                        final mailDocId = mailsUserData?['mailId'];
                        if (mailType == null || mailDocId == null) {
                          Navigator.of(context, rootNavigator: true).pop(); // Đóng loading
                          print('Không có mailType hoặc mailDocId');
                          return;
                        }
                    
                        // 2. Lấy thông tin mail gốc
                        final mailSnap = await FirebaseFirestore.instance
                            .collection('mails')
                            .doc(mailDocId)
                            .get();
                        if (!mailSnap.exists) {
                          Navigator.of(context, rootNavigator: true).pop(); // Đóng loading
                          print('Không tìm thấy mail gốc');
                          return;
                        }
                        final mailOrigin = mailSnap.data();
                        final input = mailOrigin?['input'] ?? '';
                        final cc = mailOrigin?['cc'] ?? '';
                        final bcc = mailOrigin?['bcc'] ?? '';
                        final subject = mailOrigin?['subject'] ?? '';
                        final content = mailOrigin?['content'] ?? '';
                    
                        // Gọi Gemini để lấy gợi ý trả lời
                        final suggestedReply = await suggestReplyWithGemini(subject, content);
                    
                        // 3. Lấy senderId của mail gốc từ bảng mails_users
                        final mailsUsersQuery = await FirebaseFirestore.instance
                            .collection('mails_users')
                            .where('mailId', isEqualTo: mailDocId)
                            .limit(1)
                            .get();
                        String senderEmail = '';
                        String senderPhone = '';
                        if (mailsUsersQuery.docs.isNotEmpty) {
                          final senderId = mailsUsersQuery.docs.first.data()['senderId'];
                          // Lấy email/phone của người gửi
                          final senderSnap = await FirebaseFirestore.instance
                              .collection('users')
                              .where('id', isEqualTo: senderId)
                              .limit(1)
                              .get();
                          if (senderSnap.docs.isNotEmpty) {
                            final senderData = senderSnap.docs.first.data();
                            senderEmail = senderData['email'] ?? '';
                            senderPhone = senderData['phone'] ?? '';
                          }
                        }
                    
                        // 4. Lấy email/phone của user hiện tại
                        String currentUserEmail = '';
                        String currentUserName = '';
                        String currentUserPhone = '';
                        final currentUserSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('id', isEqualTo: widget.currentUserId)
                            .limit(1)
                            .get();
                        if (currentUserSnap.docs.isNotEmpty) {
                          final userData = currentUserSnap.docs.first.data();
                          currentUserName = userData['name'] ?? '';
                          currentUserEmail = userData['email'] ?? '';
                          currentUserPhone = userData['phone'] ?? '';
                        }
                    
                        // Hàm loại bỏ bản thân và người gửi khỏi danh sách
                        String removeSelfAndSender(String emails) {
                          final list = emails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          list.removeWhere((e) =>
                            e == currentUserEmail ||
                            e == currentUserPhone ||
                            e == senderEmail ||
                            e == senderPhone
                          );
                          return list.join(',');
                        }
                    
                        // Chỉ trả lời đúng nhóm theo mailType
                        String to = '', ccField = '', bccField = '';
                        if (mailType == 'to') {
                          to = removeSelfAndSender(input);
                          if (senderEmail.isNotEmpty) {
                            to = to.isEmpty ? senderEmail : '$senderEmail,$to';
                          }
                        } else if (mailType == 'CC') {
                          ccField = removeSelfAndSender(cc);
                          if (senderEmail.isNotEmpty) {
                            ccField = ccField.isEmpty ? senderEmail : '$senderEmail,$ccField';
                          }
                        } else if (mailType == 'BCC') {
                          bccField = removeSelfAndSender(bcc);
                          if (senderEmail.isNotEmpty) {
                            bccField = bccField.isEmpty ? senderEmail : '$senderEmail,$bccField';
                          }
                        }
                    
                        // Đóng loading trước khi chuyển trang
                        Navigator.of(context, rootNavigator: true).pop();
                    
                        // 7. Mở màn hình soạn thư với dữ liệu phản hồi tất cả và gợi ý trả lời
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComposeMailScreen(
                              senderId: widget.currentUserId,
                              senderEmail: null,
                              senderName: currentUserName,
                              key: UniqueKey(),
                            ),
                            settings: RouteSettings(
                              arguments: {
                                'to': to,
                                'cc': ccField,
                                'bcc': bccField,
                                'subject': 'Re: $subject',
                                'previousMailId': widget.mailId,
                                'suggestedReply': suggestedReply, // truyền gợi ý sang
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        Navigator.of(context, rootNavigator: true).pop();
                        print('Lỗi chuyển tiếp: $e');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.reply),
                    label: const Text('Trả lời'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // Hiện loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        
                      String currentUserName = '';
                      String currentUserEmail = '';
                      final currentUserSnap = await FirebaseFirestore.instance
                          .collection('users')
                          .where('id', isEqualTo: widget.currentUserId)
                          .limit(1)
                          .get();
                      if (currentUserSnap.docs.isNotEmpty) {
                        final userData = currentUserSnap.docs.first.data();
                        currentUserName = userData['name'] ?? '';
                        currentUserEmail = userData['email'] ?? '';
    }
                        // 1. Xác định mailType và mailId gốc
                        final mailType = mailsUserData?['mailType'];
                        final mailDocId = mailsUserData?['mailId'];
                        if (mailType == null || mailDocId == null) {
                          Navigator.of(context, rootNavigator: true).pop();
                          print('Không có mailType hoặc mailDocId');
                          return;
                        }

                        // 2. Lấy thông tin mail gốc
                        final mailSnap = await FirebaseFirestore.instance
                            .collection('mails')
                            .doc(mailDocId)
                            .get();
                        final subject = mailSnap.data()?['subject'] ?? '';
                        final content = mailSnap.data()?['content'] ?? '';

                        // Gọi Gemini để lấy gợi ý trả lời
                        final suggestedReply = await suggestReplyWithGemini(subject, content);

                        // 3. Tìm senderId của mail gốc (khác user hiện tại)
                        final mailsUsersQuery = await FirebaseFirestore.instance
                            .collection('mails_users')
                            .where('mailId', isEqualTo: mailDocId)
                            .where('senderId', isNotEqualTo: widget.currentUserId)
                            .limit(1)
                            .get();

                        if (mailsUsersQuery.docs.isEmpty) {
                          Navigator.of(context, rootNavigator: true).pop();
                          print('Không tìm thấy senderId');
                          return;
                        }
                        final senderId = mailsUsersQuery.docs.first.data()['senderId'];

                        // 4. Lấy email người gửi
                        final userSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('id', isEqualTo: senderId)
                            .limit(1)
                            .get();
                        if (userSnap.docs.isEmpty) {
                          Navigator.of(context, rootNavigator: true).pop();
                          print('Không tìm thấy user');
                          return;
                        }
                        final senderEmail = userSnap.docs.first.data()['email'] ?? '';

                        // 5. Chuẩn bị input cho ComposeMailScreen
                        String to = '', cc = '', bcc = '';
                        if (mailType == 'to') {
                          to = senderEmail;
                        } else if (mailType == 'CC') {
                          cc = senderEmail;
                        } else if (mailType == 'BCC') {
                          bcc = senderEmail;
                        }

                        Navigator.of(context, rootNavigator: true).pop();

                        // 6. Mở màn hình soạn thư với dữ liệu phản hồi và gợi ý trả lời
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComposeMailScreen(
                              senderId: widget.currentUserId,
                              senderEmail: null,
                              senderName: currentUserName,
                              key: UniqueKey(),
                            ),
                            settings: RouteSettings(
                              arguments: {
                                'to': to,
                                'cc': cc,
                                'bcc': bcc,
                                'subject': 'Re: $subject',
                                'previousMailId': widget.mailId,
                                'suggestedReply': suggestedReply, // truyền gợi ý sang
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        Navigator.of(context, rootNavigator: true).pop();
                        print('Lỗi chuyển tiếp: $e');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.forward_to_inbox),
                    label: const Text('Chuyển tiếp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // Hiện loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        // 1. Lấy mailId gốc từ mailsUserData
                        final mailDocId = mailsUserData?['mailId'];
                        if (mailDocId == null) {
                          Navigator.of(context, rootNavigator: true).pop(); // Đóng loading
                          print('Không có mailId');
                          return;
                        }
                    
                        // 2. Lấy subject và styleContent từ bảng mails
                        final mailSnap = await FirebaseFirestore.instance
                            .collection('mails')
                            .doc(mailDocId)
                            .get();
                        if (!mailSnap.exists) {
                          Navigator.of(context, rootNavigator: true).pop(); // Đóng loading
                          print('Không tìm thấy mail gốc');
                          return;
                        }
                        final mailOrigin = mailSnap.data();
                        final subject = mailOrigin?['subject'] ?? '';
                        final styleContent = mailOrigin?['styleContent'] ?? '';
                    
                        // 3. Lấy danh sách file đính kèm
                        final attachSnap = await FirebaseFirestore.instance
                            .collection('mail_attachments')
                            .where('mailId', isEqualTo: mailDocId)
                            .get();
                        final List<Map<String, dynamic>> attachments = attachSnap.docs
                            .map((doc) => doc.data())
                            .toList();
                    
                        // Đóng loading trước khi chuyển trang
                        Navigator.of(context, rootNavigator: true).pop();
                    
                        // 4. Mở màn hình soạn thư với subject, styleContent và file đính kèm
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComposeMailScreen(
                              senderId: widget.currentUserId,
                              senderEmail: null,
                              senderName: null,
                              key: UniqueKey(),
                            ),
                            settings: RouteSettings(
                              arguments: {
                                'subject': 'Fwd: $subject',
                                'styleContent': styleContent,
                                'attachments': attachments, // truyền file đính kèm
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        Navigator.of(context, rootNavigator: true).pop();
                        print('Lỗi chuyển tiếp: $e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}