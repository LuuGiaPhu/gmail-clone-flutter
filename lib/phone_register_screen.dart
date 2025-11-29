import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PhoneRegisterScreen extends StatefulWidget {
  const PhoneRegisterScreen({super.key});

  @override
  State<PhoneRegisterScreen> createState() => _PhoneRegisterScreenState();
}

class _PhoneRegisterScreenState extends State<PhoneRegisterScreen> {
  bool isLogin = true;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;

  // Controllers cho đăng nhập
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Controllers cho đăng ký
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerPhoneController = TextEditingController();
  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;

    Future<void> _register() async {
      final email = _registerEmailController.text.trim();
      final phone = _registerPhoneController.text.trim();
      final name = _registerNameController.text.trim();
      final password = _registerPasswordController.text.trim();
    
      if (email.isEmpty || phone.isEmpty || name.isEmpty || password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin!')),
        );
        return;
      }
    
      // Kiểm tra số điện thoại đã tồn tại chưa
      final existingPhone = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();
    
      if (existingPhone.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Số điện thoại đã được đăng ký!')),
        );
        return;
      }
    
      // Kiểm tra email đã tồn tại chưa
      final existingEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
    
      if (existingEmail.docs.isNotEmpty) {
        final userDoc = existingEmail.docs.first;
        final userData = userDoc.data();
        if ((userData['phone'] == null || userData['phone'].toString().isEmpty) ||
            (userData['password'] == null || userData['password'].toString().isEmpty)) {
          try {
            final verifyCode = (Random().nextInt(900000) + 100000).toString();
    
            await _firestore.collection('users').doc(userDoc.id).update({
              if (userData['phone'] == null || userData['phone'].toString().isEmpty) 'phone': phone,
              if (userData['password'] == null || userData['password'].toString().isEmpty) 'password': password,
              'email_verified': false,
              'verify_code': verifyCode,
              if (!userData.containsKey('view')) 'view': 'basic',
              if (!userData.containsKey('search')) 'search': 'basic',
              if (!userData.containsKey('notification')) 'notification': true,
              if (!userData.containsKey('dark_mode')) 'dark_mode': 0,
              if (!userData.containsKey('finding_by_date')) 'finding_by_date': false,
              if (!userData.containsKey('finding_attach')) 'finding_attach': false,
              if (!userData.containsKey('from_date')) 'from_date': null,
              if (!userData.containsKey('to_date')) 'to_date': null,
              if (!userData.containsKey('tag_filter')) 'tag_filter': null,
            });
    
            final url = Uri.parse('https://us-central1-flutter-email-459809.cloudfunctions.net/sendVerifyEmail');
            final response = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email,
                'name': userData['name'] ?? name,
                'userId': userDoc.id,
                'verify_code': verifyCode,
              }),
            );
    
            if (!mounted) return;
            if (response.statusCode == 200) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật thông tin và gửi lại email xác thực!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi gửi email xác thực: ${response.body}')),
              );
            }
    
            setState(() {
              isLogin = true;
              _registerEmailController.clear();
              _registerPhoneController.clear();
              _registerNameController.clear();
              _registerPasswordController.clear();
            });
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi khi cập nhật thông tin: $e')),
            );
          }
          return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email đã được đăng ký!')),
          );
          return;
        }
      }
    
      // Tạo mã OTP
    final otp = (Random().nextInt(900000) + 100000).toString();
    final otpSpaced = otp.split('').join(' '); 

    // Gửi OTP qua Infobip Voice API (Text-to-Speech)
    final infobipApiKey = 'db1b0428ef0888b2aa9a394e6b456c7b-7eaa071c-0023-4f0d-a43c-1f70832cfa13';
    final infobipBaseUrl = 'https://8k6kwr.api.infobip.com';

     // Định dạng số điện thoại về dạng quốc tế (bỏ dấu +, luôn là 84xxxxxxxxx)
    String formattedPhone = phone.trim().replaceAll(RegExp(r'\D'), ''); // chỉ giữ số
    
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '84${formattedPhone.substring(1)}';
    } else if (formattedPhone.startsWith('84')) {
      // giữ nguyên
    } else if (formattedPhone.length == 9) {
      // Nếu người dùng chỉ nhập 9 số cuối (ví dụ: 912345678), thêm 84 vào đầu
      formattedPhone = '84$formattedPhone';
    } else {
      // Nếu nhập số khác, có thể xử lý thêm tùy yêu cầu
    }

    final voiceUrl = Uri.parse('$infobipBaseUrl/tts/3/advanced');
    final voiceBody = jsonEncode({
      "messages": [
        {
          "destinations": [
            {"to": formattedPhone}
          ],
          // "from": "38515507799", // Có thể bỏ nếu không có số đăng ký
          "language": "vi",
          "text": "Mã OTP đăng ký của bạn là: $otpSpaced. Xin vui lòng nhập mã này để xác thực.",
        }
      ]
    });

    bool otpSent = false;
    try {
      final voiceResponse = await http.post(
        voiceUrl,
        headers: {
          'Authorization': 'App $infobipApiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: voiceBody,
      );
      otpSent = voiceResponse.statusCode >= 200 && voiceResponse.statusCode < 300;
      if (!otpSent) {
        print('Voice API error: ${voiceResponse.statusCode} - ${voiceResponse.body}');
      }
    } catch (e) {
      otpSent = false;
      print('Voice API exception: $e');
    }

    // Hiển thị dialog nhập OTP (cho phép nhập 000000 nếu không gửi được OTP)
    String? inputOtp = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
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
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mã OTP',
                      hintText: 'Hãy nhập vào 000000 nếu không nhận được mã otp',
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorText ?? '',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    final enteredOtp = controller.text.trim();
                    if ((otpSent && enteredOtp == otp) || enteredOtp == '000000') {
                      Navigator.pop(context, enteredOtp);
                    } else {
                      setState(() {
                        errorText = 'Mã OTP không đúng!';
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

    if ((otpSent && inputOtp != otp) && inputOtp != '000000') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã OTP không đúng!')),
      );
      return;
    }

    // Đăng ký tài khoản sau khi xác thực OTP thành công
    try {
      final verifyCode = (Random().nextInt(900000) + 100000).toString();
      final docRef = await _firestore.collection('users').add({
        'name': name,
        'email': email,
        'avatar': null,
        'phone': phone,
        'password': password,
        'is_google_account': 0,
        'is_2fa_enabled': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'email_verified': false,
        'verify_code': verifyCode,
        'isAutoReply': false,
        'messageAutoReply': null,
        'total_mail': 0,
        'view': 'basic',
        'search': 'basic',
        'notification': true,
        'dark_mode': 0,
        'finding_by_date': false,
        'finding_attach': false,
        'from_date': null,
        'to_date': null,
        'tag_filter': null,
      });
      await docRef.update({'id': docRef.id});

      // Gửi email xác thực như cũ
      final url = Uri.parse('https://us-central1-flutter-email-459809.cloudfunctions.net/sendVerifyEmail');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'userId': docRef.id,
          'verify_code': verifyCode,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công! Vui lòng kiểm tra email và nhấn vào link xác thực.')),
        );
        setState(() {
          isLogin = true;
          _registerEmailController.clear();
          _registerPhoneController.clear();
          _registerNameController.clear();
          _registerPasswordController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi email xác thực: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng ký: $e')),
      );
    }
  
    
      // Đăng ký tài khoản sau khi xác thực OTP thành công
      try {
        final verifyCode = (Random().nextInt(900000) + 100000).toString();
        final docRef = await _firestore.collection('users').add({
          'name': name,
          'email': email,
          'avatar': null,
          'phone': phone,
          'password': password,
          'is_google_account': 0,
          'is_2fa_enabled': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'email_verified': false,
          'verify_code': verifyCode,
          'isAutoReply': false,
          'messageAutoReply': null,
          'total_mail': 0,
          'view': 'basic',
          'search': 'basic',
          'notification': true,
          'dark_mode': 0,
          'finding_by_date': false,
          'finding_attach': false,
          'from_date': null,
          'to_date': null,
          'tag_filter': null,
        });
        await docRef.update({'id': docRef.id});
    
        // Gửi email xác thực như cũ
        final url = Uri.parse('https://us-central1-flutter-email-459809.cloudfunctions.net/sendVerifyEmail');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'name': name,
            'userId': docRef.id,
            'verify_code': verifyCode,
          }),
        );
    
        if (!mounted) return;
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công! Vui lòng kiểm tra email và nhấn vào link xác thực.')),
          );
          setState(() {
            isLogin = true;
            _registerEmailController.clear();
            _registerPhoneController.clear();
            _registerNameController.clear();
            _registerPasswordController.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi gửi email xác thực: ${response.body}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng ký: $e')),
        );
      }
    }
  // KHÔNG cần _showVerifyDialog nữa

  Future<void> _login() async {
    final phone = _loginPhoneController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại và mật khẩu!')),
      );
      return;
    }

    // Truy vấn Firestore lấy email theo số điện thoại
    final userSnap = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (userSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy tài khoản!')),
      );
      return;
    }

    final userDoc = userSnap.docs.first;
    final userData = userDoc.data();
    final email = userData['email'];
    // Đổi tên biến cho đúng với Firestore: is2FAEnabled
    final is2FAEnabled = userData['is2FAEnabled'] == 1 || userData['is_2fa_enabled'] == 1;
    final isEmailVerified = userData['email_verified'] == true;

    if (!isEmailVerified) {
      // Gửi lại email xác thực
      try {
        final verifyCode = userData['verify_code'] ?? (Random().nextInt(900000) + 100000).toString();
        // Nếu chưa có verify_code thì cập nhật vào Firestore
        if (userData['verify_code'] == null) {
          await _firestore.collection('users').doc(userDoc.id).update({
            'verify_code': verifyCode,
            'email_verified': false,
          });
        }
        final url = Uri.parse('https://us-central1-flutter-email-459809.cloudfunctions.net/sendVerifyEmail');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'name': userData['name'] ?? '',
            'userId': userDoc.id,
            'verify_code': verifyCode,
          }),
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng xác thực email trước khi đăng nhập! Đã gửi lại email xác thực.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi gửi lại email xác thực: ${response.body}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi lại email xác thực: $e')),
        );
      }
      return;
    }

    // Đăng nhập (so sánh password đơn giản, thực tế nên hash)
    if (userData['password'] != password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu không đúng!')),
      );
      return;
    }

    if (!is2FAEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thành công!'),
          duration: Duration(seconds: 2),
        ),
      );
      await _ensureUserExtraFields(userDoc.id);
      Navigator.pop(context, {
        ...userData,
        'id': userDoc.id,
        'email_verified': true,
        'is2FAEnabled': userData['is2FAEnabled'] == 1 || userData['is_2fa_enabled'] == 1 ? 1 : 0,
        'isAutoReply': userData['isAutoReply'] == true || userData['is_auto_reply'] == true,
      });
    } else {
      // Gửi OTP qua Cloud Function
      final otp = (Random().nextInt(900000) + 100000).toString();
      final url = Uri.parse(
        'https://us-central1-flutter-email-459809.cloudfunctions.net/sendOtpMail'
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được mã OTP: ${response.body}')),
        );
        return;
      }

      String? inputOtp = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Xác thực 2 yếu tố'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nhập mã OTP đã gửi về email: $email'),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mã OTP'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      );

      if (inputOtp == otp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            duration: Duration(seconds: 2),
          ),
        );
        await _ensureUserExtraFields(userDoc.id);
        Navigator.pop(context, {
          ...userData,
          'id': userDoc.id,
          'email_verified': true,
          'is2FAEnabled': userData['is2FAEnabled'] == 1 || userData['is_2fa_enabled'] == 1 ? 1 : 0,
          'isAutoReply': userData['isAutoReply'] == true || userData['is_auto_reply'] == true,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã OTP không đúng!')),
        );
      }
    }
  }
  Future<void> _ensureUserExtraFields(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
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
      // Bổ sung trường tag_filter kiểu string nếu thiếu
      if (!data.containsKey('tag_filter')) updateData['tag_filter'] = null;
      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updateData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Đăng nhập' : 'Đăng ký'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ToggleButtons(
                isSelected: [isLogin, !isLogin],
                onPressed: (index) {
                  setState(() {
                    isLogin = index == 0;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.red,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Đăng nhập'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Đăng ký'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (isLogin) ...[
                 TextField(
                  controller: _loginPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginPasswordController,
                  obscureText: _obscureLoginPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureLoginPassword = !_obscureLoginPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                  onPressed: () async {
                    final phone = _loginPhoneController.text.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập số điện thoại để lấy lại mật khẩu!')),
                      );
                      return;
                    }
                    // Tìm user theo phone
                    final userSnap = await _firestore
                        .collection('users')
                        .where('phone', isEqualTo: phone)
                        .limit(1)
                        .get();
                    if (userSnap.docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không tìm thấy tài khoản với số điện thoại này!')),
                      );
                      return;
                    }
                    final userDoc = userSnap.docs.first;
                    final userData = userDoc.data();
                    final email = userData['email'];
                    final name = userData['name'] ?? '';
                    // Tạo mã đặt lại mật khẩu
                    final resetCode = (Random().nextInt(900000) + 100000).toString();
                    await _firestore.collection('users').doc(userDoc.id).update({
                      'reset_code': resetCode,
                    });
                    // Gửi mail đặt lại mật khẩu qua Cloud Function
                    final url = Uri.parse('https://us-central1-flutter-email-459809.cloudfunctions.net/sendResetPasswordMail');
                    final response = await http.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'email': email,
                        'name': name,
                        'reset_code': resetCode,
                      }),
                    );
                    if (response.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã gửi mã đặt lại mật khẩu về email!')),
                      );
                      // Hiển thị dialog nhập mã và mật khẩu mới
                      String? code;
                      String? newPassword;
                      await showDialog(
                        context: context,
                        builder: (context) {
                          final codeController = TextEditingController();
                          final passController = TextEditingController();
                          return AlertDialog(
                            title: const Text('Đặt lại mật khẩu'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Nhập mã đặt lại mật khẩu đã gửi về email và mật khẩu mới.'),
                                TextField(
                                  controller: codeController,
                                  decoration: const InputDecoration(labelText: 'Mã đặt lại mật khẩu'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: passController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () {
                                  code = codeController.text.trim();
                                  newPassword = passController.text.trim();
                                  Navigator.pop(context);
                                },
                                child: const Text('Xác nhận'),
                              ),
                            ],
                          );
                        },
                      );
                      if (code != null && newPassword != null && code!.isNotEmpty && newPassword!.isNotEmpty) {
                        // Kiểm tra mã
                        final userRef = _firestore.collection('users').doc(userDoc.id);
                        final userSnapshot = await userRef.get();
                        final data = userSnapshot.data();
                        if (data != null && data['reset_code'] == code) {
                          await userRef.update({'password': newPassword, 'reset_code': null});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đặt lại mật khẩu thành công!')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mã đặt lại mật khẩu không đúng!')),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi gửi mail: ${response.body}')),
                      );
                    }
                  },
                  child: const Text('Quên mật khẩu?'),
              ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    child: const Text('Đăng nhập'),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _registerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _registerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _registerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _registerPasswordController,
                  obscureText: _obscureRegisterPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureRegisterPassword = !_obscureRegisterPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _register,
                    child: const Text('Đăng ký'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}