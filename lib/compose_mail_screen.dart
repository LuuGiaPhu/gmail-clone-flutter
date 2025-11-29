import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/mail_model.dart';
import 'models/MailUserRelation_model.dart'; // import model quan hệ
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'models/mail_attachment_model.dart';
import 'dart:io' show File; // Thêm dòng này
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
class ComposeMailScreen extends StatefulWidget {
  final String? senderId;
  final String? senderName;
  final String? senderPhone;
  final String? senderEmail;
  const ComposeMailScreen({
    this.senderId,
    this.senderName,
    this.senderPhone,
    this.senderEmail,
    super.key,
  });

  @override
  State<ComposeMailScreen> createState() => _ComposeMailScreenState();
}

class _ComposeMailScreenState extends State<ComposeMailScreen> {
  final TextEditingController toController = TextEditingController();
  final TextEditingController ccController = TextEditingController();
  final TextEditingController bccController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  bool important = false;
  bool starred = false;
  bool trash = false;
  DateTime? scheduled;
  List<MailAttachmentModel> mailAttachments = [];
  bool _isSending = false; // Thêm biến trạng thái
  double _progress = 0; // Thêm biến này
  final quill.QuillController quillController = quill.QuillController.basic();
  String? _previousMailId; // Thêm biến này
    // ...existing code...
  bool _lastBold = false;
  bool _lastItalic = false;
  bool _lastUnderline = false; // Thêm dòng này
  late FocusNode _editorFocusNode;
  bool _showSendEffect = false;
  final List<String> toTags = [];
  final List<String> ccTags = [];
  final List<String> bccTags = [];
  @override
    @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    quillController.addListener(_handleQuillChange);
    _editorFocusNode.addListener(_handleFocusChange);
  
    Future.microtask(() async {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['suggestedReply'] != null && args['suggestedReply'].toString().isNotEmpty) {
          quillController.document.insert(0, args['suggestedReply'] + '\n');
        }
        // Xử lý To
        if (args['to'] != null) {
          toController.text = '';
          toTags.clear();
          toTags.addAll(_parseEmailsOrPhones(args['to']));
        }
        // Xử lý CC
        if (args['cc'] != null) {
          ccController.text = '';
          ccTags.clear();
          ccTags.addAll(_parseEmailsOrPhones(args['cc']));
        }
        // Xử lý BCC
        if (args['bcc'] != null) {
          bccController.text = '';
          bccTags.clear();
          bccTags.addAll(_parseEmailsOrPhones(args['bcc']));
        }
        if (args['subject'] != null) subjectController.text = args['subject'];
        _previousMailId = args['previousMailId']?.toString();
  
        // Nhận lại scheduled và createdAt
        if (args['scheduled'] != null) {
          if (args['scheduled'] is Timestamp) {
            scheduled = (args['scheduled'] as Timestamp).toDate();
          } else if (args['scheduled'] is String) {
            try {
              scheduled = DateTime.parse(args['scheduled']);
            } catch (_) {}
          } else if (args['scheduled'] is DateTime) {
            scheduled = args['scheduled'];
          }
        }
        if (args['createdAt'] != null) {
          // Nếu cần dùng createdAt thì xử lý ở đây
        }
        // Giữ định dạng khi chuyển tiếp
        if (args['styleContent'] != null && args['styleContent'].toString().isNotEmpty) {
          try {
            final doc = quill.Document.fromJson(jsonDecode(args['styleContent']));
            quillController.document = doc;
          } catch (e) {
            // Nếu lỗi thì giữ nguyên quillController mặc định
          }
        }
         // Load file đính kèm khi chuyển tiếp (nếu có)
        if (args['attachments'] != null && args['attachments'] is List) {
          setState(() {
            mailAttachments = (args['attachments'] as List)
                .map((e) {
                  final old = MailAttachmentModel.fromMap(Map<String, dynamic>.from(e));
                  // Tạo id mới, giữ nguyên url, name, uploadedAt
                  return MailAttachmentModel(
                    id: "${DateTime.now().microsecondsSinceEpoch}_${old.name}",
                    mailId: '', // sẽ gán đúng mailId khi gửi
                    name: old.name,
                    url: old.url,
                    uploadedAt: old.uploadedAt,
                  );
                })
                .toList();
          });
        }
        // Load file đính kèm nếu là chỉnh sửa nháp
        if (_previousMailId != null && _previousMailId!.isNotEmpty) {
          final attSnap = await FirebaseFirestore.instance
              .collection('mail_attachments')
              .where('mailId', isEqualTo: _previousMailId)
              .get();
          if (!mounted) return;
          setState(() {
            mailAttachments = attSnap.docs
                .map((doc) => MailAttachmentModel.fromMap(doc.data()))
                .toList();
          });
        }
      }
    });
  
    toController.addListener(_handleToInput);
    ccController.addListener(_handleCcInput);
    bccController.addListener(_handleBccInput);
  }
  void _handleToInput() {
    final text = toController.text;
    if (text.endsWith(',') || text.endsWith(' ') || text.endsWith('\n')) {
      final value = text.substring(0, text.length - 1).trim();
      if (value.isNotEmpty) {
        setState(() {
          toTags.add(value);
        });
      }
      toController.clear();
    }
  }
  void _handleCcInput() {
  final text = ccController.text;
  if (text.endsWith(',') || text.endsWith(' ') || text.endsWith('\n')) {
    final value = text.substring(0, text.length - 1).trim();
    if (value.isNotEmpty) {
      setState(() {
        ccTags.add(value);
      });
    }
    ccController.clear();
  }
}

