import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<void> insertUser(Map<String, dynamic> user) async {
    await usersCollection.add(user);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final snapshot = await usersCollection.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  // Kiểm tra user theo email đã tồn tại chưa
  Future<bool> userExists(String email) async {
    final query = await usersCollection.where('email', isEqualTo: email).get();
    return query.docs.isNotEmpty;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCURbADuU8iBuXyOQMvQVCMwn5prNfME1o",
        authDomain: "flutter-email-459809.firebaseapp.com",
        projectId: "flutter-email-459809",
        storageBucket: "flutter-email-459809.appspot.com",
        messagingSenderId: "141493579332",
        appId: "1:141493579332:web:1ab696e684c1f3b9781611",
        measurementId: "G-YQPXG9W7QC",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  await syncFromFirebase();
  runApp(MyApp());
}

// Hàm đồng bộ dữ liệu từ Firebase về local (nếu muốn lưu local nữa)
Future<void> syncFromFirebase() async {
  List<Map<String, dynamic>> users = await DatabaseHelper.instance.getUsers();
  // Xử lý dữ liệu nếu cần
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gmail Clone',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[900],
        drawerTheme: DrawerThemeData(backgroundColor: Colors.grey[850]),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
        ),
      ),
      home: GmailHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GmailHomePage extends StatefulWidget {
  const GmailHomePage({super.key});

  @override
  State<GmailHomePage> createState() => _GmailHomePageState();
}

