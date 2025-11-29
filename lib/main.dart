import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'controllers/user_controller.dart';
import 'models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'phone_register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_info_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'compose_mail_screen.dart';
import 'dart:async';
import 'mail_detail_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart'; // Thêm dòng này
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/animation.dart';
import 'dart:convert'; // Để dùng jsonEncode
import 'dart:math';    // Để dùng Random
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
   String? receiverId = message.data['receiverId'];
  if (receiverId != null && receiverId.isNotEmpty) {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
    final data = userDoc.data();
    if (data != null && data.containsKey('notification') && data['notification'] == false) {
      print('User đã tắt thông báo (background), không hiện notification.');
      return; // Không hiện thông báo nếu notification = false
    }
  }
  // Hiện thông báo khi app ở background/terminated
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  // Lấy thông tin createdAt từ data (nếu có)
  String createdAtStr = '';
  if (message.data.containsKey('createdAt') && message.data['createdAt'] != null && message.data['createdAt'].toString().isNotEmpty) {
    try {
      DateTime dt = DateTime.parse(message.data['createdAt']);
      createdAtStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      createdAtStr = message.data['createdAt'].toString();
    }
  }

  String body = notification?.body ?? '';
  if (createdAtStr.isNotEmpty) {
    // Thêm dòng thời gian vào cuối body
    body = "$body\nLúc: $createdAtStr";
  }

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mail_channel', // channelId phải giống với Cloud Function
          'Mail Notification',
          channelDescription: 'Thông báo email mới',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   RemoteNotification? notification = message.notification;