void _handleBccInput() {
  final text = bccController.text;
  if (text.endsWith(',') || text.endsWith(' ') || text.endsWith('\n')) {
    final value = text.substring(0, text.length - 1).trim();
    if (value.isNotEmpty) {
      setState(() {
        bccTags.add(value);
      });
    }
    bccController.clear();
  }
}
  void _handleQuillChange() {
    final attrs = quillController.getSelectionStyle().attributes;
    _lastBold = attrs.containsKey('bold');
    _lastItalic = attrs.containsKey('italic');
    _lastUnderline = attrs.containsKey('underline'); // Thêm dòng này
  }
  void _handleFocusChange() {
    if (_editorFocusNode.hasFocus) {
      // Chỉ áp dụng lại định dạng nếu selection đang rỗng (không chọn đoạn nào)
      final selection = quillController.selection;
      if (selection.isCollapsed) {
        Future.delayed(const Duration(milliseconds: 10), () {
          if (_lastBold) {
            quillController.formatSelection(quill.Attribute.bold);
          }
          if (_lastItalic) {
            quillController.formatSelection(quill.Attribute.italic);
          }
          if (_lastUnderline) {
            quillController.formatSelection(quill.Attribute.underline);
          }
        });
      }
    }
  }
  @override
  void dispose() {
    ccController.removeListener(_handleCcInput);
    bccController.removeListener(_handleBccInput);
    toController.removeListener(_handleToInput);
    quillController.removeListener(_handleQuillChange);
    _editorFocusNode.removeListener(_handleFocusChange); // Thêm dòng này
    _editorFocusNode.dispose();
    super.dispose();
  }
  // Khi gửi mail, truyền dữ liệu như cũ:
  List<String> _getToList() {
    final tags = List<String>.from(toTags);
    if (toController.text.trim().isNotEmpty) {
      tags.addAll(_parseEmailsOrPhones(toController.text));
    }
    // Loại bỏ trùng lặp và khoảng trắng
    return tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
  }
  
  List<String> _getCcList() {
    final tags = List<String>.from(ccTags);
    if (ccController.text.trim().isNotEmpty) {
      tags.addAll(_parseEmailsOrPhones(ccController.text));
    }
    return tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
  }
  
  List<String> _getBccList() {
    final tags = List<String>.from(bccTags);
    if (bccController.text.trim().isNotEmpty) {
      tags.addAll(_parseEmailsOrPhones(bccController.text));
    }
    return tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
  }
  List<String> _parseEmailsOrPhones(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _extractEmail(String value) {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(value) ? value : '';
  }

  String _extractPhone(String value) {
    final phoneRegex = RegExp(r'^\d{4,15}$');
    return phoneRegex.hasMatch(value) ? value : '';
  }
    Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      final fileName = file.name;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('mail_attachments/${DateTime.now().millisecondsSinceEpoch}_$fileName');
  
      String downloadUrl = '';
      final progressNotifier = ValueNotifier<double>(0);
  
      // Show dialog trước
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: SizedBox(
            height: 80,
            child: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, value, _) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 16),
                  Text('Đang tải lên... ${(value * 100).toInt()}%'),
                ],
              ),
            ),
          ),
        ),
      );
  
      try {
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes != null) {
            final uploadTask = storageRef.putData(bytes);
            uploadTask.snapshotEvents.listen((event) {
              final progress = event.bytesTransferred / (event.totalBytes == 0 ? 1 : event.totalBytes);
              progressNotifier.value = progress;
            });
            await uploadTask;
            downloadUrl = await storageRef.getDownloadURL();
          }
        } else {
          if (file.path != null) {
            final uploadTask = storageRef.putFile(File(file.path!));
            uploadTask.snapshotEvents.listen((event) {
              final progress = event.bytesTransferred / (event.totalBytes == 0 ? 1 : event.totalBytes);
              progressNotifier.value = progress;
            });
            await uploadTask;
            downloadUrl = await storageRef.getDownloadURL();
          }
        }
  
        if (downloadUrl.isNotEmpty) {
          final attachment = MailAttachmentModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            mailId: '',
            name: fileName,
            url: downloadUrl,
            uploadedAt: DateTime.now(),
          );
          if (mounted) {
            setState(() {
              mailAttachments.add(attachment);
            });
          }
        }
      } finally {
        progressNotifier.dispose();
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
  // Hàm gọi Gemini API
  Future<String> checkSpamWithGemini(String subject, String content) async {
    const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
    final prompt = '''
  Trả lời ngắn gọn, dựa vào chủ đề và nội dung trong đây có phải là mail spam hay không, lưu ý trả lời bằng tiếng Việt là chỉ đưa ra câu trả lời 1 chữ ví dụ output là "có" hoặc "không", chủ đề: $subject, nội dung của mail: $content
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
  
      print('Gemini raw response: ${response.body}');
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        print('Gemini extracted text: $text');
        final answer = text.trim().toLowerCase().startsWith('có') ? 'có' : 'không';
        return answer;
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return 'không';
      }
    } catch (e) {
      print('Gemini Exception: $e');
      return 'không';
    }
  }
  // Thêm hàm dịch content sang tiếng Việt bằng Gemini
  Future<String> translateContentWithGemini(String content) async {
    const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
    final prompt = 'Hãy dịch đoạn văn sau đây sang tiếng Việt , lưu ý chỉ dịch nội dung không ghi gì khác: $content';
  
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
    Future<String> checkCategoryWithGemini(String subject, String content) async {
    const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
    final prompt = '''
  chỉ trả lời output 1 từ (ouput ví dụ social ) , dựa vào tiêu đề và nội dung của mail hãy trả lời xem mail thuộc 1 trong danh mục nào hay không thuộc tất cả danh mục trên nếu mail có subject và content không thuộc trong 4 danh mục trên thì output chỉ ghi là không , gồm các danh mục  social , promotions,updates,forums ; mail có tiêu đề là $subject và mail có nội dung là $content
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
      print('Gemini raw response (category): ${response.body}'); // In ra phản hồi của Gemini
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        print('Gemini extracted category: $text'); // In ra kết quả trích xuất
        return text.trim().toLowerCase();
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return 'không';
      }
    } catch (e) {
      print('Gemini Exception: $e');
      return 'không';
    }
  }
  // static Future<String> suggestReplyWithGemini(String subject, String content) async {
  //   const apiKey = 'AIzaSyAroQ0Qd50AlPUEkxr8DRqDdcq7Eb7Gx0k';
  //   final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
  //   final prompt = '''
  // Hãy gợi ý nội dung trả lời phản hồi cho thư vừa gởi đến, biết rằng thư vừa gởi đến có tiêu đề là "$subject"; và nội dung của thư vừa gửi đến là "$content".
  // Chỉ trả về nội dung gợi ý, không giải thích gì thêm.
  // ''';

  //   final body = jsonEncode({
  //     "contents": [
  //       {
  //         "parts": [
  //           {"text": prompt}
  //         ]
  //       }
  //     ]
  //   });

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json"},
  //       body: body,
  //     );
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
  //       return text.trim();
  //     } else {
  //       print('Gemini API error: ${response.statusCode} - ${response.body}');
  //       return '';
  //     }
  //   } catch (e) {
  //     print('Gemini Exception: $e');
  //     return '';
  //   }
  // }
    Future<void> _sendMail() async {
    setState(() {
      _isSending = true;
      _progress = 0;
    });
  
    late void Function(void Function()) setStateDialog;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) {
          setStateDialog = setStateSB;
          return AlertDialog(
            content: SizedBox(
              height: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 16),
                  Text('Đang gửi mail... ${(_progress * 100).toInt()}%'),
                ],
              ),
            ),
          );
        },
      ),
    );
  
    try {
      // 1. Lấy thông tin người gửi
      String senderEmail = '';
      String senderPhone = '';
      String senderAvatar = '';
      if (widget.senderId != null && widget.senderId!.isNotEmpty) {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: widget.senderId)
            .limit(1)
            .get();
        if (userSnapshot.docs.isNotEmpty) {
          final userData = userSnapshot.docs.first.data();
          senderEmail = userData['email'] ?? '';
          senderPhone = userData['phone'] ?? '';
          senderAvatar = userData['avatar'] ?? '';
        }
      }
      setStateDialog(() => _progress = 0.1);
  
      // 2. Xử lý danh sách người nhận
      final List<String> toList = _getToList();
      final List<String> ccList = _getCcList();
      final List<String> bccList = _getBccList();
  
      final Set<String> toUserKeys = {};
      final Set<String> ccUserKeys = {};
      final Set<String> bccUserKeys = {};
  
      Future<String> getUserKey(String input) async {
        final email = _extractEmail(input);
        final phone = _extractPhone(input);
        if (email.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email.toLowerCase())
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return snap.docs.first.data()['id']?.toString() ?? input;
          }
          return input;
        } else if (phone.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return snap.docs.first.data()['id']?.toString() ?? input;
          }
          return input;
        }
        return input;
      }
  
      Future<List<String>> filterPriority(
          List<String> mainList, Set<String> higherKeys) async {
        List<String> result = [];
        for (final item in mainList) {
          final key = await getUserKey(item);
          if (!higherKeys.contains(key)) {
            result.add(item);
            higherKeys.add(key);
          }
        }
        return result;
      }
  
      final List<String> filteredToList = [];
      for (final item in toList) {
        final key = await getUserKey(item);
        if (!toUserKeys.contains(key)) {
          filteredToList.add(item);
          toUserKeys.add(key);
        }
      }
      final List<String> filteredCcList =
          await filterPriority(ccList, {...toUserKeys});
      ccUserKeys.addAll(toUserKeys);
      for (final item in filteredCcList) {
        final key = await getUserKey(item);
        ccUserKeys.add(key);
      }
      final List<String> filteredBccList =
          await filterPriority(bccList, {...toUserKeys, ...ccUserKeys});
  
      toController.text = filteredToList.join(',');
      ccController.text = filteredCcList.join(',');
      bccController.text = filteredBccList.join(',');
  
      setStateDialog(() => _progress = 0.18);
  
      // 3. Xử lý danh sách người nhận chi tiết
      final List<Map<String, String>> receivers = [];
      for (final item in filteredToList) {
        if (_extractEmail(item).isNotEmpty) {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: _extractEmail(item).toLowerCase())
              .limit(1)
              .get();
          if (userSnapshot.docs.isNotEmpty) {
            final userData = userSnapshot.docs.first.data();
            final phone = (userData['phone'] != null && userData['phone'].toString().isNotEmpty)
                ? userData['phone']
                : 'null';
            final id = userData['id']?.toString() ?? 'null';
            receivers.add({
              'input': item,
              'email': item,
              'phone': phone,
              'name': userData['name'] ?? 'null',
              'id': id,
            });
          } else {
            receivers.add({
              'input': item,
              'email': item,
              'phone': 'null',
              'name': 'null',
              'id': 'null',
            });
          }
        } else if (_extractPhone(item).isNotEmpty) {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: item)
              .limit(1)
              .get();
          if (userSnapshot.docs.isNotEmpty) {
            final userData = userSnapshot.docs.first.data();
            final email = (userData['email'] != null && userData['email'].toString().isNotEmpty)
                ? userData['email']
                : 'null';
            final id = userData['id']?.toString() ?? 'null';
            receivers.add({
              'input': item,
              'email': email,
              'phone': item,
              'name': userData['name'] ?? 'null',
              'id': id,
            });
          } else {
            receivers.add({
              'input': item,
              'email': 'null',
              'phone': item,
              'name': 'null',
              'id': 'null',
            });
          }
        }
      }
  
      setStateDialog(() => _progress = 0.23);
  
      List<String> receiverEmails = [];
      List<String> receiverPhones = [];
      List<String> receiverNames = [];
      List<String> receiverIds = [];
      List<String> inputs = [];
  
      for (var entry in receivers) {
        if (_extractEmail(entry['input'] ?? '') != '') {
          inputs.add(entry['email'] ?? 'null');
        } else if (_extractPhone(entry['input'] ?? '') != '') {
          inputs.add(entry['phone'] ?? 'null');
        }
        receiverEmails.add(entry['email'] ?? 'null');
        receiverPhones.add(entry['phone'] ?? 'null');
        receiverNames.add(entry['name'] ?? 'null');
        receiverIds.add(entry['id'] ?? 'null');
      }
  
      toController.text = inputs.join(',');
  
      setStateDialog(() => _progress = 0.28);
  
      // 4. Chuẩn bị nội dung mail
      final DateTime createdAt = scheduled ?? DateTime.now();
      final subject = subjectController.text;
      final content = quillController.document.toPlainText();
      final styleContent = jsonEncode(quillController.document.toDelta().toJson());
  
      // 5. Kiểm tra spam và dịch nội dung
      final geminiResult = await checkSpamWithGemini(subject, content);
      setStateDialog(() => _progress = 0.35);
      final isSpam = geminiResult == 'có';
      final trans = await translateContentWithGemini(content);
      setStateDialog(() => _progress = 0.42);
  
      // 5.1. Kiểm tra danh mục mail
      final category = await checkCategoryWithGemini(subject, content);
      bool isSocial = false;
      bool isPromotions = false;
      bool isUpdates = false;
      bool isForums = false;
      if (category == 'social') isSocial = true;
      if (category == 'promotions') isPromotions = true;
      if (category == 'updates') isUpdates = true;
      if (category == 'forums') isForums = true;
  
      // 6. Gửi mail chính
      final mailId = (_previousMailId != null && _previousMailId!.isNotEmpty)
          ? _previousMailId!
          : DateTime.now().millisecondsSinceEpoch.toString();
      final mailDoc = FirebaseFirestore.instance.collection('mails').doc(mailId);
      await mailDoc.set(
        MailModel(
          id: mailId,
          senderId: widget.senderId ?? '',
          senderName: widget.senderName ?? '',
          senderPhone: senderPhone,
          senderEmail: senderEmail,
          senderAvatar: senderAvatar,
          input: toController.text,
          receiverId: receiverIds.join(','),
          receiverName: receiverNames.join(','),
          receiverPhone: receiverPhones.join(','),
          receiverEmail: receiverEmails.join(','),
          subject: subjectController.text,
          content: content,
          styleContent: styleContent,
          cc: ccController.text,
          bcc: bccController.text,
          scheduled: scheduled,
          tag: tagController.text,
          createdAt: createdAt,
          trans: trans,
          isDrafts: false, // Đánh dấu không còn là nháp
        ).toMap(),
      );
      setStateDialog(() => _progress = 0.55);
  
      // 7. Gửi file đính kèm
      for (int i = 0; i < mailAttachments.length; i++) {
        final attachment = mailAttachments[i];
        final attDoc = FirebaseFirestore.instance.collection('mail_attachments').doc(attachment.id);
        await attDoc.set(attachment.copyWith(mailId: mailId).toMap());
        setStateDialog(() => _progress = 0.55 + 0.1 * (i + 1) / mailAttachments.length);
      }
  
      setStateDialog(() => _progress = 0.65);
  
      // 8. Lấy lại tag từ bảng mails để gán cho mails_users
      String tagValue = '';
      try {
        final mailDocSnap = await FirebaseFirestore.instance.collection('mails').doc(mailId).get();
        if (mailDocSnap.exists) {
          tagValue = mailDocSnap.data()?['tag'] ?? '';
        }
      } catch (_) {}
  
      String? replyToMailId = _previousMailId;
  
      Future<void> createRelations(List<String> inputList, String mailType) async {
        for (final item in inputList) {
          if (_extractEmail(item).isNotEmpty) {
            final userSnap = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: item.toLowerCase())
                .limit(1)
                .get();
            if (userSnap.docs.isNotEmpty) {
              final receiverId = userSnap.docs.first.data()['id']?.toString() ?? '';
              final relationId = DateTime.now().microsecondsSinceEpoch.toString() + receiverId;
              await FirebaseFirestore.instance
                  .collection('mails_users')
                  .doc(relationId)
                  .set(
                    MailUserRelationModel(
                      id: relationId,
                      mailId: mailId,
                      senderId: widget.senderId ?? '',
                      receiverId: receiverId,
                      mailType: mailType,
                      important: important,
                      starred: starred,
                      trash: trash,
                      isSpam: isSpam,
                      createdAt: createdAt,
                      isRead: false,
                      previousMailId: replyToMailId,
                      tag: tagValue,
                      isSocial: isSocial,
                      isPromotions: isPromotions,
                      isUpdates: isUpdates,
                      isForums: isForums,
                      isOutbox: false,
                      isSnoozed: false,
                      snoozedTime: null,
                    ).toMap(),
                  );
            }
          } else if (_extractPhone(item).isNotEmpty) {
            final userSnap = await FirebaseFirestore.instance
                .collection('users')
                .where('phone', isEqualTo: item)
                .limit(1)
                .get();
            if (userSnap.docs.isNotEmpty) {
              final receiverId = userSnap.docs.first.data()['id']?.toString() ?? '';
              final relationId = DateTime.now().microsecondsSinceEpoch.toString() + receiverId;
              await FirebaseFirestore.instance
                  .collection('mails_users')
                  .doc(relationId)
                  .set(
                    MailUserRelationModel(
                      id: relationId,
                      mailId: mailId,
                      senderId: widget.senderId ?? '',
                      receiverId: receiverId,
                      mailType: mailType,
                      important: important,
                      starred: starred,
                      trash: trash,
                      isSpam: isSpam,
                      createdAt: createdAt,
                      previousMailId: replyToMailId,
                      tag: tagValue,
                      isSocial: isSocial,
                      isPromotions: isPromotions,
                      isUpdates: isUpdates,
                      isForums: isForums,
                      isOutbox: false,
                      isSnoozed: false,
                      snoozedTime: null,
                    ).toMap(),
                  );
            }
          }
        }
      }
  
      await createRelations(filteredToList, "to");
      setStateDialog(() => _progress = 0.7);
      await createRelations(filteredCcList, "CC");
      setStateDialog(() => _progress = 0.75);
      await createRelations(filteredBccList, "BCC");
      setStateDialog(() => _progress = 0.8);
  
      // 9. Đánh dấu spam nếu có
      if (isSpam) {
        final mailsUsersQuery = await FirebaseFirestore.instance
            .collection('mails_users')
            .where('mailId', isEqualTo: mailId)
            .get();
        for (final doc in mailsUsersQuery.docs) {
          await doc.reference.update({'is_spam': true});
        }
      }
      setStateDialog(() => _progress = 0.85);
  
      // 10. Cập nhật nháp nếu có
      await Future.delayed(const Duration(milliseconds: 1000));
      if (_previousMailId != null && _previousMailId!.isNotEmpty) {
        final prevDoc = FirebaseFirestore.instance.collection('mails').doc(_previousMailId);
        final prevSnap = await prevDoc.get();
        if (prevSnap.exists) {
          await prevDoc.update({'is_drafts': false});
        }
      }
      setStateDialog(() => _progress = 0.9);
  
      // 11. Lấy lại dữ liệu mail vừa gửi
      final sentMailSnap = await FirebaseFirestore.instance
          .collection('mails')
          .doc(mailId)
          .get();
      final sentMailData = sentMailSnap.data();
  
      // 12. Gửi auto-reply nếu có
      final allReceivers = <String>{
        ...filteredToList,
        ...filteredCcList,
        ...filteredBccList,
      };
  
      int autoReplyCount = 0;
      for (final receiver in allReceivers) {
        String email = _extractEmail(receiver);
        String phone = _extractPhone(receiver);
        QuerySnapshot userSnap;
        if (email.isNotEmpty) {
          userSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email.toLowerCase())
              .limit(1)
              .get();
        } else if (phone.isNotEmpty) {
          userSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();
        } else {
          continue;
        }
        if (userSnap.docs.isEmpty) continue;
        final userData = userSnap.docs.first.data() as Map<String, dynamic>?;
        final isAutoReply = userData?['isAutoReply'] == true;
        final messageAutoReply = userData?['messageAutoReply'] ?? '';
        if (!isAutoReply || messageAutoReply == null || messageAutoReply.toString().isEmpty) continue;
  
        // Chặn vòng lặp auto-reply
        if (sentMailData?['subject'] != null) {
          final subject = sentMailData?['subject'].toString();
          if (subject != null && subject.startsWith('Re_Auto:')) {
            final prevMailId = sentMailData?['previousMailId'];
            if (prevMailId != null && prevMailId.toString().isNotEmpty) {
              final prevMailSnap = await FirebaseFirestore.instance
                  .collection('mails')
                  .doc(prevMailId)
                  .get();
              if (prevMailSnap.exists) {
                final prevMailData = prevMailSnap.data();
                if (prevMailData?['subject'] != null) {
                  final prevSubject = prevMailData?['subject'].toString();
                  if (prevSubject != null && prevSubject.startsWith('Re_Auto:')) {
                    continue;
                  }
                }
              }
            }
          }
        }
  
        final originalSenderId = sentMailData?['senderId'];
        if (originalSenderId == null) continue;
  
        final senderSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: originalSenderId)
            .limit(1)
            .get();
        if (senderSnap.docs.isEmpty) continue;
        final senderData = senderSnap.docs.first.data();
  
        final String styleContentReply = jsonEncode([
          {"insert": "$messageAutoReply\n"}
        ]);
        final String transReply = await translateContentWithGemini(messageAutoReply);
  
        // --- LẤY scheduled từ mail gửi để ghi vào mail phản hồi ---
        dynamic scheduledReply = sentMailData?['scheduled'];
        if (scheduledReply is Timestamp) {
          scheduledReply = scheduledReply.toDate().toIso8601String();
        } else if (scheduledReply is DateTime) {
          scheduledReply = scheduledReply.toIso8601String();
        } else if (scheduledReply is String && scheduledReply.isNotEmpty) {
          // giữ nguyên
        } else {
          scheduledReply = null;
        }
        // LẤY createdAt từ mail gửi để ghi vào mail phản hồi
        dynamic createdAtReply = sentMailData?['createdAt'];
        if (createdAtReply is Timestamp) {
          createdAtReply = createdAtReply.toDate().toIso8601String();
        } else if (createdAtReply is DateTime) {
          createdAtReply = createdAtReply.toIso8601String();
        } else if (createdAtReply is String && createdAtReply.isNotEmpty) {
          // giữ nguyên
        } else {
          createdAtReply = DateTime.now().toIso8601String();
        }
  
        final autoReplyMailId = DateTime.now().millisecondsSinceEpoch.toString();
        await FirebaseFirestore.instance.collection('mails').doc(autoReplyMailId).set({
          'id': autoReplyMailId,
          'senderId': userData?['id'] ?? '',
          'senderName': userData?['name'] ?? '',
          'senderPhone': userData?['phone'] ?? '',
          'senderEmail': userData?['email'] ?? '',
          'senderAvatar': userData?['avatar'] ?? '',
          'input': senderData['email'] ?? senderData['phone'] ?? '',
          'receiverId': senderData['id'] ?? '',
          'receiverName': senderData['name'] ?? '',
          'receiverPhone': senderData['phone'] ?? '',
          'receiverEmail': senderData['email'] ?? '',
          'subject': 'Re_Auto: ${sentMailData?['subject'] ?? ''}',
          'content': messageAutoReply,
          'styleContent': styleContentReply,
          'cc': '',
          'bcc': '',
          'scheduled': scheduledReply,
          'tag': '',
          'createdAt': createdAtReply,
          'trans': transReply,
          // Bổ sung các trường mặc định còn thiếu:
          'is_social': false,
          'is_promotions': false,
          'is_updates': false,
          'is_forums': false,
          'is_outbox': false,
          'is_snoozed': false,
          'snoozed_time': null,
          'important': false,
          'starred': false,
          'trash': false,
          'is_spam': false,
          'is_read': false,
        });
  
        final relationId = DateTime.now().microsecondsSinceEpoch.toString() + (senderData['id'] ?? '');
        await FirebaseFirestore.instance.collection('mails_users').doc(relationId).set({
          'id': relationId,
          'mailId': autoReplyMailId,
          'senderId': userData?['id'] ?? '',
          'receiverId': senderData['id'] ?? '',
          'mailType': 'to',
          'important': false,
          'starred': false,
          'trash': false,
          'is_spam': false,
          'is_read': false,
          'createdAt': createdAtReply,
          'previousMailId': mailId,
          'tag': '',
          'is_social': false,
          'is_promotions': false,
          'is_updates': false,
          'is_forums': false,
          'is_outbox': false,
          'is_snoozed': false,
          'snoozed_time': null,
        });
  
        autoReplyCount++;
        setStateDialog(() => _progress = 0.9 + 0.1 * autoReplyCount / allReceivers.length);
      }
  
      setStateDialog(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 400));
  
      // Hiển thị hiệu ứng gửi thành công
      if (mounted) {
        Navigator.of(context).pop(true); // pop màn hình soạn thư
        setState(() => _showSendEffect = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _showSendEffect = false);
      }
    } finally {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        setState(() => _isSending = false);
      }
    }
  }
    // Thay đổi hàm _saveDraft:
       
    // ...existing code...
    Future<void> _saveDraft({bool showSnackBar = true}) async {
    String senderEmail = '';
    String senderPhone = '';
    String senderAvatar = '';
    if (widget.senderId != null && widget.senderId!.isNotEmpty) {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: widget.senderId)
          .limit(1)
          .get();
      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data();
        senderEmail = userData['email'] ?? '';
        senderPhone = userData['phone'] ?? '';
        senderAvatar = userData['avatar'] ?? '';
      }
    }
    final DateTime createdAt = scheduled ?? DateTime.now();
    final styleContent = jsonEncode(quillController.document.toDelta().toJson());
  
    // Lấy đúng dữ liệu từ tag + controller
    final toValue = _getToList().join(',');
    final ccValue = _getCcList().join(',');
    final bccValue = _getBccList().join(',');
  
    String mailId;
    if (_previousMailId != null && _previousMailId!.isNotEmpty) {
      // Đang chỉnh sửa bản nháp: dùng lại mailId cũ
      mailId = _previousMailId!;
      await FirebaseFirestore.instance.collection('mails').doc(mailId).set(
        MailModel(
          id: mailId,
          senderId: widget.senderId ?? '',
          senderName: widget.senderName ?? '',
          senderPhone: senderPhone,
          senderEmail: senderEmail,
          senderAvatar: senderAvatar,
          input: toValue,
          receiverId: '',
          receiverName: '',
          receiverPhone: '',
          receiverEmail: '',
          subject: subjectController.text,
          content: quillController.document.toPlainText(),
          styleContent: styleContent,
          cc: ccValue,
          bcc: bccValue,
          scheduled: scheduled,
          tag: tagController.text,
          createdAt: createdAt,
          trans: null,
          isDrafts: true,
        ).toMap(),
      );
    } else {
      // Soạn mới: tạo bản nháp mới
      mailId = DateTime.now().millisecondsSinceEpoch.toString();
      await FirebaseFirestore.instance.collection('mails').doc(mailId).set(
        MailModel(
          id: mailId,
          senderId: widget.senderId ?? '',
          senderName: widget.senderName ?? '',
          senderPhone: senderPhone,
          senderEmail: senderEmail,
          senderAvatar: senderAvatar,
          input: toValue,
          receiverId: '',
          receiverName: '',
          receiverPhone: '',
          receiverEmail: '',
          subject: subjectController.text,
          content: quillController.document.toPlainText(),
          styleContent: styleContent,
          cc: ccValue,
          bcc: bccValue,
          scheduled: scheduled,
          tag: tagController.text,
          createdAt: createdAt,
          trans: null,
          isDrafts: true,
        ).toMap(),
      );
      _previousMailId = mailId; // Lưu lại để lần sau sửa tiếp
    }
  
    // Lưu file đính kèm cho bản nháp (luôn gắn đúng mailId)
    for (final attachment in mailAttachments) {
      final attDoc = FirebaseFirestore.instance.collection('mail_attachments').doc(attachment.id);
      await attDoc.set(attachment.copyWith(mailId: mailId).toMap());
    }
  
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu bản nháp!')),
      );
    }
  }
  // Hàm xóa bản nháp
  Future<void> _deleteDraft() async {
    if (_previousMailId == null || _previousMailId!.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản nháp?'),
        content: const Text('Bạn có chắc muốn xóa bản nháp này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm != true) return;

    // Xóa mail nháp
    await FirebaseFirestore.instance.collection('mails').doc(_previousMailId).delete();
    // Xóa file đính kèm liên quan (nếu có)
    final attSnap = await FirebaseFirestore.instance
        .collection('mail_attachments')
        .where('mailId', isEqualTo: _previousMailId)
        .get();
    for (var doc in attSnap.docs) {
      await doc.reference.delete();
    }
    if (mounted) {
      Navigator.of(context).pop(true); // Trả về true để reload danh sách nháp
    }
  }

  // ...existing code...
  @override
  Widget build(BuildContext context) {
    if (_showSendEffect) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.7),
        body: Center(
          child: Lottie.asset(
            'assets/send.json',
            width: 220,
            height: 220,
            repeat: false,
          ),
        ),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        await _saveDraft(showSnackBar: true); // Không hiện SnackBar khi thoát
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Soạn Email'),
          actions: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickAndUploadFile,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Lưu bản nháp',
              onPressed: _saveDraft,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMail,
            ),
            if (_previousMailId != null && _previousMailId!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Xóa bản nháp',
                onPressed: _deleteDraft,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đến (Email hoặc SĐT, cách nhau bởi dấu phẩy)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...toTags.map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() {
                                toTags.remove(tag);
                              });
                            },
                          )),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: toController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Nhập email/SĐT...',
                          ),
                          onSubmitted: (value) {
                            final v = value.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                toTags.add(v);
                              });
                              toController.clear();
                            }
                          },
                          onEditingComplete: () {
                            final v = toController.text.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                toTags.add(v);
                              });
                              toController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CC (Email hoặc SĐT, cách nhau bởi dấu phẩy)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...ccTags.map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() {
                                ccTags.remove(tag);
                              });
                            },
                          )),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: ccController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Nhập email/SĐT...',
                          ),
                          onSubmitted: (value) {
                            final v = value.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                ccTags.add(v);
                              });
                              ccController.clear();
                            }
                          },
                          onEditingComplete: () {
                            final v = ccController.text.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                ccTags.add(v);
                              });
                              ccController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
           Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BCC (Email hoặc SĐT, cách nhau bởi dấu phẩy)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...bccTags.map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () {
                            setState(() {
                              bccTags.remove(tag);
                            });
                          },
                        )),
                    SizedBox(
                      width: double.infinity,
                      child: TextField(
                        controller: bccController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Nhập email/SĐT...',
                        ),
                        onSubmitted: (value) {
                          final v = value.trim();
                          if (v.isNotEmpty) {
                            setState(() {
                              bccTags.add(v);
                            });
                            bccController.clear();
                          }
                        },
                        onEditingComplete: () {
                          final v = bccController.text.trim();
                          if (v.isNotEmpty) {
                            setState(() {
                              bccTags.add(v);
                            });
                            bccController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Chủ đề'),
            ),
            const SizedBox(height: 10),
            quill.QuillToolbar.simple(
              controller: quillController,
              configurations: quill.QuillSimpleToolbarConfigurations(
                showFontFamily: true,
                fontFamilyValues: const {
                  'Sans Serif': 'SansSerif',
                  'Serif': 'SansSerif',
                  'Monospace': 'monospace',
                  'Roboto': 'Roboto',
                  'Times New Roman': 'Times New Roman',
                  'Arial': 'Arial',
                },
                showFontSize: true,
              ),
            ),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: quill.QuillEditor(
                controller: quillController,
                scrollController: ScrollController(),
                focusNode: _editorFocusNode,
                configurations: const quill.QuillEditorConfigurations(
                  scrollable: true,
                  autoFocus: false,
                  expands: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tagController,
              decoration: const InputDecoration(labelText: 'Tag (cách nhau bởi dấu phẩy)'),
            ),
            if (mailAttachments.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tài liệu đã đính kèm:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...mailAttachments.map((att) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(att.name),
                        subtitle: Text(att.url),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: 'Gỡ tệp này',
                          onPressed: () async {
                            // Xóa file trên Firestore
                            await FirebaseFirestore.instance
                                .collection('mail_attachments')
                                .doc(att.id)
                                .delete();
                            // Xóa khỏi danh sách local
                            setState(() {
                              mailAttachments.removeWhere((a) => a.id == att.id);
                            });
                          },
                        ),
                      )),
                ],
              ),
            ListTile(
              title: Text(scheduled == null
                  ? 'Chọn thời gian gửi'
                  : 'Đã chọn: ${scheduled!.day}/${scheduled!.month}/${scheduled!.year} ${scheduled!.hour.toString().padLeft(2, '0')}:${scheduled!.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: scheduled ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(scheduled ?? DateTime.now()),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      scheduled = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  } else {
                    setState(() {
                      scheduled = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                      );
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}