class _GmailHomePageState extends State<GmailHomePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '141493579332-h9nq4qvl7o0h0hm517lapo7gn9crdmst.apps.googleusercontent.com'
        : null,
  );
  GoogleSignInAccount? _currentUser;
  bool _checkingSignIn = true;
  String? _avatarUrl; // Biến này để lưu link avatar

  final List<Map<String, String>> emails = [
    {
      'sender': 'Gamefound',
      'subject': 'New comment reply',
      'message': "There’s a new reply to your comment.",
      'time': '6:13 AM',
      'avatar': 'G'
    },
    {
      'sender': 'Gamefound',
      'subject': 'Update 24 in Lands of Evershade',
      'message': "Pledge Manager is OPEN! TESTING...",
      'time': '2:41 AM',
      'avatar': 'G'
    },
    {
      'sender': 'BoardGameTables.com',
      'subject': 'A shipment from order #241222 is on the way',
      'message': "🚗  Shipped",
      'time': '28 Feb',
      'avatar': 'B'
    },
    {
      'sender': 'Gamefound',
      'subject': 'AR Next: Coming to Gamefound in 2025',
      'message': "War, Agriculture and zombies See all AR Next...",
      'time': '28 Feb',
      'avatar': 'G'
    },
    {
      'sender': 'Gamefound',
      'subject': 'Update 18 in Puerto Rico Special Edition',
      'message': "Development news rk revealed!",
      'time': '27 Feb',
      'avatar': 'G'
    },
    {
      'sender': 'cardservicedesk',
      'subject': 'SAO KÉ TÍCH ĐIỂM HOÀN TIÊN MASTERCARD...',
      'message': "Kính gửi: Quý khách hàng Ngân hàng TMCP H...",
      'time': '22 Feb',
      'avatar': 'C'
    },
    {
      'sender': 'Miniature Market',
      'subject': 'A little gift for your next game n°',
      'message': "Limited-time deal: \$10 off when",
      'time': '22 Feb',
      'avatar': 'M'
    },
  ];

  Color getAvatarColor(String avatar) {
    final Map<String, Color> colorMap = {
      'G': const Color.fromRGBO(160, 66, 244, 1),
      'B': const Color.fromRGBO(251, 187, 1, 1),
      'C': const Color.fromRGBO(52, 167, 83, 1),
      'M': const Color.fromRGBO(233, 30, 99, 1),
    };

    String firstChar = avatar[0].toUpperCase();

    if (colorMap.containsKey(firstChar)) {
      return colorMap[firstChar]!;
    }

    return Colors.grey;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    final user = await _googleSignIn.signInSilently();
    if (user != null) {
      await _fetchAvatarFromDatabase(user.email);
    }
    setState(() {
      _currentUser = user;
      _checkingSignIn = false;
    });
  }

  Future<void> _handleSignIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user != null) {
        await _fetchAvatarFromDatabase(user.email);
        setState(() {
          _currentUser = user;
        });
        final exists = await DatabaseHelper.instance.userExists(user.email);
        if (!exists) {
          await DatabaseHelper.instance.insertUser({
            'name': user.displayName,
            'email': user.email,
            'avatar': user.photoUrl,
            'phone': null,
            'password': null,
            'is_google_account': 1,
            'is_2fa_enabled': 1,
          });
          setState(() {
            _avatarUrl = user.photoUrl;
          });
        }
      }
    } catch (error) {
      print('Google Sign-In error: $error');
    }
  }

  // Lấy avatar từ Firestore
  Future<void> _fetchAvatarFromDatabase(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      setState(() {
        _avatarUrl = data['avatar'] ?? '';
      });
    } else {
      setState(() {
        _avatarUrl = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSignIn) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton.icon(
            icon: Icon(Icons.login),
            label: Text('Đăng nhập với Google'),
            onPressed: _handleSignIn,
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 48.0,
              margin: EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    blurRadius: 5,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: IconButton(
                      icon: Icon(Icons.menu),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ),
                  Expanded(
                    child: Text('Search in mail',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 2.0),
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
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 0.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: emails.map((email) {
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 16, right: 16),
                    visualDensity: VisualDensity.compact,
                    titleAlignment: ListTileTitleAlignment.top,
                    leading: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CircleAvatar(
                        backgroundColor: getAvatarColor(email['avatar']!),
                        child: Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            email['avatar']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                            strutStyle: StrutStyle(
                              forceStrutHeight: true,
                            ),
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
                                email['sender']!,
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                email['subject']!,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                email['message']!,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  wordSpacing: -0.8,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              email['time']!,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            SizedBox(height: 30),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: IconButton(
                                    icon: Transform.scale(
                                      scale: 0.5,
                                      child: Icon(Icons.more_horiz, color: Colors.grey),
                                    ),
                                    constraints: BoxConstraints(),
                                    padding: EdgeInsets.fromLTRB(0, 7.5, 0, 0),
                                    onPressed: () {},
                                  ),
                                ),
                                SizedBox(width: 5),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: IconButton(
                                    icon: Transform.scale(
                                      scale: 1,
                                      child: Icon(Icons.star_border, color: Colors.grey),
                                    ),
                                    constraints: BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 90,
              child: DrawerHeader(
                child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/gmail_logo.svg',
                        width: 20,
                        height: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
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
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 0.5),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.all_inbox,
                      size: 20,
                    ),
                    title: Text('All inboxes', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  Padding(
                    padding:
                        EdgeInsets.only(left: 70),
                    child: Divider(
                      color: Color.fromRGBO(158, 158, 158, 0.2),
                      thickness: 2,
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.inbox,
                      size: 20,
                    ),
                    title: Text('Primary', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.people,
                      size: 20,
                    ),
                    title: Text('Social', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.local_offer_outlined,
                      size: 20,
                    ),
                    title: Text('Promotions', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      size: 20,
                    ),
                    title: Text('Updates', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.forum_outlined,
                      size: 20,
                    ),
                    title: Text('Forums', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  Padding(
                    padding:
                        EdgeInsets.only(left: 70),
                    child: Divider(
                      color: Color.fromRGBO(158, 158, 158, 0.2),
                      thickness: 2,
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.star_border,
                      size: 20,
                    ),
                    title: Text('Starred', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.access_time,
                      size: 20,
                    ),
                    title: Text('Snoozed', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.label_important_outline,
                      size: 20,
                    ),
                    title: Text('Important', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.send_outlined,
                      size: 20,
                    ),
                    title: Text('Sent', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.schedule_send_outlined,
                      size: 20,
                    ),
                    title: Text('Scheduled', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.outbox,
                      size: 20,
                    ),
                    title: Text('Outbox', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.drafts,
                      size: 20,
                    ),
                    title: Text('Drafts', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.mail_outlined,
                      size: 20,
                    ),
                    title: Text('All mail', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.report_outlined,
                      size: 20,
                    ),
                    title: Text('Spam', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outlined,
                      size: 20,
                    ),
                    title: Text('Trash', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                    },
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
          color: Color.fromRGBO(48, 49, 51, 1),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {},
          icon: Icon(Icons.edit_outlined,
              color: Color.fromRGBO(242, 139, 129, 1)),
          label: Text(
            'Compose',
            style: TextStyle(
                color: Color.fromRGBO(242, 139, 129, 1)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.mail, color: Color.fromRGBO(242, 139, 129, 1)),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            label: "",
          ),
        ],
        backgroundColor: Color.fromRGBO(48, 49, 51, 1),
      ),
    );
  }
}