//   AndroidNotification? android = message.notification?.android;
//   if (notification != null && android != null) {
//     flutterLocalNotificationsPlugin.show(
//       notification.hashCode,
//       notification.title,
//       notification.body,
//       NotificationDetails(
//         android: AndroidNotificationDetails(
//           'mail_channel',
//           'Mail Notification',
//           channelDescription: 'Thông báo email mới',
//           importance: Importance.max,
//           priority: Priority.high,
//           playSound: true,
//         ),
//       ),
//     );
//   }
// }
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Thêm đoạn này để khởi tạo local notification cho Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCURbADuU8iBuXyOQMvQVCMwn5prNfME1o",
        authDomain: "flutter-email-459809.firebaseapp.com",
        projectId: "flutter-email-459809",
        storageBucket: "flutter-email-459809.firebasestorage.app",
        messagingSenderId: "141493579332",
        appId: "1:141493579332:web:1ab696e684c1f3b9781611",
        measurementId: "G-YQPXG9W7QC",
      ),
    );
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    await Firebase.initializeApp();

    // Tạo notification channel cho Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mail_channel', // id phải giống với channelId trong Cloud Function
      'Mail Notification',
      description: 'Thông báo email mới',
      importance: Importance.max,
      playSound: true,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Đăng ký handler cho background message
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Lắng nghe thông báo khi app đang mở (foreground)
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   print('RemoteMessage received: $message');
    //   RemoteNotification? notification = message.notification;
    //   AndroidNotification? android = message.notification?.android;
    //   if (notification != null && android != null) {
    //     print('Show local notification!');
    //     flutterLocalNotificationsPlugin.show(
    //       notification.hashCode,
    //       notification.title,
    //       notification.body,
    //       NotificationDetails(
    //         android: AndroidNotificationDetails(
    //           'mail_channel',
    //           'Mail Notification',
    //           channelDescription: 'Thông báo email mới',
    //           importance: Importance.max,
    //           priority: Priority.high,
    //           playSound: true,
    //         ),
    //       ),
    //     );
    //   }
    // });
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  int _darkMode = 1; // 0: light, 1: dark, 2: system
  bool _showSplash = true;
  late final AnimationController _lottieController;
  
  @override
  void initState() {
    super.initState();
    // Tạo controller cho Lottie, tăng tốc độ lên 2 lần (hoặc giá trị bạn muốn)
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3250), // Giữ nguyên thời gian hiệu ứng gốc nếu muốn
    )..forward();

    // Hiện splash trong 6.5 giây như cũ
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }
  void setDarkMode(int value) {
    setState(() {
      _darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          body: Center(
            child: Lottie.asset(
              'assets/intro.json',
              width: 350,   // Tăng kích thước tại đây
              height: 350,  // Tăng kích thước tại đây
              fit: BoxFit.contain,
              controller: _lottieController,
              onLoaded: (composition) {
                _lottieController.duration = composition.duration * 0.5;
                _lottieController.forward(from: 0);
              },
              repeat: false,
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Gmail Clone',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[900],
        drawerTheme: DrawerThemeData(backgroundColor: Colors.grey[850]),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
        ),
      ),
      themeMode: _darkMode == 0
          ? ThemeMode.light
          : _darkMode == 1
              ? ThemeMode.dark
              : ThemeMode.system,
      home: GmailHomePage(
        onDarkModeChanged: setDarkMode,
        darkMode: _darkMode, // Thêm dòng này
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
enum MailFilter { primary, starred, important, snoozed, trash, spam, sent, scheduled, drafts, outbox }
MailFilter _currentFilter = MailFilter.primary;

class GmailHomePage extends StatefulWidget {
  final void Function(int)? onDarkModeChanged;
  final int darkMode;
  const GmailHomePage({super.key, this.onDarkModeChanged, required this.darkMode});
  // const GmailHomePage({super.key});
  @override
  State<GmailHomePage> createState() => _GmailHomePageState();
}

class _GmailHomePageState extends State<GmailHomePage> {
  final UserController _controller = UserController();
  UserModel? _user;
  bool _checkingSignIn = true;
  String? _avatarUrl;
  StreamSubscription? _mailSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _autoRefreshTimer;
  Set<String> _previousMailIds = {};
  bool _isLoadingMails = false; 
  DateTime? _lastMaxCreatedAt;
  List<Map<String, dynamic>> _futureMails = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  String? _lastViewedMailId;
  String? _lastViewedMailsUsersId;
  String? _fcmToken;
  String _viewMode = 'basic';
  bool _showTagFilters = false;
  List<String> _tagFilters = [];
  final TextEditingController _tagController = TextEditingController();
  String? _selectedTag;
  bool _isTagFilterActive = false; // Thêm vào class _GmailHomePageState
  String? _currentTag; // Lưu tag hiện tại nếu có
  bool _isCategoryFilterActive = false;
  String? _currentCategory;
  Set<String> _allPreviousMailIds = {};
  // GoogleSignIn instance cho web (có clientId) và mobile (null)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '141493579332-h9nq4qvl7o0h0hm517lapo7gn9crdmst.apps.googleusercontent.com'
        : null,
  );
  List<Map<String, dynamic>> userMails = []; // Danh sách mail thực tế
  // final List<Map<String, String>> emails = [
  //   {
  //     'sender': 'Gamefound',
  //     'subject': 'New comment reply',
  //     'message': "There’s a new reply to your comment.",
  //     'time': '6:13 AM',
  //     'avatar': 'G'
  //   },
  //   {
  //     'sender': 'Gamefound',
  //     'subject': 'Update 24 in Lands of Evershade',
  //     'message': "Pledge Manager is OPEN! TESTING...",
  //     'time': '2:41 AM',
  //     'avatar': 'G'
  //   },
  //   {
  //     'sender': 'BoardGameTables.com',
  //     'subject': 'A shipment from order #241222 is on the way',
  //     'message': "🚗  Shipped",
  //     'time': '28 Feb',
  //     'avatar': 'B'
  //   },
  //   {
  //     'sender': 'Gamefound',
  //     'subject': 'AR Next: Coming to Gamefound in 2025',
  //     'message': "War, Agriculture and zombies See all AR Next...",
  //     'time': '28 Feb',
  //     'avatar': 'G'
  //   },
  //   {
  //     'sender': 'Gamefound',
  //     'subject': 'Update 18 in Puerto Rico Special Edition',
  //     'message': "Development news rk revealed!",
  //     'time': '27 Feb',
  //     'avatar': 'G'
  //   },
  //   {
  //     'sender': 'cardservicedesk',
  //     'subject': 'SAO KÉ TÍCH ĐIỂM HOÀN TIÊN MASTERCARD...',
  //     'message': "Kính gửi: Quý khách hàng Ngân hàng TMCP H...",
  //     'time': '22 Feb',
  //     'avatar': 'C'
  //   },
  //   {
  //     'sender': 'Miniature Market',
  //     'subject': 'A little gift for your next game n°',
  //     'message': "Limited-time deal: \$10 off when",
  //     'time': '22 Feb',
  //     'avatar': 'M'
  //   },
  // ];

  Color getAvatarColor(String avatar) {
    final Map<String, Color> colorMap = {
      'G': const Color.fromRGBO(160, 66, 244, 1),
      'B': const Color.fromRGBO(251, 187, 1, 1),
      'C': const Color.fromRGBO(52, 167, 83, 1),
      'M': const Color.fromRGBO(233, 30, 99, 1),
    };
    String firstChar = avatar[0].toUpperCase();
    return colorMap[firstChar] ?? Colors.grey;
  }
  // Hàm tìm kiếm mail theo subject hoặc content
        Future<void> _searchMails(String query) async {
      if (_user == null || query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
        return;
      }
      setState(() {
        _isSearching = true;
      });
      try {
        // Lấy userId, email, phone, search mode, finding_by_date, from_date, to_date
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _user!.email)
            .limit(1)
            .get();
        if (userQuery.docs.isEmpty) {
          setState(() {
            _searchResults = [];
            _showSearchResults = false;
            _isSearching = false;
          });
          return;
        }
        final userData = userQuery.docs.first.data();
        final userId = userData['id']?.toString();
        final userEmail = userData['email']?.toString();
        final userPhone = userData['phone']?.toString();
        final searchMode = userData['search'] ?? 'basic';
        final findingByDate = userData['finding_by_date'] ?? false;
        final fromDateRaw = userData['from_date'];
        final toDateRaw = userData['to_date'];
    
        DateTime? fromDate;
        DateTime? toDate;
        // Chuyển đổi from_date, to_date sang DateTime
        if (fromDateRaw != null) {
          if (fromDateRaw is Timestamp) {
            fromDate = fromDateRaw.toDate();
          } else if (fromDateRaw is String) {
            try {
              fromDate = DateTime.parse(fromDateRaw);
            } catch (_) {
              fromDate = null;
            }
          }
        }
        if (toDateRaw != null) {
          if (toDateRaw is Timestamp) {
            toDate = toDateRaw.toDate();
          } else if (toDateRaw is String) {
            try {
              toDate = DateTime.parse(toDateRaw);
            } catch (_) {
              toDate = null;
            }
          }
        }
    
        if (userId == null || userId.isEmpty) {
          setState(() {
            _searchResults = [];
            _showSearchResults = false;
            _isSearching = false;
          });
          return;
        }
    
        // 1. Lấy danh sách mailId mà user này là receiver
        final mailsUsersSnap = await FirebaseFirestore.instance
            .collection('mails_users')
            .where('receiverId', isEqualTo: userId)
            .get();
        final Set<String> mailIds = {};
        for (var doc in mailsUsersSnap.docs) {
          final mailId = doc.data()['mailId']?.toString();
          if (mailId != null && mailId.isNotEmpty) {
            mailIds.add(mailId);
          }
        }
    
        // 2. Nếu không có mailId, thử tìm qua CC/BCC với email và phone
        if (mailIds.isEmpty) {
          final mailsSnap = await FirebaseFirestore.instance
              .collection('mails')
              .where('cc', isGreaterThanOrEqualTo: '')
              .get();
    
          for (var mailDoc in mailsSnap.docs) {
            final data = mailDoc.data();
            final cc = (data['cc'] ?? '').toString();
            final bcc = (data['bcc'] ?? '').toString();
    
            bool found = false;
            if (userEmail != null && userEmail.isNotEmpty) {
              final ccList = cc.split(',').map((e) => e.trim()).toList();
              final bccList = bcc.split(',').map((e) => e.trim()).toList();
              if (ccList.contains(userEmail) || bccList.contains(userEmail)) {
                mailIds.add(data['id']?.toString() ?? mailDoc.id);
                found = true;
              }
            }
            if (!found && userPhone != null && userPhone.isNotEmpty) {
              final ccList = cc.split(',').map((e) => e.trim()).toList();
              final bccList = bcc.split(',').map((e) => e.trim()).toList();
              if (ccList.contains(userPhone) || bccList.contains(userPhone)) {
                mailIds.add(data['id']?.toString() ?? mailDoc.id);
              }
            }
          }
        }
    
        if (mailIds.isEmpty) {
          setState(() {
            _searchResults = [];
            _showSearchResults = false;
            _isSearching = false;
          });
          return;
        }
    
        // Truy vấn bảng mails theo batch (tối đa 30/lần)
        List<Map<String, dynamic>> results = [];
        const int batchSize = 30;
        final mailIdsList = mailIds.toList();
    
        for (var i = 0; i < mailIdsList.length; i += batchSize) {
          final batchMailIds = mailIdsList.sublist(
            i,
            i + batchSize > mailIdsList.length ? mailIdsList.length : i + batchSize,
          );
          final mailsSnap = await FirebaseFirestore.instance
              .collection('mails')
              .where('id', whereIn: batchMailIds)
              .get();
    
          for (var mailDoc in mailsSnap.docs) {
            final data = mailDoc.data();
            final subject = (data['subject'] ?? '').toString();
            final content = (data['content'] ?? '').toString();
            final mailId = data['id'] ?? mailDoc.id;
            final createdAtRaw = data['createdAt'];
            DateTime? createdAt;
            if (createdAtRaw is Timestamp) {
              createdAt = createdAtRaw.toDate();
            } else if (createdAtRaw is String) {
              try {
                createdAt = DateTime.parse(createdAtRaw);
              } catch (_) {}
            }
    
            // BASIC SEARCH
            if (searchMode == 'basic') {
              if (subject.toLowerCase().contains(query.toLowerCase()) ||
                  content.toLowerCase().contains(query.toLowerCase())) {
                results.add({
                  'id': mailId,
                  'subject': subject,
                  'content': content,
                  'senderName': data['senderName'] ?? '',
                  'createdAt': data['createdAt'],
                });
              }
            } else {
              // ADVANCED SEARCH
              bool match = false;
    
              // 1. Tìm theo subject/content như basic
              if (subject.toLowerCase().contains(query.toLowerCase()) ||
                  content.toLowerCase().contains(query.toLowerCase())) {
                match = true;
              }
    
              // 2. Tìm theo tài liệu đính kèm (mail_attachments)
              if (!match) {
                final attachSnap = await FirebaseFirestore.instance
                    .collection('mail_attachments')
                    .where('mailId', isEqualTo: mailId)
                    .get();
                for (var attDoc in attachSnap.docs) {
                  final attData = attDoc.data();
                  final name = (attData['name'] ?? '').toString();
                  if (name.toLowerCase().contains(query.toLowerCase())) {
                    match = true;
                    break;
                  }
                }
              }
    
              // 3. Nếu finding_by_date, kiểm tra khoảng thời gian
              if (match && findingByDate && fromDate != null && toDate != null && createdAt != null) {
                if (createdAt.isBefore(fromDate) || createdAt.isAfter(toDate)) {
                  match = false;
                }
              }
    
              if (match) {
                results.add({
                  'id': mailId,
                  'subject': subject,
                  'content': content,
                  'senderName': data['senderName'] ?? '',
                  'createdAt': data['createdAt'],
                });
              }
            }
          }
        }
    
        setState(() {
          _searchResults = results;
          _showSearchResults = true;
          _isSearching = false;
        });
      } catch (e) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    }
  // Trong initState hoặc sau khi đăng nhập:
Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _restoreUserFromPrefs();
    _autoSignIn();
    // _mailSubscription = FirebaseFirestore.instance
    //   .collection('mails_users')
    //   .snapshots()
    //   .listen((_) {
    //     _fetchUserMails();
    //   });
    if (!kIsWeb) {
      _requestNotificationPermission();
      listenAndShowForegroundNotification();
      print('Đang lấy FCM token...');
      FirebaseMessaging.instance.getToken().then((token) async {
        print('FCM Token: $token');
        // Lưu token vào Firestore (chỉ cho Android)
        if (_user != null && token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.id)
              .update({'fcmTokenAndroid': token});
        }
      });
    }
    if (kIsWeb) {
    _setupFirebaseMessagingWeb().then((_) async {
      print('FCM Token (web): $_fcmToken');
      // Lưu token web vào Firestore (nếu có user)
      if (_user != null && _fcmToken != null && _fcmToken!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.id)
            .update({'fcmTokenWeb': _fcmToken});
      }
    });
  }

    // Tự động reload mỗi 10 giây để kiểm tra mail đến hạn
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _unsnoozeMailsIfNeeded();
      if (_isCategoryFilterActive && _currentCategory != null) {
        await _fetchUserMailsByCategory(_currentCategory!, showLoading: false);
      } else if (_isTagFilterActive && _currentTag != null) {
        await _fetchMailsByTag(_currentTag!, showLoading: false);
      } else {
        await _fetchUserMails(showLoading: false);
      }
      _checkAndNotifyFutureMails();
      await _checkAllNewMailsAndNotify(); // Thêm dòng này
    });
    // ...existing code...
    // Nếu có mail vừa xem bị văng thì mở lại
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Ưu tiên lấy từ SharedPreferences nếu có
    final prefs = await SharedPreferences.getInstance();
    final lastMailId = prefs.getString('last_viewed_mail_id');
    final lastMailsUsersId = prefs.getString('last_viewed_mails_users_id');
    if (lastMailId != null && lastMailsUsersId != null && _user != null) {
      await prefs.remove('last_viewed_mail_id');
      await prefs.remove('last_viewed_mails_users_id');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MailDetailScreen(
            mailId: lastMailsUsersId,
            currentUserId: _user!.id!,
            isSent: false,
            filter: _currentFilter,
            darkMode: widget.darkMode,
          ),
        ),
      );
    } else if (_lastViewedMailId != null && _lastViewedMailsUsersId != null && _user != null) {
      final mailId = _lastViewedMailId!;
      final mailsUsersId = _lastViewedMailsUsersId!;
      final userId = _user!.id;
      _lastViewedMailId = null;
      _lastViewedMailsUsersId = null;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MailDetailScreen(
            mailId: mailsUsersId,
            currentUserId: userId!,
            isSent: false,
            filter: _currentFilter,
            darkMode: widget.darkMode,
          ),
        ),
      );
    }
  });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_user != null) {
        await _loadTagFilters();
      }
    });
  }
  Future<void> _loadTagFilters() async {
  if (_user == null || _user!.id == null) return;
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
  final data = userDoc.data();
  if (data != null && data['tag_filter'] != null && data['tag_filter'].toString().trim().isNotEmpty) {
    setState(() {
      _tagFilters = data['tag_filter'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    });
  } else {
    setState(() {
      _tagFilters = [];
    });
  }
}

Future<void> _updateTagFilters(List<String> tags) async {
  if (_user == null || _user!.id == null) return;
  await FirebaseFirestore.instance.collection('users').doc(_user!.id).update({
    'tag_filter': tags.join(','),
  });
  setState(() {
    _tagFilters = tags;
  });
}
  Future<void> _ensureUserExtraFields(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      final Map<String, dynamic> updateData = {};
      if (!data.containsKey('view')) updateData['view'] = 'basic';
      if (!data.containsKey('search')) updateData['search'] = 'basic';
      if (!data.containsKey('notification')) updateData['notification'] = true;
      if (!data.containsKey('dark_mode')) updateData['dark_mode'] = 0;
      // Bổ sung các trường mới cho tìm kiếm nâng cao
      if (!data.containsKey('finding_by_date')) updateData['finding_by_date'] = false;
      if (!data.containsKey('finding_attach')) updateData['finding_attach'] = false;
      if (!data.containsKey('from_date')) updateData['from_date'] = null;
      if (!data.containsKey('to_date')) updateData['to_date'] = null;
      // Bổ sung trường tag_filter kiểu string
      if (!data.containsKey('tag_filter')) updateData['tag_filter'] = null;
      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(updateData);
      }
    }
  }
  void listenAndShowForegroundNotification() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('RemoteMessage received: $message');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification}');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // --- Kiểm tra notification setting của user ---
    if (_user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
      final data = userDoc.data();
      if (data != null && data.containsKey('notification') && data['notification'] == false) {
        print('User đã tắt thông báo, không hiện notification.');
        return; // Không hiện thông báo nếu notification = false
      }
    }

    if (notification != null && android != null) {
      print('Show local notification!');
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'mail_channel',
            'Mail Notification',
            channelDescription: 'Thông báo email mới',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    } else {
      print('Không có trường notification trong message!');
    }
  });
}
  // Thiết lập FCM cho web
  Future<void> _setupFirebaseMessagingWeb() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    _fcmToken = await messaging.getToken(
      vapidKey: 'BA2jAWCkhjXZ9gmCjUC9dBlF7XnHC2hwI6_dhXHh8O4djsMHWCTDTcnSCw_e-5bou4ZSdrztk50Fo9cpk4TTrTE',
    );
    print('FCM Token (from _setupFirebaseMessagingWeb): $_fcmToken');

    // Đăng ký service worker nếu chưa có (chỉ cần cho web)
    registerServiceWorker();

    // Lắng nghe thông báo foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('RemoteMessage received: $message');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // --- Kiểm tra notification setting của user ---
      if (_user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
        final data = userDoc.data();
        if (data != null && data.containsKey('notification') && data['notification'] == false) {
          print('User đã tắt thông báo (web), không hiện notification.');
          return; // Không hiện thông báo nếu notification = false
        }
      }

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'mail_channel',
              'Mail Notification',
              channelDescription: 'Thông báo email mới',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });
  }
  // Hàm phát âm thanh notification (dùng cho web)
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset('assets/notification.mp3');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }
  @override
  void dispose() {
    _mailSubscription?.cancel();
    _autoRefreshTimer?.cancel(); // Hủy timer khi dispose
    _searchController.dispose();
    super.dispose();
  }
  // Hàm kiểm tra các mail đã đến hạn và phát âm thanh
  Future<void> _checkAndNotifyFutureMails() async {
    if (_futureMails.isEmpty) return;

    // --- Kiểm tra notification setting của user ---
    if (_user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
      final data = userDoc.data();
      if (data != null && data.containsKey('notification') && data['notification'] == false) {
        print('User đã tắt thông báo, không hiện notification (future mail).');
        return; // Không hiện thông báo nếu notification = false
      }
    }

    final now = DateTime.now().toUtc();
    List<Map<String, dynamic>> remain = [];
        for (final mail in _futureMails) {
      final createdAt = mail['createdAtObj'] as DateTime;
      if (!createdAt.isAfter(now)) {
        // Kiểm tra notification setting của user, nếu tắt thì không tạo thông báo
        bool shouldNotify = true;
        if (_user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
          final data = userDoc.data();
          if (data != null && data.containsKey('notification') && data['notification'] == false) {
            shouldNotify = false;
          }
        }
        if (!shouldNotify) {
          print('User đã tắt thông báo, không tạo notification cho mail đến hạn.');
          continue;
        }
        // Hiện local notification khi đến giờ
        final senderName = mail['sender'] ?? '';
        String createdAtStr = '';
        try {
          createdAtStr =
              "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} ${createdAt.day}/${createdAt.month}/${createdAt.year}";
        } catch (_) {}
        await _showLocalNotification(
          title: 'Bạn có email mới!',
          body:
              "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
          imageUrl: mail['avatar'],
        );
        try {
          await _audioPlayer.stop();
          await _audioPlayer.setAsset('assets/notification.mp3');
          await _audioPlayer.play();
        } catch (e) {
          debugPrint('Audio error: $e');
        }
      } else {
        remain.add(mail);
      }
    }
    _futureMails = remain;
  }
  
    // ...existing code...
    Future<void> _checkAllNewMailsAndNotify() async {
    if (_user == null || _user!.id == null) return;
    final userId = _user!.id!;
    final mailsUsersSnap = await FirebaseFirestore.instance
        .collection('mails_users')
        .where('receiverId', isEqualTo: userId)
        .where('is_spam', isEqualTo: false)
        .where('trash', isEqualTo: false)
        .get();
  
    final List<String> mailIds = [];
    for (var doc in mailsUsersSnap.docs) {
      final data = doc.data();
      final mailId = data['mailId']?.toString();
      if (mailId != null && mailId.isNotEmpty) {
        mailIds.add(mailId);
      }
    }
  
    final nowUtc = DateTime.now().toUtc();
    final Set<String> currentMailIds = mailIds.toSet();
    final Set<String> newMailIds = _allPreviousMailIds == null
        ? currentMailIds
        : currentMailIds.difference(_allPreviousMailIds);
  
    if (newMailIds.isNotEmpty) {
      // Chia nhỏ thành các batch tối đa 30 phần tử
      const int batchSize = 30;
      final newMailIdsList = newMailIds.toList();
      for (var i = 0; i < newMailIdsList.length; i += batchSize) {
        final batchMailIds = newMailIdsList.sublist(
          i,
          i + batchSize > newMailIdsList.length ? newMailIdsList.length : i + batchSize,
        );
        final mailsSnap = await FirebaseFirestore.instance
            .collection('mails')
            .where('id', whereIn: batchMailIds)
            .get();
        for (var mailDoc in mailsSnap.docs) {
          final data = mailDoc.data();
          final createdAt = data['createdAt'];
          DateTime? createdAtTime;
          if (createdAt is String) {
            try {
              createdAtTime = DateTime.parse(createdAt);
            } catch (_) {}
          } else if (createdAt is Timestamp) {
            createdAtTime = createdAt.toDate();
          }
          if (createdAtTime == null) continue;
          // Nếu mail mới trong vòng 2 phút gần nhất
          if (nowUtc.difference(createdAtTime.toUtc()).inMinutes.abs() < 2) {
            final senderName = data['senderName'] ?? '';
            String createdAtStr = '';
            try {
              createdAtStr =
                  "${createdAtTime.hour.toString().padLeft(2, '0')}:${createdAtTime.minute.toString().padLeft(2, '0')} ${createdAtTime.day}/${createdAtTime.month}/${createdAtTime.year}";
            } catch (_) {}
            await _showLocalNotification(
              title: 'Bạn có email mới!',
              body:
                  "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${data['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
              imageUrl: data['senderAvatar'],
            );
            try {
              await _audioPlayer.stop();
              await _audioPlayer.setAsset('assets/notification.mp3');
              await _audioPlayer.play();
            } catch (e) {
              debugPrint('Audio error: $e');
            }
          }
        }
      }
    }
    _allPreviousMailIds = currentMailIds;
  }
  Future<void> _unsnoozeMailsIfNeeded() async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('mails_users')
        .where('is_snoozed', isEqualTo: true)
        .where('snoozed_time', isLessThanOrEqualTo: now)
        .get();
    for (var doc in snap.docs) {
      await doc.reference.update({'is_snoozed': false, 'snoozed_time': null});
    }
  }
  // ...existing code...
  Future<void> _fetchUserMails({bool showLoading = true}) async {
    if (_isTagFilterActive || _isCategoryFilterActive) {
      return;
    }
    if (!mounted) return;
    if (showLoading) setState(() => _isLoadingMails = true);
    try {
      if (_user == null || _user!.email.isEmpty) {
        setState(() {
          userMails = [];
          _isLoadingMails = false;
        });
        return;
      }
  
      // Lấy thông tin view (basic/advanced)
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _user!.email)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        setState(() {
          userMails = [];
          _isLoadingMails = false;
        });
        return;
      }
      final userData = userQuery.docs.first.data();
      final userId = userData['id']?.toString();
      final viewMode = userData['view'] ?? 'basic';
      setState(() {
        _viewMode = viewMode;
      });
      if (userId == null || userId.isEmpty) {
        setState(() {
          userMails = [];
          _isLoadingMails = false;
        });
        return;
      }
  
      // Xử lý các filter gửi đi (sent, scheduled, drafts)
      if (_currentFilter == MailFilter.sent ||
          _currentFilter == MailFilter.scheduled ||
          _currentFilter == MailFilter.drafts) {
        Query mailsQuery = FirebaseFirestore.instance
            .collection('mails')
            .where('senderId', isEqualTo: userId);
  
        if (_currentFilter == MailFilter.drafts) {
          mailsQuery = mailsQuery.where('is_drafts', isEqualTo: true);
        }
  
        final mailsSnap = await mailsQuery.get();
        final now = DateTime.now();
        List<Map<String, dynamic>> mails = [];
        for (var mailDoc in mailsSnap.docs) {
          final dataObj = mailDoc.data();
          if (dataObj == null || dataObj is! Map) continue;
          final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
  
          final createdAt = data['createdAt'];
          DateTime? createdAtTime;
          if (createdAt is String) {
            try {
              createdAtTime = DateTime.parse(createdAt);
            } catch (_) {}
          } else if (createdAt is Timestamp) {
            createdAtTime = createdAt.toDate();
          }
  
          // Sửa filter SENT: KHÔNG hiển thị mail là nháp (is_drafts == true)
        if (_currentFilter == MailFilter.sent &&
            createdAtTime != null &&
            !createdAtTime.isAfter(now) &&
            (data['is_drafts'] != true)) {
          mails.add({
            'mailsUsersId': null,
            'mailId': (data['id']?.toString() ?? mailDoc.id),
            'sender': data['senderName'] ?? '',
            'subject': data['subject'] ?? '',
            'content': viewMode == "advanced"
                ? (data['content'] ?? '').toString()
                : ((data['content'] ?? '').toString().length > 40
                    ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                    : (data['content'] ?? '').toString()),
            'createdAt': data['createdAt'] ?? '',
            'starred': false,
            'important': data['important'] == true,
            'avatar': data['senderAvatar'] ?? '',
            'createdAtObj': createdAtTime,
          });
        }
          if (_currentFilter == MailFilter.scheduled && createdAtTime != null && createdAtTime.isAfter(now)) {
            mails.add({
              'mailsUsersId': null,
              'mailId': (data['id']?.toString() ?? mailDoc.id),
              'sender': data['senderName'] ?? '',
              'subject': data['subject'] ?? '',
              'content': viewMode == "advanced"
                  ? (data['content'] ?? '').toString()
                  : ((data['content'] ?? '').toString().length > 40
                      ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                      : (data['content'] ?? '').toString()),
              'createdAt': data['createdAt'] ?? '',
              'starred': false,
              'important': data['important'] == true,
              'avatar': data['senderAvatar'] ?? '',
            });
          }
          if (_currentFilter == MailFilter.drafts && data['is_drafts'] == true) {
            mails.add({
              'mailsUsersId': null,
              'mailId': (data['id']?.toString() ?? mailDoc.id),
              'sender': data['senderName'] ?? '',
              'subject': data['subject'] ?? '',
              'content': viewMode == "advanced"
                  ? (data['content'] ?? '').toString()
                  : ((data['content'] ?? '').toString().length > 40
                      ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                      : (data['content'] ?? '').toString()),
              'createdAt': data['createdAt'] ?? '',
              'starred': false,
              'important': data['important'] == true,
              'avatar': data['senderAvatar'] ?? '',
              'createdAtObj': createdAtTime,
            });
          }
        }
        // Sắp xếp mail mới nhất lên đầu (giảm dần theo createdAt)
        mails.sort((a, b) {
          final aTime = a['createdAtObj'] as DateTime?;
          final bTime = b['createdAtObj'] as DateTime?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        setState(() {
          userMails = mails;
          _isLoadingMails = false;
        });
        return;
      }
  
      // --- FILTER OUTBOX ---
      if (_currentFilter == MailFilter.outbox) {
        var mailsUsersQuery = FirebaseFirestore.instance
            .collection('mails_users')
            .where('receiverId', isEqualTo: userId)
            .where('is_outbox', isEqualTo: true)
            .where('is_spam', isEqualTo: false)
            .where('trash', isEqualTo: false);
  
        final mailsUsersSnap = await mailsUsersQuery.get();
  
        final List<Map<String, dynamic>> mailsUsersList = [];
        final List<String> mailIds = [];
        for (var doc in mailsUsersSnap.docs) {
          final dataObj = doc.data();
          final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
          final mailId = data['mailId']?.toString();
          if (mailId != null && mailId.isNotEmpty) {
            mailsUsersList.add({
              'mailsUsersId': doc.id,
              'mailId': mailId,
              'starred': data['starred'] == true,
              'important': data['important'] == true,
              'is_read': data['is_read'] == true,
              'is_spam': data['is_spam'] == true,
              'is_outbox': data['is_outbox'] == true,
              'is_snoozed': data['is_snoozed'] == true, // Lấy thêm trường này
            });
            mailIds.add(mailId);
          }
        }
  
        if (mailIds.isEmpty) {
          setState(() {
            userMails = [];
            _isLoadingMails = false;
          });
          _previousMailIds = {};
          return;
        }
  
        List<Map<String, dynamic>> mails = [];
        final nowUtc = DateTime.now().toUtc();
        const int batchSize = 30;
        for (var i = 0; i < mailIds.length; i += batchSize) {
          final batchMailIds = mailIds.sublist(
            i,
            i + batchSize > mailIds.length ? mailIds.length : i + batchSize,
          );
          final mailsQuery = await FirebaseFirestore.instance
              .collection('mails')
              .where('id', whereIn: batchMailIds)
              .get();
          for (var mailDoc in mailsQuery.docs) {
            final dataObj = mailDoc.data();
            final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
            final mailId = data['id']?.toString() ?? mailDoc.id;
            final mailsUsers = mailsUsersList.firstWhere(
              (e) => e['mailId'] == mailId,
              orElse: () => <String, dynamic>{},
            );
            if (mailsUsers.isEmpty) continue;
            final createdAt = data['createdAt'];
            DateTime? createdAtTime;
            if (createdAt is String) {
              try {
                createdAtTime = DateTime.parse(createdAt);
              } catch (_) {}
            } else if (createdAt is Timestamp) {
              createdAtTime = createdAt.toDate();
            }
            if (createdAtTime == null) continue;
            if (createdAtTime.isAfter(nowUtc)) continue;
            mails.add({
              'mailsUsersId': mailsUsers['mailsUsersId'],
              'mailId': mailId,
              'sender': data['senderName'] ?? '',
              'subject': data['subject'] ?? '',
              'content': viewMode == "advanced"
                  ? (data['content'] ?? '').toString()
                  : ((data['content'] ?? '').toString().length > 40
                      ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                      : (data['content'] ?? '').toString()),
              'createdAt': data['createdAt'] ?? '',
              'createdAtObj': createdAtTime.toUtc(),
              'starred': mailsUsers['starred'] ?? false,
              'important': mailsUsers['important'] ?? false,
              'avatar': data['senderAvatar'] ?? '',
              'is_read': mailsUsers['is_read'] ?? false,
              'is_spam': mailsUsers['is_spam'] ?? false,
              'is_outbox': mailsUsers['is_outbox'] ?? false,
              'is_snoozed': mailsUsers['is_snoozed'] ?? false, // Thêm trường này
            });
          }
        }
  
        // Loại bỏ mail có is_snoozed = true trong filter outbox
        mails = mails.where((mail) => mail['is_snoozed'] != true).toList();
  
        // Nếu viewMode là advanced, lấy thông tin tệp đính kèm cho từng mail theo batch
        if (viewMode == "advanced" && mails.isNotEmpty) {
          final allMailIds = mails.map((m) => m['mailId'] as String).toList();
          Map<String, List<Map<String, String>>> attachmentsMap = {};
          for (var i = 0; i < allMailIds.length; i += batchSize) {
            final batchMailIds = allMailIds.sublist(
              i,
              i + batchSize > allMailIds.length ? allMailIds.length : i + batchSize,
            );
            final attachSnap = await FirebaseFirestore.instance
                .collection('mail_attachments')
                .where('mailId', whereIn: batchMailIds)
                .get();
            for (var doc in attachSnap.docs) {
              final data = doc.data();
              final mailId = data['mailId']?.toString();
              if (mailId == null) continue;
              final name = data['name']?.toString() ?? '';
              final url = data['url']?.toString() ?? '';
              if (name.isNotEmpty && url.isNotEmpty) {
                attachmentsMap.putIfAbsent(mailId, () => []);
                attachmentsMap[mailId]!.add({'name': name, 'url': url});
              }
            }
          }
          // Gán vào từng mail
          for (var mail in mails) {
            mail['attachments'] = attachmentsMap[mail['mailId']] ?? [];
          }
        } else {
          for (var mail in mails) {
            mail.remove('attachments');
          }
        }
  
        // --- PHÁT ÂM THANH KHI CÓ MAIL MỚI ---
        final Set<String> currentMailIds = mails
            .where((mail) => !(mail['createdAtObj'] as DateTime).isAfter(nowUtc))
            .map((mail) => mail['mailId'] as String)
            .toSet();
  
        final Set<String> newMailIds = currentMailIds.difference(_previousMailIds);
  
        bool shouldNotify = true;
        if (mounted && _user != null && _user!.id != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
          final data = userDoc.data();
          if (data != null && data.containsKey('notification') && data['notification'] == false) {
            shouldNotify = false;
          }
        }
  
        if (_previousMailIds.isNotEmpty && newMailIds.isNotEmpty && shouldNotify) {
          for (final mail in mails) {
            if (newMailIds.contains(mail['mailId'])) {
              bool shouldNotify = true;
              if (_user != null) {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
                final data = userDoc.data();
                if (data != null && data.containsKey('notification') && data['notification'] == false) {
                  shouldNotify = false;
                }
              }
              if (!shouldNotify) {
                print('User đã tắt thông báo, không tạo notification cho mail mới.');
                break;
              }
  
              final createdAt = mail['createdAtObj'] as DateTime;
              final createdAtLocal = createdAt.toLocal();
              if (nowUtc.difference(createdAt).inSeconds.abs() < 30) {
                final senderName = mail['sender'] ?? '';
                String createdAtStr = '';
                try {
                  createdAtStr =
                      "${createdAtLocal.hour.toString().padLeft(2, '0')}:${createdAtLocal.minute.toString().padLeft(2, '0')} ${createdAtLocal.day}/${createdAtLocal.month}/${createdAtLocal.year}";
                } catch (_) {}
                if (kIsWeb) {
                  await showWebNotification(
                    'Bạn có email mới!',
                    "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                    icon: 'assets/gmail_logo.png',
                  );
                  _playNotificationSound();
                } else {
                  await _showLocalNotification(
                    title: 'Bạn có email mới!',
                    body:
                        "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                    imageUrl: mail['avatar'],
                  );
                  try {
                    await _audioPlayer.stop();
                    await _audioPlayer.setAsset('assets/notification.mp3');
                    await _audioPlayer.play();
                  } catch (e) {
                    debugPrint('Audio error: $e');
                  }
                }
                break;
              }
            }
          }
        }
        _previousMailIds = currentMailIds;
  
        _futureMails = mails.where((mail) {
          final createdAt = mail['createdAtObj'] as DateTime;
          return createdAt.isAfter(nowUtc);
        }).toList();
  
        mails.sort((a, b) => (b['createdAtObj'] as DateTime).compareTo(a['createdAtObj'] as DateTime));
  
        setState(() {
          userMails = mails.where((mail) {
            final createdAt = mail['createdAtObj'] as DateTime;
            return !createdAt.isAfter(nowUtc);
          }).toList();
          _isLoadingMails = false;
        });
        await _checkAndNotifyFutureMails();
        return;
      }
  
      // --- FILTER NHẬN (primary, starred, important, snoozed, trash, spam) ---
      var mailsUsersQuery = FirebaseFirestore.instance
          .collection('mails_users')
          .where('receiverId', isEqualTo: userId);
  
      if (_currentFilter == MailFilter.snoozed) {
        mailsUsersQuery = mailsUsersQuery
            .where('is_snoozed', isEqualTo: true)
            .where('trash', isEqualTo: false)
            .where('is_spam', isEqualTo: false);
      } else {
        mailsUsersQuery = mailsUsersQuery
            .where('is_snoozed', isEqualTo: false)
            .where('snoozed_time', isNull: true);
  
        if (_currentFilter == MailFilter.primary) {
          mailsUsersQuery = mailsUsersQuery
              .where('trash', isEqualTo: false)
              .where('is_spam', isEqualTo: false);
        } else if (_currentFilter == MailFilter.starred) {
          mailsUsersQuery = mailsUsersQuery
              .where('starred', isEqualTo: true)
              .where('trash', isEqualTo: false)
              .where('is_spam', isEqualTo: false);
        } else if (_currentFilter == MailFilter.important) {
          mailsUsersQuery = mailsUsersQuery
              .where('important', isEqualTo: true)
              .where('trash', isEqualTo: false)
              .where('is_spam', isEqualTo: false);
        } else if (_currentFilter == MailFilter.trash) {
          mailsUsersQuery = mailsUsersQuery.where('trash', isEqualTo: true);
        } else if (_currentFilter == MailFilter.spam) {
          mailsUsersQuery = mailsUsersQuery.where('is_spam', isEqualTo: true);
        }
      }
  
      final mailsUsersSnap = await mailsUsersQuery.get();
  
      final List<Map<String, dynamic>> mailsUsersList = [];
      final List<String> mailIds = [];
      for (var doc in mailsUsersSnap.docs) {
        final dataObj = doc.data();
        final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
        final mailId = data['mailId']?.toString();
        if (mailId != null && mailId.isNotEmpty) {
          mailsUsersList.add({
            'mailsUsersId': doc.id,
            'mailId': mailId,
            'starred': data['starred'] == true,
            'important': data['important'] == true,
            'is_read': data['is_read'] == true,
            'is_spam': data['is_spam'] == true,
            'is_outbox': data['is_outbox'] == true,
          });
          mailIds.add(mailId);
        }
      }
  
      if (mailIds.isEmpty) {
        setState(() {
          userMails = [];
          _isLoadingMails = false;
        });
        _previousMailIds = {};
        return;
      }
  
      List<Map<String, dynamic>> mails = [];
      final nowUtc = DateTime.now().toUtc();
      const int batchSize = 30;
      for (var i = 0; i < mailIds.length; i += batchSize) {
        final batchMailIds = mailIds.sublist(
          i,
          i + batchSize > mailIds.length ? mailIds.length : i + batchSize,
        );
        final mailsQuery = await FirebaseFirestore.instance
            .collection('mails')
            .where('id', whereIn: batchMailIds)
            .get();
        for (var mailDoc in mailsQuery.docs) {
          final dataObj = mailDoc.data();
          final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
          final mailId = data['id']?.toString() ?? mailDoc.id;
          final mailsUsers = mailsUsersList.firstWhere(
            (e) => e['mailId'] == mailId,
            orElse: () => <String, dynamic>{},
          );
          if (mailsUsers.isEmpty) continue;
          final createdAt = data['createdAt'];
          DateTime? createdAtTime;
          if (createdAt is String) {
            try {
              createdAtTime = DateTime.parse(createdAt);
            } catch (_) {}
          } else if (createdAt is Timestamp) {
            createdAtTime = createdAt.toDate();
          }
          if (createdAtTime == null) continue;
          if (_currentFilter == MailFilter.snoozed && createdAtTime.isAfter(nowUtc)) continue;
          mails.add({
            'mailsUsersId': mailsUsers['mailsUsersId'],
            'mailId': mailId,
            'sender': data['senderName'] ?? '',
            'subject': data['subject'] ?? '',
            'content': viewMode == "advanced"
                ? (data['content'] ?? '').toString()
                : ((data['content'] ?? '').toString().length > 40
                    ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                    : (data['content'] ?? '').toString()),
            'createdAt': data['createdAt'] ?? '',
            'createdAtObj': createdAtTime.toUtc(),
            'starred': mailsUsers['starred'] ?? false,
            'important': mailsUsers['important'] ?? false,
            'avatar': data['senderAvatar'] ?? '',
            'is_read': mailsUsers['is_read'] ?? false,
            'is_spam': mailsUsers['is_spam'] ?? false,
            'is_outbox': mailsUsers['is_outbox'] ?? false,
          });
        }
      }
  
      // Nếu KHÔNG phải filter outbox và KHÔNG phải snoozed thì loại bỏ mail có is_outbox = true
      if (_currentFilter != MailFilter.outbox && _currentFilter != MailFilter.snoozed) {
        mails = mails.where((mail) => mail['is_outbox'] != true).toList();
      }
  
      // Nếu viewMode là advanced, lấy thông tin tệp đính kèm cho từng mail theo batch
      if (viewMode == "advanced" && mails.isNotEmpty) {
        final allMailIds = mails.map((m) => m['mailId'] as String).toList();
        Map<String, List<Map<String, String>>> attachmentsMap = {};
        for (var i = 0; i < allMailIds.length; i += batchSize) {
          final batchMailIds = allMailIds.sublist(
            i,
            i + batchSize > allMailIds.length ? allMailIds.length : i + batchSize,
          );
          final attachSnap = await FirebaseFirestore.instance
              .collection('mail_attachments')
              .where('mailId', whereIn: batchMailIds)
              .get();
          for (var doc in attachSnap.docs) {
            final data = doc.data();
            final mailId = data['mailId']?.toString();
            if (mailId == null) continue;
            final name = data['name']?.toString() ?? '';
            final url = data['url']?.toString() ?? '';
            if (name.isNotEmpty && url.isNotEmpty) {
              attachmentsMap.putIfAbsent(mailId, () => []);
              attachmentsMap[mailId]!.add({'name': name, 'url': url});
            }
          }
        }
        // Gán vào từng mail
        for (var mail in mails) {
          mail['attachments'] = attachmentsMap[mail['mailId']] ?? [];
        }
      } else {
        for (var mail in mails) {
          mail.remove('attachments');
        }
      }
  
      // --- PHÁT ÂM THANH KHI CÓ MAIL MỚI ---
      final Set<String> currentMailIds = mails
          .where((mail) => !(mail['createdAtObj'] as DateTime).isAfter(nowUtc))
          .map((mail) => mail['mailId'] as String)
          .toSet();
  
      final Set<String> newMailIds = currentMailIds.difference(_previousMailIds);
  
      bool shouldNotify = true;
      if (mounted && _user != null && _user!.id != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
        final data = userDoc.data();
        if (data != null && data.containsKey('notification') && data['notification'] == false) {
          shouldNotify = false;
        }
      }
  
      if (_previousMailIds.isNotEmpty && newMailIds.isNotEmpty && shouldNotify) {
        for (final mail in mails) {
          if (newMailIds.contains(mail['mailId'])) {
            bool shouldNotify = true;
            if (_user != null) {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
              final data = userDoc.data();
              if (data != null && data.containsKey('notification') && data['notification'] == false) {
                shouldNotify = false;
              }
            }
            if (!shouldNotify) {
              print('User đã tắt thông báo, không tạo notification cho mail mới.');
              break;
            }
  
            final createdAt = mail['createdAtObj'] as DateTime;
            final createdAtLocal = createdAt.toLocal();
            if (nowUtc.difference(createdAt).inSeconds.abs() < 30) {
              final senderName = mail['sender'] ?? '';
              String createdAtStr = '';
              try {
                createdAtStr =
                    "${createdAtLocal.hour.toString().padLeft(2, '0')}:${createdAtLocal.minute.toString().padLeft(2, '0')} ${createdAtLocal.day}/${createdAtLocal.month}/${createdAtLocal.year}";
              } catch (_) {}
              if (kIsWeb) {
                await showWebNotification(
                  'Bạn có email mới!',
                  "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                  icon: 'assets/gmail_logo.png',
                );
                _playNotificationSound();
              } else {
                await _showLocalNotification(
                  title: 'Bạn có email mới!',
                  body:
                      "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                  imageUrl: mail['avatar'],
                );
                try {
                  await _audioPlayer.stop();
                  await _audioPlayer.setAsset('assets/notification.mp3');
                  await _audioPlayer.play();
                } catch (e) {
                  debugPrint('Audio error: $e');
                }
              }
              break;
            }
          }
        }
      }
      _previousMailIds = currentMailIds;
  
      _futureMails = mails.where((mail) {
        final createdAt = mail['createdAtObj'] as DateTime;
        return createdAt.isAfter(nowUtc);
      }).toList();
  
      mails.sort((a, b) => (b['createdAtObj'] as DateTime).compareTo(a['createdAtObj'] as DateTime));
  
      setState(() {
        userMails = mails.where((mail) {
          final createdAt = mail['createdAtObj'] as DateTime;
          return !createdAt.isAfter(nowUtc);
        }).toList();
        _isLoadingMails = false;
      });
      await _checkAndNotifyFutureMails();
    } catch (e) {
      setState(() {
        _isLoadingMails = false;
      });
    }
  }
  // Thêm hàm này vào class _GmailHomePageState:
Future<void> _fetchMailsByTag(String tag, {bool showLoading = true}) async {
  if (_user == null || _user!.id == null) return;
  if (showLoading) {
    setState(() {
      _isLoadingMails = true;
    });
  }
  try {
    // Lấy thông tin viewMode (basic/advanced)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
    final viewMode = userDoc.data()?['view'] ?? 'basic';

    // Lấy danh sách mails_users mà user này là receiver, không phải spam/trash, KHÔNG bị snoozed và có tag chứa tag cần lọc
    final mailsUsersSnap = await FirebaseFirestore.instance
        .collection('mails_users')
        .where('receiverId', isEqualTo: _user!.id)
        .where('is_spam', isEqualTo: false)
        .where('trash', isEqualTo: false)
        .where('is_snoozed', isEqualTo: false)
        .where('snoozed_time', isNull: true) 
        .get();

    // Lọc các mails_users có chứa tag cần tìm
    final List<Map<String, dynamic>> mailsUsersList = [];
    final List<String> mailIds = [];
    for (var doc in mailsUsersSnap.docs) {
      final data = doc.data();
      final mailId = data['mailId']?.toString();
      final tagStr = (data['tag'] ?? '').toString();
      final tags = tagStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (mailId != null && mailId.isNotEmpty && tags.contains(tag)) {
        mailsUsersList.add({
          'mailsUsersId': doc.id,
          'mailId': mailId,
          'starred': data['starred'] == true,
          'important': data['important'] == true,
          'is_read': data['is_read'] == true,
          'is_spam': data['is_spam'] == true,
        });
        mailIds.add(mailId);
      }
    }

    if (mailIds.isEmpty) {
      setState(() {
        userMails = [];
        _isLoadingMails = false;
      });
      return;
    }

    // Lấy thông tin mail từ bảng mails
    List<Map<String, dynamic>> mails = [];
    const int batchSize = 30;
    for (var i = 0; i < mailIds.length; i += batchSize) {
      final batchMailIds = mailIds.sublist(
        i,
        i + batchSize > mailIds.length ? mailIds.length : i + batchSize,
      );
      final mailsSnap = await FirebaseFirestore.instance
          .collection('mails')
          .where('id', whereIn: batchMailIds)
          .get();
      for (var mailDoc in mailsSnap.docs) {
        final data = mailDoc.data();
        final mailId = data['id']?.toString() ?? mailDoc.id;
        final mailsUsers = mailsUsersList.firstWhere(
          (e) => e['mailId'] == mailId,
          orElse: () => <String, dynamic>{},
        );
        if (mailsUsers.isEmpty) continue;
        final createdAt = data['createdAt'];
        DateTime? createdAtTime;
        if (createdAt is String) {
          try {
            createdAtTime = DateTime.parse(createdAt);
          } catch (_) {}
        } else if (createdAt is Timestamp) {
          createdAtTime = createdAt.toDate();
        }
        if (createdAtTime == null) continue;
        mails.add({
          'mailsUsersId': mailsUsers['mailsUsersId'],
          'mailId': mailId,
          'sender': data['senderName'] ?? '',
          'subject': data['subject'] ?? '',
          'content': viewMode == "advanced"
              ? (data['content'] ?? '').toString()
              : ((data['content'] ?? '').toString().length > 40
                  ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                  : (data['content'] ?? '').toString()),
          'createdAt': data['createdAt'] ?? '',
          'createdAtObj': createdAtTime.toUtc(),
          'avatar': data['senderAvatar'] ?? '',
          'starred': mailsUsers['starred'] ?? false,
          'important': mailsUsers['important'] ?? false,
          'is_read': mailsUsers['is_read'] ?? false,
          'is_spam': mailsUsers['is_spam'] ?? false,
        });
      }
    }

    // Nếu viewMode là advanced, lấy thông tin tệp đính kèm cho từng mail theo batch
    if (viewMode == "advanced" && mails.isNotEmpty) {
      final allMailIds = mails.map((m) => m['mailId'] as String).toList();
      Map<String, List<Map<String, String>>> attachmentsMap = {};
      for (var i = 0; i < allMailIds.length; i += batchSize) {
        final batchMailIds = allMailIds.sublist(
          i,
          i + batchSize > allMailIds.length ? allMailIds.length : i + batchSize,
        );
        final attachSnap = await FirebaseFirestore.instance
            .collection('mail_attachments')
            .where('mailId', whereIn: batchMailIds)
            .get();
        for (var doc in attachSnap.docs) {
          final data = doc.data();
          final mailId = data['mailId']?.toString();
          if (mailId == null) continue;
          final name = data['name']?.toString() ?? '';
          final url = data['url']?.toString() ?? '';
          if (name.isNotEmpty && url.isNotEmpty) {
            attachmentsMap.putIfAbsent(mailId, () => []);
            attachmentsMap[mailId]!.add({'name': name, 'url': url});
          }
        }
      }
      // Gán vào từng mail
      for (var mail in mails) {
        mail['attachments'] = attachmentsMap[mail['mailId']] ?? [];
      }
    } else {
      for (var mail in mails) {
        mail.remove('attachments');
      }
    }

    // --- PHÁT ÂM THANH KHI CÓ MAIL MỚI ---
    final nowUtc = DateTime.now().toUtc();
    final Set<String> currentMailIds = mails
        .where((mail) => !(mail['createdAtObj'] as DateTime).isAfter(nowUtc))
        .map((mail) => mail['mailId'] as String)
        .toSet();

    final Set<String> newMailIds = currentMailIds.difference(_previousMailIds);

    // Kiểm tra notification setting của user, nếu tắt thì không thông báo và không phát âm thanh
    bool shouldNotify = true;
    if (mounted && _user != null && _user!.id != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
      final data = userDoc.data();
      if (data != null && data.containsKey('notification') && data['notification'] == false) {
        shouldNotify = false;
      }
    }

    if (_previousMailIds.isNotEmpty && newMailIds.isNotEmpty && shouldNotify) {
      for (final mail in mails) {
        if (newMailIds.contains(mail['mailId'])) {
          bool shouldNotify = true;
          if (_user != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
            final data = userDoc.data();
            if (data != null && data.containsKey('notification') && data['notification'] == false) {
              shouldNotify = false;
            }
          }
          if (!shouldNotify) {
            print('User đã tắt thông báo, không tạo notification cho mail mới.');
            break;
          }

          final createdAt = mail['createdAtObj'] as DateTime;
          final createdAtLocal = createdAt.toLocal();
          if (nowUtc.difference(createdAt).inSeconds.abs() < 30) {
            final senderName = mail['sender'] ?? '';
            String createdAtStr = '';
            try {
              createdAtStr =
                  "${createdAtLocal.hour.toString().padLeft(2, '0')}:${createdAtLocal.minute.toString().padLeft(2, '0')} ${createdAtLocal.day}/${createdAtLocal.month}/${createdAtLocal.year}";
            } catch (_) {}
            if (kIsWeb) {
              await showWebNotification(
                'Bạn có email mới!',
                "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                icon: 'assets/gmail_logo.png',
              );
              _playNotificationSound();
            } else {
              await _showLocalNotification(
                title: 'Bạn có email mới!',
                body:
                    "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                imageUrl: mail['avatar'],
              );
              try {
                await _audioPlayer.stop();
                await _audioPlayer.setAsset('assets/notification.mp3');
                await _audioPlayer.play();
              } catch (e) {
                debugPrint('Audio error: $e');
              }
            }
            break;
          }
        }
      }
    }
    _previousMailIds = currentMailIds;

    // Lưu lại các mail có createdAt trong tương lai để kiểm tra định kỳ
    _futureMails = mails.where((mail) {
      final createdAt = mail['createdAtObj'] as DateTime;
      return createdAt.isAfter(nowUtc);
    }).toList();

    // Thêm dòng này để mail mới lên đầu
    mails.sort((a, b) => (b['createdAtObj'] as DateTime).compareTo(a['createdAtObj'] as DateTime));

    setState(() {
      userMails = mails.where((mail) {
        final createdAt = mail['createdAtObj'] as DateTime;
        return !createdAt.isAfter(nowUtc);
      }).toList();
      _isLoadingMails = false;
    });
    await _checkAndNotifyFutureMails();
  } catch (e) {
    setState(() {
      userMails = [];
      _isLoadingMails = false;
    });
  }
}
Future<void> _fetchUserMailsByCategory(String category, {bool showLoading = true}) async {
  if (_user == null || _user!.id == null) return;
  if (showLoading) {
    setState(() {
      _isLoadingMails = true;
    });
  }
  setState(() {
    _isTagFilterActive = false;
    _currentTag = null;
    _isCategoryFilterActive = true;
    _currentCategory = category;
  });
  try {
    final userId = _user!.id!;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final viewMode = userDoc.data()?['view'] ?? 'basic';

    // Xác định tên trường đúng với category (ví dụ: social -> is_social)
    String field = '';
    switch (category.toLowerCase()) {
      case 'social':
        field = 'is_social';
        break;
      case 'promotions':
        field = 'is_promotions';
        break;
      case 'updates':
        field = 'is_updates';
        break;
      case 'forums':
        field = 'is_forums';
        break;
      default:
        field = '';
    }
    if (field.isEmpty) {
      setState(() {
        userMails = [];
        _isLoadingMails = false;
      });
      await _checkAndNotifyFutureMails();
      return;
    }

    // Lấy danh sách mails_users với receiverId = userId, không phải spam/trash, đúng category
    var mailsUsersQuery = FirebaseFirestore.instance
        .collection('mails_users')
        .where('receiverId', isEqualTo: userId)
        .where('is_spam', isEqualTo: false)
        .where('trash', isEqualTo: false)
        .where(field, isEqualTo: true)
        .where('is_snoozed', isEqualTo: false)
        .where('snoozed_time', isNull: true);

    final mailsUsersSnap = await mailsUsersQuery.get();

    final List<Map<String, dynamic>> mailsUsersList = [];
    final List<String> mailIds = [];
    for (var doc in mailsUsersSnap.docs) {
      final dataObj = doc.data();
      final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
      final mailId = data['mailId']?.toString();
      if (mailId != null && mailId.isNotEmpty) {
        mailsUsersList.add({
          'mailsUsersId': doc.id,
          'mailId': mailId,
          'starred': data['starred'] == true,
          'important': data['important'] == true,
          'is_read': data['is_read'] == true,
          'is_spam': data['is_spam'] == true,
        });
        mailIds.add(mailId);
      }
    }

    if (mailIds.isEmpty) {
      setState(() {
        userMails = [];
        _isLoadingMails = false;
      });
      // _previousMailIds = {};
      return;
    }

    // Lấy thông tin mail từ bảng mails
    List<Map<String, dynamic>> mails = [];
    final nowUtc = DateTime.now().toUtc();
    const int batchSize = 30;
    for (var i = 0; i < mailIds.length; i += batchSize) {
      final batchMailIds = mailIds.sublist(
        i,
        i + batchSize > mailIds.length ? mailIds.length : i + batchSize,
      );
      final mailsSnap = await FirebaseFirestore.instance
          .collection('mails')
          .where('id', whereIn: batchMailIds)
          .get();
      for (var mailDoc in mailsSnap.docs) {
        final dataObj = mailDoc.data();
        final Map<String, dynamic> data = Map<String, dynamic>.from(dataObj);
        final mailId = data['id']?.toString() ?? mailDoc.id;
        final mailsUsers = mailsUsersList.firstWhere(
          (e) => e['mailId'] == mailId,
          orElse: () => <String, dynamic>{},
        );
        if (mailsUsers.isEmpty) continue;
        final createdAt = data['createdAt'];
        DateTime? createdAtTime;
        if (createdAt is String) {
          try {
            createdAtTime = DateTime.parse(createdAt);
          } catch (_) {}
        } else if (createdAt is Timestamp) {
          createdAtTime = createdAt.toDate();
        }
        if (createdAtTime == null) continue;
        // Chỉ lấy mail đã đến hạn (không lấy mail trong tương lai)
        if (createdAtTime.isAfter(nowUtc)) continue;
        mails.add({
          'mailsUsersId': mailsUsers['mailsUsersId'],
          'mailId': mailId,
          'sender': data['senderName'] ?? '',
          'subject': data['subject'] ?? '',
          'content': viewMode == "advanced"
              ? (data['content'] ?? '').toString()
              : ((data['content'] ?? '').toString().length > 40
                  ? '${(data['content'] ?? '').toString().substring(0, 40)}...'
                  : (data['content'] ?? '').toString()),
          'createdAt': data['createdAt'] ?? '',
          'createdAtObj': createdAtTime.toUtc(),
          'starred': mailsUsers['starred'] ?? false,
          'important': mailsUsers['important'] ?? false,
          'avatar': data['senderAvatar'] ?? '',
          'is_read': mailsUsers['is_read'] ?? false,
          'is_spam': mailsUsers['is_spam'] ?? false,
        });
      }
    }

    // Nếu viewMode là advanced, lấy thông tin tệp đính kèm cho từng mail theo batch
    if (viewMode == "advanced" && mails.isNotEmpty) {
      final allMailIds = mails.map((m) => m['mailId'] as String).toList();
      Map<String, List<Map<String, String>>> attachmentsMap = {};
      for (var i = 0; i < allMailIds.length; i += batchSize) {
        final batchMailIds = allMailIds.sublist(
          i,
          i + batchSize > allMailIds.length ? allMailIds.length : i + batchSize,
        );
        final attachSnap = await FirebaseFirestore.instance
            .collection('mail_attachments')
            .where('mailId', whereIn: batchMailIds)
            .get();
        for (var doc in attachSnap.docs) {
          final data = doc.data();
          final mailId = data['mailId']?.toString();
          if (mailId == null) continue;
          final name = data['name']?.toString() ?? '';
          final url = data['url']?.toString() ?? '';
          if (name.isNotEmpty && url.isNotEmpty) {
            attachmentsMap.putIfAbsent(mailId, () => []);
            attachmentsMap[mailId]!.add({'name': name, 'url': url});
          }
        }
      }
      // Gán vào từng mail
      for (var mail in mails) {
        mail['attachments'] = attachmentsMap[mail['mailId']] ?? [];
      }
    } else {
      for (var mail in mails) {
        mail.remove('attachments');
      }
    }

    // --- PHÁT ÂM THANH KHI CÓ MAIL MỚI ---
    final Set<String> currentMailIds = mails
        .where((mail) => !(mail['createdAtObj'] as DateTime).isAfter(nowUtc))
        .map((mail) => mail['mailId'] as String)
        .toSet();

    final Set<String> newMailIds = currentMailIds.difference(_previousMailIds);

    // Kiểm tra notification setting của user, nếu tắt thì không thông báo và không phát âm thanh
    bool shouldNotify = true;
    if (mounted && _user != null && _user!.id != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
      final data = userDoc.data();
      if (data != null && data.containsKey('notification') && data['notification'] == false) {
        shouldNotify = false;
      }
    }

    if (_previousMailIds.isNotEmpty && newMailIds.isNotEmpty && shouldNotify) {
      for (final mail in mails) {
        if (newMailIds.contains(mail['mailId'])) {
          bool shouldNotify = true;
          if (_user != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
            final data = userDoc.data();
            if (data != null && data.containsKey('notification') && data['notification'] == false) {
              shouldNotify = false;
            }
          }
          if (!shouldNotify) {
            print('User đã tắt thông báo, không tạo notification cho mail mới.');
            break;
          }

          final createdAt = mail['createdAtObj'] as DateTime;
          final createdAtLocal = createdAt.toLocal();
          if (nowUtc.difference(createdAt).inSeconds.abs() < 30) {
            final senderName = mail['sender'] ?? '';
            String createdAtStr = '';
            try {
              createdAtStr =
                  "${createdAtLocal.hour.toString().padLeft(2, '0')}:${createdAtLocal.minute.toString().padLeft(2, '0')} ${createdAtLocal.day}/${createdAtLocal.month}/${createdAtLocal.year}";
            } catch (_) {}
            if (kIsWeb) {
              await showWebNotification(
                'Bạn có email mới!',
                "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                icon: 'assets/gmail_logo.png',
              );
              _playNotificationSound();
            } else {
              await _showLocalNotification(
                title: 'Bạn có email mới!',
                body:
                    "${senderName.isNotEmpty ? "Từ: $senderName\n" : ""}Chủ đề: ${mail['subject'] ?? 'Có thư mới trong hộp thư đến'}\n${createdAtStr.isNotEmpty ? "Lúc: $createdAtStr" : ""}",
                imageUrl: mail['avatar'],
              );
              try {
                await _audioPlayer.stop();
                await _audioPlayer.setAsset('assets/notification.mp3');
                await _audioPlayer.play();
              } catch (e) {
                debugPrint('Audio error: $e');
              }
            }
            break;
          }
        }
      }
    }
    _previousMailIds = currentMailIds;

    // Lưu lại các mail có createdAt trong tương lai để kiểm tra định kỳ
    _futureMails = mails.where((mail) {
      final createdAt = mail['createdAtObj'] as DateTime;
      return createdAt.isAfter(nowUtc);
    }).toList();

    // Thêm dòng này để mail mới lên đầu
    mails.sort((a, b) => (b['createdAtObj'] as DateTime).compareTo(a['createdAtObj'] as DateTime));

    setState(() {
      userMails = mails.where((mail) {
        final createdAt = mail['createdAtObj'] as DateTime;
        return !createdAt.isAfter(nowUtc);
      }).toList();
      _isLoadingMails = false;
    });
    await _checkAndNotifyFutureMails();
  } catch (e) {
    setState(() {
      userMails = [];
      _isLoadingMails = false;
    });
  }
}
  // Thêm hàm này vào class _GmailHomePageState nếu chưa có
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    // --- Kiểm tra notification setting của user ---
    if (_user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
      final data = userDoc.data();
      if (data != null && data.containsKey('notification') && data['notification'] == false) {
        print('User đã tắt thông báo, không hiện notification (showLocalNotification).');
        return; // Không hiện thông báo nếu notification = false
      }
    }

    final androidDetails = AndroidNotificationDetails(
      'mail_channel',
      'Mail Notification',
      channelDescription: 'Thông báo email mới',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      largeIcon: imageUrl != null && imageUrl.isNotEmpty
          ? DrawableResourceAndroidBitmap('@mipmap/ic_launcher') // fallback
          : null,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: null,
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
  Future<void> _restoreUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null && email.isNotEmpty) {
      final userModel = await _controller.getUserByEmail(email);
      final avatarUrl = await _getAvatarUrl(email: email, phone: userModel?.phone);
      // Lấy dark_mode từ Firestore
      int darkMode = 0;
      if (userModel != null && userModel.id != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userModel.id).get();
        final data = userDoc.data();
        if (data != null && data.containsKey('dark_mode')) {
          darkMode = data['dark_mode'] ?? 0;
        }
      }
      // Gọi callback để cập nhật giao diện
      if (widget.onDarkModeChanged != null) {
        widget.onDarkModeChanged!(darkMode);
      }
      setState(() {
        _user = userModel;
        _avatarUrl = avatarUrl ?? userModel?.avatar;
        _checkingSignIn = false;
      });
      await _fetchUserMails(); // Thêm dòng này
    }
  }

  Future<void> _saveUserToPrefs(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', user.email);
  }

  Future<String?> _getAvatarUrl({String? email, String? phone}) async {
    final firestore = FirebaseFirestore.instance;
    QuerySnapshot<Map<String, dynamic>> snap;
    if (email != null && email.isNotEmpty) {
      snap = await firestore.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (snap.docs.isNotEmpty && snap.docs.first.data()['avatar'] != null && snap.docs.first.data()['avatar'].toString().isNotEmpty) {
        return snap.docs.first.data()['avatar'];
      }
    }
    if (phone != null && phone.isNotEmpty) {
      snap = await firestore.collection('users').where('phone', isEqualTo: phone).limit(1).get();
      if (snap.docs.isNotEmpty && snap.docs.first.data()['avatar'] != null && snap.docs.first.data()['avatar'].toString().isNotEmpty) {
        return snap.docs.first.data()['avatar'];
      }
    }
    return null;
  }

  Future<void> _autoSignIn() async {
    setState(() => _checkingSignIn = true);
  
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final userModel = await _controller.getUserByEmail(firebaseUser.email!);
      final avatarUrl = await _getAvatarUrl(email: firebaseUser.email, phone: userModel?.phone);
      int darkMode = 0;
      if (userModel != null && userModel.id != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userModel.id).get();
        final data = userDoc.data();
        if (data != null && data.containsKey('dark_mode')) {
          darkMode = data['dark_mode'] ?? 0;
        }
      }
      // Gọi callback để cập nhật giao diện
      if (widget.onDarkModeChanged != null) {
        widget.onDarkModeChanged!(darkMode);
      }
      setState(() {
        _user = userModel;
        _avatarUrl = avatarUrl ?? firebaseUser.photoURL;
        _checkingSignIn = false;
      });
      if (userModel != null && userModel.id != null) {
        await _ensureUserExtraFields(userModel.id!);
      }
      // Cập nhật FCM token cho Android
      if (!kIsWeb && _user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.id)
              .update({'fcmTokenAndroid': token});
        }
      }
      if (kIsWeb && _user != null) {
        if (_fcmToken == null) {
          // Lấy lại token nếu chưa có
          final messaging = FirebaseMessaging.instance;
          _fcmToken = await messaging.getToken(
            vapidKey: 'BA2jAWCkhjXZ9gmCjUC9dBlF7XnHC2hwI6_dhXHh8O4djsMHWCTDTcnSCw_e-5bou4ZSdrztk50Fo9cpk4TTrTE',
          );
        }
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.id)
              .update({'fcmTokenWeb': _fcmToken});
        }
      }
      await _fetchUserMails();
      return;
    }
  
    // WEB: thử signInSilently để lấy lại phiên Google
    if (kIsWeb) {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        final userModel = await _controller.getUserByEmail(googleUser.email);
        final avatarUrl = await _getAvatarUrl(email: googleUser.email, phone: userModel?.phone);
        int darkMode = 0;
        if (userModel != null && userModel.id != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userModel.id).get();
          final data = userDoc.data();
          if (data != null && data.containsKey('dark_mode')) {
            darkMode = data['dark_mode'] ?? 0;
          }
        }
        if (widget.onDarkModeChanged != null) {
          widget.onDarkModeChanged!(darkMode);
        }
        setState(() {
          _user = userModel;
          _avatarUrl = avatarUrl ?? googleUser.photoUrl;
          _checkingSignIn = false;
        });
        // Đảm bảo các trường mới luôn tồn tại
        if (userModel != null && userModel.id != null) {
          await _ensureUserExtraFields(userModel.id!);
        }
        // Lưu số điện thoại nếu có
        final prefs = await SharedPreferences.getInstance();
        if (userModel?.phone != null && userModel!.phone!.isNotEmpty) {
          await prefs.setString('user_phone', userModel.phone!);
        } else {
          await prefs.remove('user_phone');
        }
        return;
      }
    }
  
    // Nếu không có firebaseUser và không còn phiên Google, thử lấy số điện thoại từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone');
    if (phone != null && phone.isNotEmpty) {
      final userModel = await _controller.getUserByPhone(phone);
      final avatarUrl = await _getAvatarUrl(phone: phone, email: userModel?.email);
      int darkMode = 0;
      if (userModel != null && userModel.id != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userModel.id).get();
        final data = userDoc.data();
        if (data != null && data.containsKey('dark_mode')) {
          darkMode = data['dark_mode'] ?? 0;
        }
      }
      if (widget.onDarkModeChanged != null) {
        widget.onDarkModeChanged!(darkMode);
      }
      setState(() {
        _user = userModel;
        _avatarUrl = avatarUrl ?? userModel?.avatar;
        _checkingSignIn = false;
      });
      // Đảm bảo các trường mới luôn tồn tại
      if (userModel != null && userModel.id != null) {
        await _ensureUserExtraFields(userModel.id!);
      }
      // Cập nhật FCM token cho Android
      if (!kIsWeb && _user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.id)
              .update({'fcmTokenAndroid': token});
        }
      }
      return;
    }
  
    setState(() {
      _checkingSignIn = false;
    });
  }
  Future<String?> _downloadAndSaveAvatarToStorage(String googleAvatarUrl, String userId) async {
    try {
      // Tải ảnh từ Google
      final response = await http.get(Uri.parse(googleAvatarUrl));
      if (response.statusCode == 200) {
        // Upload lên Firebase Storage
        final ref = FirebaseStorage.instance.ref().child('avatars/$userId.jpg');
        await ref.putData(response.bodyBytes, SettableMetadata(contentType: 'image/jpeg'));
        // Lấy URL public
        final url = await ref.getDownloadURL();
        // Cập nhật Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).update({'avatar': url});
        return url;
      }
    } catch (e) {
      // ignore error, dùng fallback
    }
    return null;
  }
        // ...existing code...
    
    // Thêm vào class _GmailHomePageState:
            // ...existing code...
      
      // Thay thế hàm _promptForPhoneNumber bằng phiên bản dưới đây:
            Future<String?> _promptForPhoneNumber(BuildContext context) async {
        final controller = TextEditingController();
        String? error;
        String? otp;
        bool isSending = false;
        bool otpSent = false;
      
        Future<bool> sendOtp(String phone) async {
          final infobipApiKey = 'db1b0428ef0888b2aa9a394e6b456c7b-7eaa071c-0023-4f0d-a43c-1f70832cfa13';
          final infobipBaseUrl = 'https://8k6kwr.api.infobip.com';
          otp = (Random().nextInt(900000) + 100000).toString();
          final otpSpaced = otp!.split('').join(' ');
      
          // Định dạng số điện thoại về dạng quốc tế (bỏ dấu +, luôn là 84xxxxxxxxx)
          String formattedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
          if (formattedPhone.startsWith('0')) {
            formattedPhone = '84${formattedPhone.substring(1)}';
          } else if (formattedPhone.startsWith('84')) {
            // giữ nguyên
          } else if (formattedPhone.length == 9) {
            formattedPhone = '84$formattedPhone';
          } else {
            // Nếu nhập số khác, có thể xử lý thêm tùy yêu cầu
          }
          print('Gửi OTP voice tới: $formattedPhone');
      
          final voiceUrl = Uri.parse('$infobipBaseUrl/tts/3/advanced');
          final voiceBody = jsonEncode({
            "messages": [
              {
                "destinations": [
                  {"to": formattedPhone}
                ],
                "language": "vi",
                "text": "Mã OTP xác thực số điện thoại của bạn là: $otpSpaced. Xin vui lòng nhập mã này để xác thực."
              }
            ]
          });
      
          try {
            final response = await http.post(
              voiceUrl,
              headers: {
                'Authorization': 'App $infobipApiKey',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: voiceBody,
            );
            print('Infobip Voice response: ${response.statusCode} - ${response.body}');
            return response.statusCode >= 200 && response.statusCode < 300;
          } catch (e) {
            print('Lỗi gửi OTP voice: $e');
            return false;
          }
        }
      
        return await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                return AlertDialog(
                  title: const Text('Nhập số điện thoại'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại',
                          errorText: error,
                        ),
                        enabled: !isSending,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng nhập số điện thoại để hoàn tất đăng nhập.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(null);
                      },
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              final phone = controller.text.trim();
                              if (phone.isEmpty || phone.length < 8) {
                                setState(() => error = 'Số điện thoại không hợp lệ');
                                return;
                              }
                              setState(() {
                                error = null;
                                isSending = true;
                              });
                              final sent = await sendOtp(phone);
                              setState(() {
                                isSending = false;
                                otpSent = sent;
                              });
                              // Luôn cho phép nhập OTP, nếu gửi thất bại thì cho nhập 000000
                              final otpController = TextEditingController();
                              String? otpErrorLocal;
                              bool isVerifyingOtp = false;
                              final result = await showDialog<bool>(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (otpCtx) {
                                  return StatefulBuilder(
                                    builder: (otpCtx, setOtpState) {
                                      return AlertDialog(
                                        title: const Text('Xác thực OTP qua Voice Call'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              otpSent
                                                  ? 'Hệ thống sẽ gọi đến số $phone và đọc mã OTP. Vui lòng nghe máy và nhập mã OTP.'
                                                  : 'Không gửi được OTP, hãy nhập "000000" để xác thực hoặc nhập mã OTP nếu bạn nhận được.',
                                            ),
                                            TextField(
                                              controller: otpController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Mã OTP',
                                                hintText: 'Hãy nhập vào 000000 nếu không nhận được mã otp',
                                              ),
                                            ),
                                            if (otpErrorLocal != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  otpErrorLocal ?? '',
                                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                                ),
                                              ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(otpCtx).pop(false);
                                            },
                                            child: const Text('Hủy'),
                                          ),
                                          ElevatedButton(
                                            onPressed: isVerifyingOtp
                                                ? null
                                                : () {
                                                    setOtpState(() {
                                                      isVerifyingOtp = true;
                                                    });
                                                    final enteredOtp = otpController.text.trim();
                                                    if ((otpSent && enteredOtp == otp) || enteredOtp == '000000') {
                                                      Navigator.of(otpCtx).pop(true);
                                                    } else {
                                                      setOtpState(() {
                                                        otpErrorLocal = 'Mã OTP không đúng!';
                                                        isVerifyingOtp = false;
                                                      });
                                                    }
                                                  },
                                            child: const Text('Xác nhận'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                              if (result == true) {
                                Navigator.of(ctx).pop(phone);
                              }
                            },
                      child: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Xác thực'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
        Future<void> _handleGoogleSignIn() async {
      setState(() => _checkingSignIn = true);
      final firestore = FirebaseFirestore.instance;
    
      if (kIsWeb) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final query = await firestore
              .collection('users')
              .where('email', isEqualTo: googleUser.email)
              .limit(1)
              .get();
    
          String docId = googleUser.id;
          Map<String, dynamic>? userData;
          if (query.docs.isNotEmpty) {
            // Đã có user với email này (có thể đăng ký bằng số điện thoại trước đó)
            final oldDoc = query.docs.first;
            userData = oldDoc.data();
            // Nếu id khác googleUser.id thì chuyển dữ liệu sang doc mới
            if (oldDoc.id != googleUser.id) {
              // Copy dữ liệu sang doc mới với id là googleUser.id
              await firestore.collection('users').doc(googleUser.id).set({
                ...userData,
                'id': googleUser.id,
                'is_google_account': 1,
                'avatar': googleUser.photoUrl,
              }, SetOptions(merge: true));
    
              // --- BẮT ĐẦU: SỬA DỮ LIỆU LIÊN QUAN ---
              final oldId = oldDoc.id;
              final newId = googleUser.id;
    
              // 1. mails_users: senderId
              final senderMailsUsers = await firestore
                  .collection('mails_users')
                  .where('senderId', isEqualTo: oldId)
                  .get();
              for (var doc in senderMailsUsers.docs) {
                await doc.reference.update({'senderId': newId});
              }
    
              // 2. mails_users: receiverId
              final receiverMailsUsers = await firestore
                  .collection('mails_users')
                  .where('receiverId', isEqualTo: oldId)
                  .get();
              for (var doc in receiverMailsUsers.docs) {
                await doc.reference.update({'receiverId': newId});
              }
    
              // 3. mails: senderId
              final senderMails = await firestore
                  .collection('mails')
                  .where('senderId', isEqualTo: oldId)
                  .get();
              for (var doc in senderMails.docs) {
                await doc.reference.update({'senderId': newId});
              }
    
              // 4. mails: receiverId (chuỗi nhiều id, cách nhau bởi dấu phẩy)
              final mailsWithReceiver = await firestore
                  .collection('mails')
                  .where('receiverId', isGreaterThanOrEqualTo: '')
                  .get();
              for (var doc in mailsWithReceiver.docs) {
                final data = doc.data();
                final receiverIds = (data['receiverId'] ?? '').toString();
                if (receiverIds.split(',').map((e) => e.trim()).contains(oldId)) {
                  final newReceiverIds = receiverIds
                      .split(',')
                      .map((e) => e.trim() == oldId ? newId : e.trim())
                      .join(',');
                  await doc.reference.update({'receiverId': newReceiverIds});
                }
              }
              // --- KẾT THÚC: SỬA DỮ LIỆU LIÊN QUAN ---
    
              // Xóa doc cũ
              await firestore.collection('users').doc(oldDoc.id).delete();
            }
            docId = googleUser.id;
          } else {
            // Chưa có user, tạo mới
            userData = {
              'id': googleUser.id,
              'name': googleUser.displayName,
              'email': googleUser.email,
              'avatar': googleUser.photoUrl,
              'phone': null,
              'password': null,
              'is_google_account': 1,
              'is_2fa_enabled': 1,
              'isAutoReply': false,
              'messageAutoReply': null,
              'finding_by_date': false,
              'finding_attach': false,
              'from_date': null,
              'to_date': null,
              'tag_filter': null,
              'view': 'basic',
              'search': 'basic',
              'notification': true,
              'dark_mode': 0,
              'createdAt': FieldValue.serverTimestamp(),
            };
            await firestore.collection('users').doc(googleUser.id).set(userData);
          }
    
          // Lấy lại userData mới nhất
          final userDoc = await firestore.collection('users').doc(googleUser.id).get();
          userData = userDoc.data();
    
          // Nếu thiếu phone, yêu cầu nhập và xác thực OTP qua Infobip
          if (userData != null && (userData['phone'] == null || userData['phone'].toString().isEmpty)) {
            String? phone;
            do {
              phone = await _promptForPhoneNumber(context);
              if (phone == null) {
                setState(() => _checkingSignIn = false);
                return;
              }
            } while (phone.isEmpty);
            await firestore.collection('users').doc(googleUser.id).update({'phone': phone});
            userData['phone'] = phone;
          }
    
          // Nếu avatar là link Google, tải về Storage và cập nhật lại Firestore
          String? avatarUrl = userData?['avatar'];
          if (avatarUrl != null && avatarUrl.contains('googleusercontent.com')) {
            avatarUrl = await _downloadAndSaveAvatarToStorage(avatarUrl, googleUser.id);
            if (avatarUrl != null) {
              await firestore.collection('users').doc(googleUser.id).update({'avatar': avatarUrl});
              userData?['avatar'] = avatarUrl;
            }
          }
    
          // Đảm bảo các trường bổ sung luôn tồn tại
          final data = userData ?? {};
          Map<String, dynamic> updateData = {};
          if (!data.containsKey('isAutoReply')) updateData['isAutoReply'] = false;
          if (!data.containsKey('messageAutoReply')) updateData['messageAutoReply'] = null;
          if (!data.containsKey('view')) updateData['view'] = 'basic';
          if (!data.containsKey('search')) updateData['search'] = 'basic';
          if (!data.containsKey('notification')) updateData['notification'] = true;
          if (!data.containsKey('dark_mode')) updateData['dark_mode'] = 0;
          if (!data.containsKey('finding_by_date')) updateData['finding_by_date'] = false;
          if (!data.containsKey('finding_attach')) updateData['finding_attach'] = false;
          if (!data.containsKey('from_date')) updateData['from_date'] = null;
          if (!data.containsKey('to_date')) updateData['to_date'] = null;
          if (!data.containsKey('tag_filter')) updateData['tag_filter'] = null;
          if (updateData.isNotEmpty) {
            await firestore.collection('users').doc(googleUser.id).update(updateData);
          }
    
          final prefs = await SharedPreferences.getInstance();
          if (userData?['phone'] != null && userData!['phone'].toString().isNotEmpty) {
            await prefs.setString('user_phone', userData['phone']);
          } else {
            await prefs.remove('user_phone');
          }
          await _saveUserToPrefs(UserModel.fromMap(userData!));
    
          setState(() {
            _user = UserModel.fromMap(userData!);
            _avatarUrl = avatarUrl ?? googleUser.photoUrl;
            _checkingSignIn = false;
          });
    
          // Lưu token cho Web
          if (_user != null) {
            if (_fcmToken == null || _fcmToken!.isEmpty) {
              final messaging = FirebaseMessaging.instance;
              _fcmToken = await messaging.getToken(
                vapidKey: 'BA2jAWCkhjXZ9gmCjUC9dBlF7XnHC2hwI6_dhXHh8O4djsMHWCTDTcnSCw_e-5bou4ZSdrztk50Fo9cpk4TTrTE',
              );
            }
            if (_fcmToken != null && _fcmToken!.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_user!.id)
                  .update({'fcmTokenWeb': _fcmToken});
            }
          }
          await _fetchUserMails();
        } else {
          setState(() {
            _checkingSignIn = false;
          });
        }
      } else {
        // Mobile: tương tự, kiểm tra email trước khi tạo user mới
        final user = await _controller.signInWithGoogle();
        if (user != null) {
          final query = await firestore
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          String userId = user.id!;
          Map<String, dynamic>? data;
          if (query.docs.isNotEmpty) {
            final oldDoc = query.docs.first;
            data = oldDoc.data();
            if (oldDoc.id != user.id) {
              await firestore.collection('users').doc(user.id).set({
                ...data,
                'id': user.id,
                'is_google_account': 1,
                'avatar': user.avatar,
              }, SetOptions(merge: true));
    
              // --- BẮT ĐẦU: SỬA DỮ LIỆU LIÊN QUAN ---
              final oldId = oldDoc.id;
              final newId = user.id!;
    
              // 1. mails_users: senderId
              final senderMailsUsers = await firestore
                  .collection('mails_users')
                  .where('senderId', isEqualTo: oldId)
                  .get();
              for (var doc in senderMailsUsers.docs) {
                await doc.reference.update({'senderId': newId});
              }
    
              // 2. mails_users: receiverId
              final receiverMailsUsers = await firestore
                  .collection('mails_users')
                  .where('receiverId', isEqualTo: oldId)
                  .get();
              for (var doc in receiverMailsUsers.docs) {
                await doc.reference.update({'receiverId': newId});
              }
    
              // 3. mails: senderId
              final senderMails = await firestore
                  .collection('mails')
                  .where('senderId', isEqualTo: oldId)
                  .get();
              for (var doc in senderMails.docs) {
                await doc.reference.update({'senderId': newId});
              }
    
              // 4. mails: receiverId (chuỗi nhiều id, cách nhau bởi dấu phẩy)
              final mailsWithReceiver = await firestore
                  .collection('mails')
                  .where('receiverId', isGreaterThanOrEqualTo: '')
                  .get();
              for (var doc in mailsWithReceiver.docs) {
                final data = doc.data();
                final receiverIds = (data['receiverId'] ?? '').toString();
                if (receiverIds.split(',').map((e) => e.trim()).contains(oldId)) {
                  final newReceiverIds = receiverIds
                      .split(',')
                      .map((e) => e.trim() == oldId ? newId : e.trim())
                      .join(',');
                  await doc.reference.update({'receiverId': newReceiverIds});
                }
              }
              // --- KẾT THÚC: SỬA DỮ LIỆU LIÊN QUAN ---
    
              await firestore.collection('users').doc(oldDoc.id).delete();
            }
            userId = user.id!;
          } else {
            data = user.toMap();
            await firestore.collection('users').doc(user.id).set(data);
          }
    
          // Nếu thiếu phone, yêu cầu nhập và xác thực OTP qua Infobip
          if ((data['phone'] == null || (data['phone'] as String).isEmpty)) {
            String? phone;
            do {
              phone = await _promptForPhoneNumber(context);
              if (phone == null) {
                setState(() => _checkingSignIn = false);
                return;
              }
            } while (phone.isEmpty);
            await firestore.collection('users').doc(userId).update({'phone': phone});
            data['phone'] = phone;
          }
    
          // Nếu avatar là link Google, tải về Storage và cập nhật lại Firestore
          String? avatarUrl = data['avatar'];
          if (avatarUrl != null && avatarUrl.contains('googleusercontent.com')) {
            avatarUrl = await _downloadAndSaveAvatarToStorage(avatarUrl, userId);
            if (avatarUrl != null) {
              await firestore.collection('users').doc(userId).update({'avatar': avatarUrl});
              data['avatar'] = avatarUrl;
            }
          }
    
          // Đảm bảo các trường bổ sung luôn tồn tại
          Map<String, dynamic> updateData = {};
          if (!data.containsKey('isAutoReply')) updateData['isAutoReply'] = false;
          if (!data.containsKey('messageAutoReply')) updateData['messageAutoReply'] = null;
          if (!data.containsKey('view')) updateData['view'] = 'basic';
          if (!data.containsKey('search')) updateData['search'] = 'basic';
          if (!data.containsKey('notification')) updateData['notification'] = true;
          if (!data.containsKey('dark_mode')) updateData['dark_mode'] = 0;
          if (!data.containsKey('finding_by_date')) updateData['finding_by_date'] = false;
          if (!data.containsKey('finding_attach')) updateData['finding_attach'] = false;
          if (!data.containsKey('from_date')) updateData['from_date'] = null;
          if (!data.containsKey('to_date')) updateData['to_date'] = null;
          if (!data.containsKey('tag_filter')) updateData['tag_filter'] = null;
          if (updateData.isNotEmpty) {
            await firestore.collection('users').doc(userId).update(updateData);
          }
    
          await _saveUserToPrefs(UserModel.fromMap(data));
          setState(() {
            _user = UserModel.fromMap(data!);
            _avatarUrl = avatarUrl ?? user.avatar;
            _checkingSignIn = false;
          });
    
          // Lưu FCM token cho Android
          if (_user != null) {
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null && token.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_user!.id)
                  .update({'fcmTokenAndroid': token});
            }
          }
          await _fetchUserMails();
        } else {
          setState(() {
            _checkingSignIn = false;
          });
        }
      }
    }
    // ...existing code...
    // ...existing code...
    void _handlePhoneRegister() async {
      final userData = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhoneRegisterScreen()),
      );
      if (userData != null) {
        final avatarUrl = await _getAvatarUrl(
          email: userData['email'],
          phone: userData['phone'],
        );
        final userModel = UserModel(
          id: userData['id'],
          name: userData['name'] ?? '',
          email: userData['email'] ?? '',
          phone: userData['phone'] ?? '',
          avatar: avatarUrl,
          password: userData['password'] ?? '',
          isGoogleAccount: userData['isGoogleAccount'] == 1 ? 1 : 0,
          is2FAEnabled: userData['is2FAEnabled'] == 1 ? 1 : 0,
          isAutoReply: userData['isAutoReply'] == true,
          messageAutoReply: userData['messageAutoReply'],
        );
        setState(() {
          _user = userModel;
          _avatarUrl = avatarUrl;
        });
        await _saveUserToPrefs(userModel);
        final prefs = await SharedPreferences.getInstance();
        if (userModel.phone != null && userModel.phone!.isNotEmpty) {
          await prefs.setString('user_phone', userModel.phone!);
        }
        await _fetchUserMails();
      }
    }
   // Khi sign out, xóa local:
  void _handleSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    // Đăng xuất Google nếu có
    if (kIsWeb) {
      await _googleSignIn.signOut();
    }
    setState(() {
      _user = null;
      _avatarUrl = null;
      _allPreviousMailIds = {}; // reset lại
    });
  }

    @override
  Widget build(BuildContext context) {
    if (_checkingSignIn) {
      // Thay thế loading mặc định bằng hiệu ứng Lottie loading.json
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Lottie.asset(
            'assets/loading.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      );
    }
    if (_user == null) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/gmail_logo.png',
                        width: 56,
                        height: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chào mừng bạn đến với Gmail Clone',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Đăng nhập hoặc đăng ký để tiếp tục sử dụng dịch vụ email hiện đại, bảo mật và tiện lợi.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Đăng nhập với Google', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleGoogleSignIn,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('hoặc', style: TextStyle(color: Colors.grey[400])),
                      ),
                      const Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text('Đăng nhập hoặc đăng ký bằng số điện thoại', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 120, 158, 176),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handlePhoneRegister,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  
    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Column(
          children: [
                        // ...existing code...
            Container(
              height: 48.0,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: widget.darkMode == 0
                    ? LinearGradient(
                        colors: [const Color.fromARGB(255, 185, 185, 185), const Color.fromARGB(255, 210, 209, 209)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [const Color.fromARGB(255, 46, 46, 46), const Color.fromARGB(255, 104, 104, 104)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.darkMode == 0
                        ? Colors.grey.withOpacity(0.2)
                        : const Color.fromRGBO(0, 0, 0, 0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ),
                  // --- Thay thế Text bằng TextField search ---
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _searchController,
                          style: TextStyle(
                            color: widget.darkMode == 0 ? Colors.black : Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search in mail',
                            hintStyle: TextStyle(
                              color: widget.darkMode == 0 ? Colors.grey[700] : Colors.grey,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {}); // Để rebuild hiệu ứng khi gõ
                            if (value.trim().isEmpty) {
                              setState(() {
                                _showSearchResults = false;
                                _searchResults = [];
                              });
                            } else {
                              _searchMails(value.trim());
                            }
                          },
                        ),
                        if (_searchController.text.isNotEmpty)
                          AnimatedOpacity(
                            opacity: _isSearching ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Đang tìm kiếm...",
                                  style: TextStyle(
                                    color: widget.darkMode == 0 ? Colors.grey[700] : Colors.grey,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Nút cài đặt
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Cài đặt',
                    onPressed: () async {
                      if (_user == null) return;
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.id).get();
                      final data = userDoc.data() ?? {};
                      String view = data['view'] ?? 'basic';
                      String search = data['search'] ?? 'basic';
                      bool notification = data['notification'] ?? true;
                      int darkMode = data['dark_mode'] ?? 0;
                      if (widget.onDarkModeChanged != null) {
                        widget.onDarkModeChanged!(darkMode);
                      }
            
                                            // ...existing code...
                      await showDialog(
                        context: context,
                        builder: (context) {
                          String tempView = view;
                          String tempSearch = search;
                          bool tempNotification = notification;
                          int tempDarkMode = darkMode;
                      
                          // Lấy các trường nâng cao nếu có
                          bool tempFindingByDate = data['finding_by_date'] ?? false;
                          bool tempFindingAttach = data['finding_attach'] ?? false;
                          DateTime? tempFromDate = data['from_date'] != null
                              ? (data['from_date'] is Timestamp
                                  ? (data['from_date'] as Timestamp).toDate()
                                  : DateTime.tryParse(data['from_date'].toString()))
                              : null;
                          DateTime? tempToDate = data['to_date'] != null
                              ? (data['to_date'] is Timestamp
                                  ? (data['to_date'] as Timestamp).toDate()
                                  : DateTime.tryParse(data['to_date'].toString()))
                              : null;
                      
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('Cài đặt tài khoản'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: tempView,
                                        decoration: const InputDecoration(labelText: 'Giao diện (view)'),
                                        items: const [
                                          DropdownMenuItem(value: 'basic', child: Text('Basic')),
                                          DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                                        ],
                                        onChanged: (v) => setState(() => tempView = v ?? 'basic'),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        value: tempSearch,
                                        decoration: const InputDecoration(labelText: 'Tìm kiếm (search)'),
                                        items: const [
                                          DropdownMenuItem(value: 'basic', child: Text('Basic')),
                                          DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                                        ],
                                        onChanged: (v) => setState(() => tempSearch = v ?? 'basic'),
                                      ),
                                      const SizedBox(height: 12),
                                      SwitchListTile(
                                        title: const Text('Nhận thông báo (notification)'),
                                        value: tempNotification,
                                        onChanged: (v) => setState(() => tempNotification = v),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int>(
                                        value: tempDarkMode,
                                        decoration: const InputDecoration(labelText: 'Chế độ nền tối (dark_mode)'),
                                        items: const [
                                          DropdownMenuItem(value: 0, child: Text('Tắt')),
                                          DropdownMenuItem(value: 1, child: Text('Bật')),
                                          DropdownMenuItem(value: 2, child: Text('Hệ thống')), // Thêm dòng này
                                        ],
                                        onChanged: (v) => setState(() => tempDarkMode = v ?? 0),
                                      ),
                                      // --- Bổ sung phần nâng cao ---
                                      if (tempSearch == 'advanced') ...[
                                        const SizedBox(height: 16),
                                        SwitchListTile(
                                          title: const Text('Tìm kiếm theo tệp đính kèm (finding_attach)'),
                                          value: tempFindingAttach,
                                          onChanged: (v) => setState(() => tempFindingAttach = v),
                                        ),
                                        SwitchListTile(
                                          title: const Text('Tìm kiếm theo ngày tháng (finding_by_date)'),
                                          value: tempFindingByDate,
                                          onChanged: (v) => setState(() => tempFindingByDate = v),
                                        ),
                                        if (tempFindingByDate) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () async {
                                                    final picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: tempFromDate ?? DateTime.now(),
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                    if (picked != null) {
                                                      setState(() => tempFromDate = picked);
                                                    }
                                                  },
                                                  child: InputDecorator(
                                                    decoration: const InputDecoration(
                                                      labelText: 'Từ ngày (from_date)',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    child: Text(
                                                      tempFromDate != null
                                                          ? "${tempFromDate!.day}/${tempFromDate!.month}/${tempFromDate!.year}"
                                                          : 'Chọn ngày',
                                                      style: TextStyle(
                                                        color: Colors.white, // Luôn màu trắng
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () async {
                                                    final picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: tempToDate ?? DateTime.now(),
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                    if (picked != null) {
                                                      setState(() => tempToDate = picked);
                                                    }
                                                  },
                                                  child: InputDecorator(
                                                    decoration: const InputDecoration(
                                                      labelText: 'Đến ngày (to_date)',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    child: Text(
                                                      tempToDate != null
                                                          ? "${tempToDate!.day}/${tempToDate!.month}/${tempToDate!.year}"
                                                          : 'Chọn ngày',
                                                      style: TextStyle(
                                                         color: Colors.white, // Luôn màu trắng
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (_user != null && _user!.id != null) {
                                                                                showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => Center(
                                            child: Lottie.asset(
                                              'assets/save.json',
                                              width: 300,
                                              height: 300,
                                              fit: BoxFit.contain,
                                              repeat: false,
                                              animate: true,
                                              options: LottieOptions(enableMergePaths: true),
                                            ),
                                          ),
                                        );
                                        // Đợi hiệu ứng save.json chạy đủ 5 giây trước khi tiếp tục
                                        await Future.delayed(const Duration(milliseconds: 2000));
                                        final updateData = {
                                          'view': tempView,
                                          'search': tempSearch,
                                          'notification': tempNotification,
                                          'dark_mode': tempDarkMode,
                                        };
                                        if (tempSearch == 'advanced') {
                                          updateData['finding_by_date'] = tempFindingByDate;
                                          updateData['finding_attach'] = tempFindingAttach;
                                          updateData['from_date'] = tempFindingByDate && tempFromDate != null
                                              ? Timestamp.fromDate(tempFromDate!)
                                              : FieldValue.delete();
                                          updateData['to_date'] = tempFindingByDate && tempToDate != null
                                              ? Timestamp.fromDate(tempToDate!)
                                              : FieldValue.delete();
                                        } else {
                                          updateData['finding_by_date'] = false;
                                          updateData['finding_attach'] = false;
                                          updateData['from_date'] = FieldValue.delete();
                                          updateData['to_date'] = FieldValue.delete();
                                        }
                                        await FirebaseFirestore.instance.collection('users').doc(_user!.id).update(updateData);
                                        if (widget.onDarkModeChanged != null) {
                                          widget.onDarkModeChanged!(tempDarkMode);
                                        }
                                        if (Navigator.canPop(context)) Navigator.pop(context);
                                        if (mounted) {
                                          Navigator.of(context, rootNavigator: true).pop(); // Đóng hiệu ứng save
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Đã lưu cài đặt!')),
                                          );
                                          await _fetchUserMails();
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Không tìm thấy thông tin tài khoản!')),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Lưu'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                      // ...existing code...
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: IconButton(
                      icon: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? Image.network(
                                _avatarUrl!,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/avatar.jpg',
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : Image.asset(
                                'assets/avatar.jpg',
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                              ),
                      ),
                      onPressed: () async {
                        if (_user != null) {
                          final updatedUser = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserInfoScreen(
                                user: _user!,
                                onSave: (user) async {
                                  setState(() {
                                    _user = user;
                                    _avatarUrl = user.avatar;
                                  });
                                  await _controller.updateUser(user);
                                },
                                onSignOut: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('user_email');
                                  await prefs.remove('user_phone');
                                  if (kIsWeb) {
                                    await _googleSignIn.signOut();
                                  }
                                  setState(() {
                                    _user = null;
                                    _avatarUrl = null;
                                    _allPreviousMailIds = {};
                                  });
                                },
                              ),
                            ),
                          );
                          if (updatedUser != null) {
                            setState(() {
                              _user = updatedUser;
                              _avatarUrl = updatedUser.avatar;
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ...existing code...
            // Hiển thị bảng kết quả tìm kiếm nếu có
        if (_showSearchResults && _searchController.text.isNotEmpty)
          Expanded(
            child: _isSearching
                ? Center(
                    child: Lottie.asset(
                      'assets/loading.json',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  )
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy email phù hợp.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
            : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final mail = _searchResults[index];
                  return ListTile(
                    title: Text(
                      mail['subject'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      mail['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: mail['createdAt'] != null
                        ? Text(
                            mail['createdAt'] is Timestamp
                                ? "${(mail['createdAt'] as Timestamp).toDate().hour}:${(mail['createdAt'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}"
                                : mail['createdAt'].toString(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          )
                        : null,
                    onTap: () async {
                      final userId = _user?.id ?? '';
                      if (userId.isEmpty) return;
                      final mailId = mail['id']?.toString() ?? '';
                      if (mailId.isEmpty) return;

                      // Lấy đúng document id của mails_users
                      final mailsUsersSnap = await FirebaseFirestore
                          .instance
                          .collection('mails_users')
                          .where('mailId', isEqualTo: mailId)
                          .where('receiverId', isEqualTo: userId)
                          .limit(1)
                          .get();
                      String? mailsUsersId;
                      if (mailsUsersSnap.docs.isNotEmpty) {
                        mailsUsersId = mailsUsersSnap.docs.first.id;
                      }
                      if (mailsUsersId != null && mailsUsersId.isNotEmpty) {
                        // Lưu lại mail vừa xem vào SharedPreferences để phục hồi nếu bị văng
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('last_viewed_mail_id', mailId);
                        await prefs.setString('last_viewed_mails_users_id', mailsUsersId);

                        setState(() {
                          _lastViewedMailId = mailId;
                          _lastViewedMailsUsersId = mailsUsersId;
                        });
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MailDetailScreen(
                              mailId: mailsUsersId!,
                              currentUserId: userId,
                              isSent: false,
                              filter: _currentFilter,
                              darkMode: widget.darkMode,
                            ),
                          ),
                        );
                        _searchController.clear();
                        setState(() {
                          _showSearchResults = false;
                        });
                        // Xóa thông tin đã lưu sau khi xem xong
                        await prefs.remove('last_viewed_mail_id');
                        await prefs.remove('last_viewed_mails_users_id');
                      } else {
                        // Nếu không tìm thấy, báo lỗi
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Không tìm thấy thông tin chi tiết email này!')),
                        );
                      }
                    },
                  );
                },
              ),
  )
        else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    _isCategoryFilterActive && _currentCategory != null
                        ? _currentCategory!.substring(0, 1).toUpperCase() + _currentCategory!.substring(1)
                        : _currentFilter == MailFilter.primary
                            ? 'Primary'
                            : _currentFilter == MailFilter.starred
                                ? 'Starred'
                                : _currentFilter == MailFilter.important
                                    ? 'Important'
                                    : _currentFilter == MailFilter.trash
                                        ? 'Trash'
                                        : _currentFilter == MailFilter.spam
                                            ? 'Spam'
                                            : _currentFilter == MailFilter.sent
                                                ? 'Sent'
                                                : _currentFilter == MailFilter.snoozed // Bổ sung dòng này
                                                    ? 'Snoozed'
                                                    : _currentFilter == MailFilter.scheduled
                                                        ? 'Scheduled'
                                                        : _currentFilter == MailFilter.outbox // Bổ sung dòng này
                                                          ? 'Outbox'
                                                          : _currentFilter == MailFilter.drafts
                                                            ? 'Drafts'
                                                            : 'Inbox',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingMails
                  ? Center(
                        child: Lottie.asset(
                          'assets/loading.json',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      )
                  : ListView(
                      children: userMails
                        .where((mail) =>
                          mail['is_snoozed'] != true &&
                          (mail['snoozed_time'] == null ||
                            (mail['snoozed_time'] is DateTime && (mail['snoozed_time'] as DateTime).isBefore(DateTime.now())))
                        )
                        .map((mail) {
                        // ... giữ nguyên phần ListView như cũ ...
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final isDraft = _currentFilter == MailFilter.drafts;
                              final isSent = _currentFilter == MailFilter.sent || _currentFilter == MailFilter.scheduled;
                              if (isDraft) {
                                final mailDoc = await FirebaseFirestore.instance
                                    .collection('mails')
                                    .doc(mail['mailId'])
                                    .get();
                                if (mailDoc.exists) {
                                  final data = mailDoc.data();
                                  dynamic createdAt = data?['createdAt'];
                                  DateTime? createdAtValue;
                                  if (createdAt is Timestamp) {
                                    createdAtValue = createdAt.toDate();
                                  } else if (createdAt is String) {
                                    try {
                                      createdAtValue = DateTime.parse(createdAt);
                                    } catch (_) {}
                                  } else if (createdAt is DateTime) {
                                    createdAtValue = createdAt;
                                  }
                                  dynamic scheduled = data?['scheduled'];
                                  DateTime? scheduledValue;
                                  if (scheduled is Timestamp) {
                                    scheduledValue = scheduled.toDate();
                                  } else if (scheduled is String) {
                                    try {
                                      scheduledValue = DateTime.parse(scheduled);
                                    } catch (_) {}
                                  } else if (scheduled is DateTime) {
                                    scheduledValue = scheduled;
                                  }
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ComposeMailScreen(
                                        senderId: _user?.id,
                                        senderName: _user?.name,
                                        senderEmail: _user?.email,
                                        senderPhone: _user?.phone,
                                      ),
                                      settings: RouteSettings(
                                        arguments: {
                                          'to': data?['input'] ?? '',
                                          'cc': data?['cc'] ?? '',
                                          'bcc': data?['bcc'] ?? '',
                                          'subject': data?['subject'] ?? '',
                                          'styleContent': data?['styleContent'] ?? '',
                                          'previousMailId': data?['id'] ?? '',
                                          'scheduled': scheduledValue,
                                          'createdAt': createdAtValue,
                                        },
                                      ),
                                    ),
                                  );
                                  _fetchUserMails();
                                }
                                return;
                              }
                              if (!isSent && mail['mailsUsersId'] != null) {
                                final docRef = FirebaseFirestore.instance.collection('mails_users').doc(mail['mailsUsersId']);
                                final docSnap = await docRef.get();
                                if (docSnap.exists && (docSnap.data()?['is_read'] != true)) {
                                  await docRef.update({'is_read': true});
                                  // Cập nhật UI ngay lập tức
                                  setState(() {
                                    mail['is_read'] = true;
                                  });
                                }
                              }
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MailDetailScreen(
                                    mailId: isSent ? mail['mailId'] : mail['mailsUsersId'],
                                    currentUserId: _user?.id ?? '',
                                    isSent: isSent,
                                    filter: _currentFilter,
                                    darkMode: widget.darkMode,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchUserMails();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: widget.darkMode == 0 ? const Color.fromARGB(255, 192, 192, 192) : Colors.grey[850], 
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.07),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.09),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                                visualDensity: VisualDensity.compact,
                                titleAlignment: ListTileTitleAlignment.top,
                                leading: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: CircleAvatar(
                                    backgroundColor: widget.darkMode == 0 ? Colors.grey[300] : Colors.grey,
                                    child: mail['avatar'] != null && mail['avatar'] != ''
                                        ? ClipOval(
                                            child: Image.network(
                                              mail['avatar'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Text(
                                                  (mail['sender'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                                  style: TextStyle(
                                                    color: widget.darkMode == 0 ? Colors.black : Colors.white,
                                                    fontSize: 20,
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                        : Text(
                                            (mail['sender'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                            style: TextStyle(
                                              color: widget.darkMode == 0 ? Colors.black : Colors.white,
                                              fontSize: 20,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mail['sender'] ?? '',
                                            style: TextStyle(
                                              color: mail['is_read'] == false
                                                ? (widget.darkMode == 0 ? Colors.black : Colors.white)
                                                : (widget.darkMode == 0 ? Colors.grey[700] : Colors.grey),
                                              fontSize: 16,
                                              fontWeight: mail['is_read'] == false ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            mail['subject'] ?? '',
                                            style: TextStyle(
                                              color: mail['is_read'] == false
                                                ? (widget.darkMode == 0 ? Colors.black : Colors.white)
                                                : (widget.darkMode == 0 ? Colors.grey[700] : Colors.grey),
                                              fontSize: 13,
                                              letterSpacing: 0.1,
                                              fontWeight: mail['is_read'] == false ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (() {
                                              final content = mail['content'] ?? '';
                                              if (_viewMode == 'advanced') {
                                                return content;
                                              }
                                              final screenWidth = MediaQuery.of(context).size.width;
                                              final maxLen = screenWidth < 400 ? 20 : 40;
                                              return content.length > maxLen ? content.substring(0, maxLen) + '...' : content;
                                            })(),
                                            style: TextStyle(
                                              color: mail['is_read'] == false
                                                ? (widget.darkMode == 0 ? Colors.black : Colors.white)
                                                : (widget.darkMode == 0 ? Colors.grey[700] : Colors.grey),
                                              fontSize: 14,
                                              wordSpacing: -0.8,
                                              letterSpacing: -0.4,
                                              fontWeight: mail['is_read'] == false ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            maxLines: _viewMode == 'advanced' ? null : 2, // <-- Sửa dòng này
                                            overflow: _viewMode == 'advanced' ? TextOverflow.visible : TextOverflow.ellipsis, // <-- Sửa dòng này
                                          ),
                                          // Thêm phần này để hiển thị tệp đính kèm nếu searchMode == "advanced"
                                          if ((userMails.isNotEmpty && (mail['attachments'] ?? []).isNotEmpty) && _viewMode == 'advanced')
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Wrap(
                                                spacing: 8,
                                                children: (mail['attachments'] as List)
                                                    .map<Widget>((att) => GestureDetector(
                                                          onTap: () {
                                                            // Mở url tệp đính kèm (cần import url_launcher)
                                                            // launchUrl(Uri.parse(att['url']));
                                                          },
                                                          child: Chip(
                                                            label: Text(att['name'], style: const TextStyle(fontSize: 12)),
                                                            avatar: const Icon(Icons.attach_file, size: 16),
                                                          ),
                                                        ))
                                                    .toList(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          mail['createdAt'] != null
                                              ? (DateTime.tryParse(mail['createdAt']) != null
                                                  ? "${DateTime.parse(mail['createdAt']).hour}:${DateTime.parse(mail['createdAt']).minute.toString().padLeft(2, '0')}"
                                                  : mail['createdAt'].toString())
                                              : '',
                                          style: TextStyle(
                                            color: widget.darkMode == 0 ? Colors.grey[700] : Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Star button luôn hiển thị
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4.0), // Thêm padding trái
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: IconButton(
                                                  icon: Transform.scale(
                                                    scale: 1,
                                                    child: Icon(
                                                      mail['starred'] == true ? Icons.star : Icons.star_border,
                                                      color: Colors.yellow,
                                                    ),
                                                  ),
                                                  constraints: const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () async {
                                                    final mailsUsersId = mail['mailsUsersId'];
                                                    if (mailsUsersId != null) {
                                                      final currentStarred = mail['starred'] == true;
                                                      setState(() {
                                                        mail['starred'] = !currentStarred;
                                                      });
                                                      try {
                                                        await FirebaseFirestore.instance
                                                            .collection('mails_users')
                                                            .doc(mailsUsersId)
                                                            .update({'starred': !currentStarred});
                                                      } catch (e) {
                                                        setState(() {
                                                          mail['starred'] = currentStarred;
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Không thể cập nhật trạng thái star. Vui lòng thử lại!')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                           
                                            const SizedBox(width: 5),
                                            // Nút 3 chấm (PopupMenu) luôn hiển thị ngang hàng với star
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final isSmallScreen = MediaQuery.of(context).size.width < 600;
                                                if (isSmallScreen) {
                                                  return PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                                                    itemBuilder: (context) => [
                                                      PopupMenuItem(
                                                        value: 'snooze',
                                                        child: Row(
                                                          children: const [
                                                            Icon(Icons.snooze, color: Colors.orange, size: 20),
                                                            SizedBox(width: 8),
                                                            Text('Snooze'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'outbox',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.outbox,
                                                              color: mail['is_outbox'] == true ? Colors.deepPurple : Colors.grey,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(mail['is_outbox'] == true ? 'Bỏ khỏi Outbox' : 'Chuyển vào Outbox'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: const [
                                                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                            SizedBox(width: 8),
                                                            Text('Chuyển vào thùng rác'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'spam',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              mail['is_spam'] == true ? Icons.report : Icons.report_gmailerrorred_outlined,
                                                              color: mail['is_spam'] == true ? Colors.orange : Colors.grey,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(mail['is_spam'] == true ? 'Bỏ khỏi Spam' : 'Chuyển vào Spam'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'important',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              mail['important'] == true ? Icons.label_important : Icons.label_important_outline,
                                                              color: Colors.blueAccent,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(mail['important'] == true ? 'Bỏ quan trọng' : 'Đánh dấu quan trọng'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'read',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              mail['is_read'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                                                              color: Colors.green,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(mail['is_read'] == true ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                    onSelected: (value) async {
                                                      final mailsUsersId = mail['mailsUsersId'];
                                                      if (mailsUsersId == null) return;
                                                      if (value == 'delete') {
                                                        await FirebaseFirestore.instance
                                                            .collection('mails_users')
                                                            .doc(mailsUsersId)
                                                            .update({'trash': true});
                                                        setState(() {
                                                          userMails.remove(mail);
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Đã chuyển vào thùng rác')),
                                                        );
                                                      } else if (value == 'spam') {
                                                        final currentSpam = mail['is_spam'] == true;
                                                        await FirebaseFirestore.instance
                                                            .collection('mails_users')
                                                            .doc(mailsUsersId)
                                                            .update({'is_spam': !currentSpam});
                                                        setState(() {
                                                          mail['is_spam'] = !currentSpam;
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              !currentSpam ? 'Đã chuyển vào Spam' : 'Đã bỏ khỏi Spam',
                                                            ),
                                                          ),
                                                        );
                                                        if (_currentFilter == MailFilter.spam && currentSpam) {
                                                          setState(() {
                                                            userMails.remove(mail);
                                                          });
                                                        }
                                                      } else if (value == 'important') {
                                                        final currentImportant = mail['important'] == true;
                                                        setState(() {
                                                          mail['important'] = !currentImportant;
                                                        });
                                                        try {
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({'important': !currentImportant});
                                                        } catch (e) {
                                                          setState(() {
                                                            mail['important'] = currentImportant;
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Không thể cập nhật trạng thái important. Vui lòng thử lại!')),
                                                          );
                                                        }
                                                      } else if (value == 'read') {
                                                        final currentRead = mail['is_read'] == true;
                                                        setState(() {
                                                          mail['is_read'] = !currentRead;
                                                        });
                                                        try {
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({'is_read': !currentRead});
                                                        } catch (e) {
                                                          setState(() {
                                                            mail['is_read'] = currentRead;
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Không thể cập nhật trạng thái đọc. Vui lòng thử lại!')),
                                                          );
                                                        }
                                                      }
                                                      else if (value == 'snooze') {
                                                        final mailsUsersId = mail['mailsUsersId'];
                                                        if (mailsUsersId == null) return;
                                                        if (_currentFilter == MailFilter.snoozed) {
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({
                                                            'is_snoozed': false,
                                                            'snoozed_time': null,
                                                          });
                                                          setState(() {
                                                            mail['is_snoozed'] = false;
                                                            mail['snoozed_time'] = null;
                                                            userMails.remove(mail);
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Đã bỏ snooze email!')),
                                                          );
                                                          await _fetchUserMails(showLoading: false);
                                                          return;
                                                        }
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
                                                        if (selectedSeconds != null && selectedSeconds! > 0)  {
                                                          final snoozedTime = DateTime.now().add(Duration(seconds: selectedSeconds!));
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({
                                                                'is_snoozed': true,
                                                                'snoozed_time': snoozedTime,
                                                              });
                                                          setState(() {
                                                            mail['is_snoozed'] = true;
                                                            mail['snoozed_time'] = snoozedTime;
                                                            userMails.remove(mail);
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Email đã được snooze!')),
                                                          );
                                                          await _fetchUserMails(showLoading: false);
                                                        }
                                                      }
                                                      else if (value == 'outbox') {
                                                        final mailsUsersId = mail['mailsUsersId'];
                                                        if (mailsUsersId == null) return;
                                                        if (_currentFilter == MailFilter.outbox) {
                                                          // Nếu đang ở filter outbox thì bỏ outbox
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({'is_outbox': false});
                                                          setState(() {
                                                            mail['is_outbox'] = false;
                                                            userMails.remove(mail);
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Đã bỏ khỏi Outbox!')),
                                                          );
                                                          await _fetchUserMails(showLoading: false);
                                                        } else {
                                                          // Đánh dấu là outbox
                                                          await FirebaseFirestore.instance
                                                              .collection('mails_users')
                                                              .doc(mailsUsersId)
                                                              .update({'is_outbox': true});
                                                          setState(() {
                                                            mail['is_outbox'] = true;
                                                            userMails.remove(mail);
                                                          });
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Đã chuyển vào Outbox!')),
                                                          );
                                                          await _fetchUserMails(showLoading: false);
                                                        }
                                                      }
                                                    },
                                                  );
                                                } else {
                                                  // Hiển thị các nút như cũ trên màn hình lớn
                                                  return Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // const SizedBox(width: 5),
                                                      Padding(
                                                      padding: const EdgeInsets.only(right: 5.0), // Dịch icon sang trái 4px
                                                      // Nút Snooze
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: IconButton(
                                                          icon: Transform.scale(
                                                            scale: 1,
                                                            child: Icon(Icons.snooze, color: Colors.orange),
                                                          ),
                                                          tooltip: 'Snooze',
                                                          padding: EdgeInsets.zero,
                                                          onPressed: () async {
                                                            final mailsUsersId = mail['mailsUsersId'];
                                                            if (mailsUsersId == null) return;

                                                            // Nếu đang ở filter snoozed thì bỏ snooze
                                                            if (_currentFilter == MailFilter.snoozed) {
                                                              await FirebaseFirestore.instance
                                                                  .collection('mails_users')
                                                                  .doc(mailsUsersId)
                                                                  .update({
                                                                'is_snoozed': false,
                                                                'snoozed_time': null,
                                                              });
                                                              setState(() {
                                                                mail['is_snoozed'] = false;
                                                                mail['snoozed_time'] = null;
                                                                userMails.remove(mail);
                                                              });
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Đã bỏ snooze email!')),
                                                              );
                                                              await _fetchUserMails(showLoading: false); 
                                                              return;
                                                            }

                                                            // Nếu không phải filter snoozed thì snooze như cũ
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
                                                            if (selectedSeconds != null && selectedSeconds! > 0)  {
                                                              final snoozedTime = DateTime.now().add(Duration(seconds: selectedSeconds!));
                                                              await FirebaseFirestore.instance
                                                                  .collection('mails_users')
                                                                  .doc(mailsUsersId)
                                                                  .update({
                                                                    'is_snoozed': true,
                                                                    'snoozed_time': snoozedTime,
                                                                  });
                                                              setState(() {
                                                                mail['is_snoozed'] = true;
                                                                mail['snoozed_time'] = snoozedTime;
                                                                userMails.remove(mail);
                                                              });
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Email đã được snooze!')),
                                                              );
                                                              await _fetchUserMails(showLoading: false); 
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  // Nút Outbox
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 5.0), // Dịch sang trái 5px
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: IconButton(
                                                        icon: Transform.scale(
                                                          scale: 1,
                                                          child: Icon(
                                                            Icons.outbox,
                                                            color: mail['is_outbox'] == true ? Colors.deepPurple : Colors.grey,
                                                          ),
                                                        ),
                                                        tooltip: 'Outbox',
                                                        padding: EdgeInsets.zero,
                                                        onPressed: () async {
                                                          final mailsUsersId = mail['mailsUsersId'];
                                                          if (mailsUsersId == null) return;
                                                          if (_currentFilter == MailFilter.outbox) {
                                                            // Nếu đang ở filter outbox thì bỏ outbox
                                                            await FirebaseFirestore.instance
                                                                .collection('mails_users')
                                                                .doc(mailsUsersId)
                                                                .update({'is_outbox': false});
                                                            setState(() {
                                                              mail['is_outbox'] = false;
                                                              userMails.remove(mail);
                                                            });
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Đã bỏ khỏi Outbox!')),
                                                            );
                                                            await _fetchUserMails(showLoading: false);
                                                          } else {
                                                            // Đánh dấu là outbox
                                                            await FirebaseFirestore.instance
                                                                .collection('mails_users')
                                                                .doc(mailsUsersId)
                                                                .update({'is_outbox': true});
                                                            setState(() {
                                                              mail['is_outbox'] = true;
                                                              userMails.remove(mail);
                                                            });
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Đã chuyển vào Outbox!')),
                                                            );
                                                            await _fetchUserMails(showLoading: false);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                      // Trash button
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: IconButton(
                                                          icon: Transform.scale(
                                                            scale: 1,
                                                            child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                          ),
                                                          constraints: const BoxConstraints(),
                                                          padding: EdgeInsets.zero,
                                                          onPressed: () async {
                                                            final mailsUsersId = mail['mailsUsersId'];
                                                            final mailId = mail['mailId'];
                                                            if (mailsUsersId != null) {
                                                              if (_currentFilter == MailFilter.trash) {
                                                                // Xóa vĩnh viễn: xóa mails_users, mail_attachments, mails
                                                                await FirebaseFirestore.instance.collection('mails_users').doc(mailsUsersId).delete();
                                                                // Xóa file đính kèm
                                                                if (mailId != null) {
                                                                  final attachmentsQuery = await FirebaseFirestore.instance
                                                                      .collection('mail_attachments')
                                                                      .where('mailId', isEqualTo: mailId)
                                                                      .get();
                                                                  for (var doc in attachmentsQuery.docs) {
                                                                    await doc.reference.delete();
                                                                  }
                                                                  // Xóa mail gốc nếu không còn ai nhận
                                                                  final mailsUsersQuery = await FirebaseFirestore.instance
                                                                      .collection('mails_users')
                                                                      .where('mailId', isEqualTo: mailId)
                                                                      .get();
                                                                  if (mailsUsersQuery.docs.isEmpty) {
                                                                    await FirebaseFirestore.instance.collection('mails').doc(mailId).delete();
                                                                  }
                                                                }
                                                                setState(() {
                                                                  userMails.remove(mail);
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(content: Text('Đã xóa vĩnh viễn email!')),
                                                                );
                                                              } else {
                                                                // Chuyển vào thùng rác như cũ
                                                                await FirebaseFirestore.instance
                                                                    .collection('mails_users')
                                                                    .doc(mailsUsersId)
                                                                    .update({'trash': true});
                                                                setState(() {
                                                                  userMails.remove(mail);
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(content: Text('Đã chuyển vào thùng rác')),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      // Spam button
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: IconButton(
                                                          icon: Transform.scale(
                                                            scale: 1,
                                                            child: Icon(
                                                              mail['is_spam'] == true
                                                                  ? Icons.report
                                                                  : Icons.report_gmailerrorred_outlined,
                                                              color: mail['is_spam'] == true ? Colors.orange : Colors.grey,
                                                            ),
                                                          ),
                                                          constraints: const BoxConstraints(),
                                                          padding: EdgeInsets.zero,
                                                          tooltip: 'Spam',
                                                          onPressed: () async {
                                                            final mailsUsersId = mail['mailsUsersId'];
                                                            if (mailsUsersId != null) {
                                                              final currentSpam = mail['is_spam'] == true;
                                                              await FirebaseFirestore.instance
                                                                  .collection('mails_users')
                                                                  .doc(mailsUsersId)
                                                                  .update({'is_spam': !currentSpam});
                                                              setState(() {
                                                                mail['is_spam'] = !currentSpam;
                                                              });
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    !currentSpam ? 'Đã chuyển vào Spam' : 'Đã bỏ khỏi Spam',
                                                                  ),
                                                                ),
                                                              );
                                                              if (_currentFilter == MailFilter.spam && currentSpam) {
                                                                setState(() {
                                                                  userMails.remove(mail);
                                                                });
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      // Important button
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: IconButton(
                                                          icon: Transform.scale(
                                                            scale: 1,
                                                            child: Icon(
                                                              mail['important'] == true ? Icons.label_important : Icons.label_important_outline,
                                                              color: Colors.blueAccent,
                                                            ),
                                                          ),
                                                          constraints: const BoxConstraints(),
                                                          padding: EdgeInsets.zero,
                                                          onPressed: () async {
                                                            final mailsUsersId = mail['mailsUsersId'];
                                                            if (mailsUsersId != null) {
                                                              final currentImportant = mail['important'] == true;
                                                              setState(() {
                                                                mail['important'] = !currentImportant;
                                                                // Nếu đang ở filter Important và vừa bỏ đánh dấu, xóa khỏi danh sách
                                                                if (_currentFilter == MailFilter.important && currentImportant) {
                                                                  userMails.remove(mail);
                                                                }
                                                              });
                                                              try {
                                                                await FirebaseFirestore.instance
                                                                    .collection('mails_users')
                                                                    .doc(mailsUsersId)
                                                                    .update({'important': !currentImportant});
                                                              } catch (e) {
                                                                setState(() {
                                                                  mail['important'] = currentImportant;
                                                                  // Nếu lỗi, thêm lại mail nếu vừa xóa
                                                                  if (_currentFilter == MailFilter.important && currentImportant) {
                                                                    userMails.add(mail);
                                                                  }
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(content: Text('Không thể cập nhật trạng thái important. Vui lòng thử lại!')),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      // Đánh dấu đã đọc/chưa đọc
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: IconButton(
                                                          icon: Transform.scale(
                                                            scale: 1,
                                                            child: Icon(
                                                              mail['is_read'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                                                              color: Colors.green,
                                                            ),
                                                          ),
                                                          constraints: const BoxConstraints(),
                                                          padding: EdgeInsets.zero,
                                                          onPressed: () async {
                                                            final mailsUsersId = mail['mailsUsersId'];
                                                            if (mailsUsersId != null) {
                                                              final currentRead = mail['is_read'] == true;
                                                              setState(() {
                                                                mail['is_read'] = !currentRead;
                                                              });
                                                              try {
                                                                await FirebaseFirestore.instance
                                                                    .collection('mails_users')
                                                                    .doc(mailsUsersId)
                                                                    .update({'is_read': !currentRead});
                                                              } catch (e) {
                                                                setState(() {
                                                                  mail['is_read'] = currentRead;
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(content: Text('Không thể cập nhật trạng thái đọc. Vui lòng thử lại!')),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
              ),
            ],
          ],
        ),
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 90,
              child: DrawerHeader(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/gmail_logo.svg',
                        width: 20,
                        height: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Gmail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          wordSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTileTheme(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 0.5),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.all_inbox, size: 20),
                    title: const Text('All inboxes', style: TextStyle(fontSize: 16)),
                    onTap: () => Navigator.pop(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 70),
                    child: Divider(
                      color: Color.fromRGBO(158, 158, 158, 0.2),
                      thickness: 2,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inbox, size: 20),
                    title: const Text('Primary', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.primary;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, size: 20),
                    title: const Text('Social', style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _isLoadingMails = true;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = true;
                        _currentCategory = 'social'; // hoặc promotions, updates, forums
                      });
                      await _fetchUserMailsByCategory('social');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_offer_outlined, size: 20),
                    title: const Text('Promotions', style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _isLoadingMails = true;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = true;
                        _currentCategory = 'promotions'; // hoặc promotions, updates, forums
                      });
                      await _fetchUserMailsByCategory('promotions');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, size: 20),
                    title: const Text('Updates', style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _isLoadingMails = true;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = true;
                        _currentCategory = 'updates'; // hoặc promotions, updates, forums
                      });
                      await _fetchUserMailsByCategory('updates');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.forum_outlined, size: 20),
                    title: const Text('Forums', style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _isLoadingMails = true;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = true;
                        _currentCategory = 'forums'; // hoặc promotions, updates, forums
                      });
                      await _fetchUserMailsByCategory('forums');
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 70),
                    child: Divider(
                      color: Color.fromRGBO(158, 158, 158, 0.2),
                      thickness: 2,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_border, size: 20),
                    title: const Text('Starred', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.starred;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time, size: 20),
                    title: const Text('Snoozed', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.snoozed;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_important_outline, size: 20),
                    title: const Text('Important', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.important;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.send_outlined, size: 20),
                    title: const Text('Sent', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.sent;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_send_outlined, size: 20),
                    title: const Text('Scheduled', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.scheduled;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.outbox, size: 20),
                    title: const Text('Outbox', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.outbox;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drafts, size: 20),
                    title: const Text('Drafts', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.drafts;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.mail_outlined, size: 20),
                    title: const Text('All mail', style: TextStyle(fontSize: 16)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.report_outlined, size: 20),
                    title: const Text('Spam', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.spam;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outlined, size: 20),
                    title: const Text('Trash', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentFilter = MailFilter.trash;
                        _isTagFilterActive = false;
                        _currentTag = null;
                        _isCategoryFilterActive = false;
                        _currentCategory = null;
                        // _previousMailIds = {};
                        _isLoadingMails = true;
                      });
                      _fetchUserMails();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label, size: 20),
                    title: const Text('Tag', style: TextStyle(fontSize: 16)),
                    trailing: Icon(_showTagFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onTap: () async {
                      if (_user != null) {
                        await _loadTagFilters();
                      }
                      setState(() {
                        _showTagFilters = !_showTagFilters;
                      });
                    },
                  ),
                  if (_showTagFilters)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_tagFilters.isEmpty)
                            const Text('Chưa có tag nào', style: TextStyle(color: Colors.grey)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _tagFilters.map((tag) {
                              return Chip(
                                label: Text(tag),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () async {
                                  final newTags = List<String>.from(_tagFilters)..remove(tag);
                                  await _updateTagFilters(newTags);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tagController,
                                  decoration: const InputDecoration(
                                    hintText: 'Nhập tên tag mới...',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (value) async {
                                    final newTag = value.trim();
                                    if (newTag.isNotEmpty && !_tagFilters.contains(newTag)) {
                                      final newTags = List<String>.from(_tagFilters)..add(newTag);
                                      await _updateTagFilters(newTags);
                                      _tagController.clear();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                                label: const Text('Thêm', style: TextStyle(fontSize: 14, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final newTag = _tagController.text.trim();
                                  if (newTag.isNotEmpty && !_tagFilters.contains(newTag)) {
                                    final newTags = List<String>.from(_tagFilters)..add(newTag);
                                    await _updateTagFilters(newTags);
                                    _tagController.clear();
                                  }
                                },
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Nhập tên tag và nhấn Thêm hoặc Enter',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          // Thay thế phần ListTile tag con như sau:
                          if (_tagFilters.isNotEmpty)
                            Column(
                              children: _tagFilters.map((tag) {
                                return ListTile(
                                  leading: const Icon(Icons.label_outline, size: 18),
                                  title: Text(tag, style: const TextStyle(fontSize: 15)),
                                  selected: _selectedTag == tag,
                                  onTap: () async {
                                    Navigator.pop(context);
                                    setState(() {
                                      _selectedTag = tag;
                                      _isLoadingMails = true;
                                      _isTagFilterActive = true;
                                      _currentTag = tag;
                                      _isCategoryFilterActive = false; // <-- BẮT BUỘC
                                      _currentCategory = null;         // <-- BẮT BUỘC
                                    });
                                    await _fetchMailsByTag(tag);
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(60),
          color: const Color.fromRGBO(48, 49, 51, 1),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
                // ...existing code...
        child: FloatingActionButton.extended(
          onPressed: () async {
            // Tạo bản nháp rỗng trước khi mở màn hình compose
            final mailId = DateTime.now().millisecondsSinceEpoch.toString();
            await FirebaseFirestore.instance.collection('mails').doc(mailId).set({
              'id': mailId,
              'is_drafts': true,
              'createdAt': DateTime.now().toIso8601String(),
              // Có thể thêm các trường khác nếu muốn
            });
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComposeMailScreen(
                  senderId: _user?.id,
                  senderName: _user?.name,
                ),
                settings: RouteSettings(
                  arguments: {
                    'previousMailId': mailId,
                  },
                ),
              ),
            );
            if (result == true) {
              _fetchUserMails();
            }
          },
          icon: Icon(
            Icons.edit_outlined,
            color: widget.darkMode == 0
                ? Colors.red // Light mode: đỏ
                : const Color.fromRGBO(242, 139, 129, 1), // Dark mode: màu cũ
          ),
          label: Text(
            'Compose',
            style: TextStyle(
              color: widget.darkMode == 0
                  ? Colors.red // Light mode: đỏ
                  : const Color.fromRGBO(242, 139, 129, 1), // Dark mode: màu cũ
            ),
          ),
          backgroundColor: widget.darkMode == 0
              ? const Color.fromARGB(255, 219, 218, 218)
              : const Color.fromRGBO(48, 49, 51, 1),
          elevation: 0,
        ),
        // ...existing code...
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.mail,
              color: widget.darkMode == 0
                  ? Colors.red // Light mode: đỏ
                  : const Color.fromRGBO(242, 139, 129, 1), // Dark mode: màu cũ
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.videocam_outlined,
              color: widget.darkMode == 0
                  ? Colors.black87 // Light mode: đen
                  : const Color.fromARGB(255, 188, 188, 188),   // Dark mode: trắng
            ),
            label: "",
          ),
        ],
        backgroundColor: widget.darkMode == 0
            ? const Color.fromARGB(255, 188, 188, 188) // Light mode: nền trắng
            : const Color.fromRGBO(48, 49, 51, 1), // Dark mode: nền cũ
      ),
    );
      }
}