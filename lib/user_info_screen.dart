import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_uploader.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Thêm dòng này ở đầu file
class UserInfoScreen extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onSave;
  final VoidCallback? onSignOut;

  const UserInfoScreen({
    super.key,
    required this.user,
    required this.onSave,
    this.onSignOut,
  });

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  late TextEditingController nameController;
  late TextEditingController avatarController;
  late TextEditingController passwordController;
  late TextEditingController phoneController;
  late bool is2FAEnabled;
  late bool isAutoReply;
  late TextEditingController messageAutoReplyController;
  bool _isUploading = false; // Thêm biến trạng thái upload

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name ?? '');
    avatarController = TextEditingController(text: widget.user.avatar ?? '');
    passwordController = TextEditingController(text: widget.user.password ?? '');
    phoneController = TextEditingController(text: widget.user.phone ?? '');
    // Đảm bảo luôn lấy đúng giá trị bool cho Switch
    is2FAEnabled = widget.user.is2FAEnabled == 1 || widget.user.is2FAEnabled == true;
     isAutoReply = widget.user.isAutoReply == true;
    messageAutoReplyController = TextEditingController(text: widget.user.messageAutoReply ?? '');
    print('widget.user.is2FAEnabled: ${widget.user.is2FAEnabled}');
    print('is2FAEnabled in initState: $is2FAEnabled');
  }

  @override
  void dispose() {
    nameController.dispose();
    avatarController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    messageAutoReplyController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _isUploading = true;
    });
    final downloadUrl = await uploadImage();
    if (downloadUrl != null && mounted) {
      setState(() {
        avatarController.text = downloadUrl;
      });
    }
    setState(() {
      _isUploading = false;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    widget.onSignOut?.call();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Switch initial value: $is2FAEnabled');
    return Scaffold(
      appBar: AppBar(title: const Text('User Info')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Center(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: avatarController,
                builder: (context, value, child) {
                  final url = avatarController.text.trim();
                  return CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    child: url.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/avatar.jpg',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          )
                        : Image.asset(
                            'assets/avatar.jpg',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (_isUploading)
              Column(
                children: const [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Đang tải ảnh lên, vui lòng chờ...'),
                  SizedBox(height: 10),
                ],
              ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadImage,
              child: AbsorbPointer(
                child: TextField(
                  controller: avatarController,
                  decoration: InputDecoration(
                    labelText: 'Avatar URL',
                    suffixIcon: Icon(Icons.upload_file,
                        color: _isUploading ? Colors.grey : null),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              enabled: false,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              controller: TextEditingController(text: widget.user.email),
              enabled: false,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Enable 2FA'),
              value: is2FAEnabled,
              onChanged: (val) {
                print('Switch changed: $val');
                setState(() {
                  is2FAEnabled = val;
                  print('is2FAEnabled after setState: $is2FAEnabled');
                });
              },
            ),
            const SizedBox(height: 10),
            // Thêm switch bật/tắt trả lời tự động
            SwitchListTile(
              title: const Text('Bật trả lời tự động'),
              value: isAutoReply,
              onChanged: (val) {
                setState(() {
                  isAutoReply = val;
                });
              },
            ),
            // Nếu bật thì cho nhập nội dung trả lời tự động
            if (isAutoReply)
              TextField(
                controller: messageAutoReplyController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung trả lời tự động',
                  hintText: 'Nhập nội dung trả lời tự động...',
                ),
                maxLines: 2,
              ),
            const SizedBox(height: 20),
                        ElevatedButton(
              onPressed: () async {
                // Kiểm tra nếu mật khẩu đã thay đổi
                final isPasswordChanged = passwordController.text != (widget.user.password ?? '');
                String? newPassword = passwordController.text;
            
                // Nếu có mật khẩu cũ thì mới yêu cầu xác nhận lại
                if (isPasswordChanged && (widget.user.password != null && widget.user.password!.isNotEmpty)) {
                  String? oldPasswordInput = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      final oldPassController = TextEditingController();
                      return AlertDialog(
                        title: const Text('Xác nhận mật khẩu cũ'),
                        content: TextField(
                          controller: oldPassController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nhập mật khẩu cũ',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, oldPassController.text),
                            child: const Text('Xác nhận'),
                          ),
                        ],
                      );
                    },
                  );
            
                  if (oldPasswordInput == null || oldPasswordInput != (widget.user.password ?? '')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mật khẩu cũ không đúng!')),
                    );
                    return;
                  }
                }
            
                final updatedUser = widget.user.copyWith(
                  name: nameController.text,
                  avatar: avatarController.text,
                  password: passwordController.text,
                  is2FAEnabled: is2FAEnabled ? 1 : 0,
                  isAutoReply: isAutoReply,
                  messageAutoReply: isAutoReply ? messageAutoReplyController.text : "",
                );
            
                final firestore = FirebaseFirestore.instance;
                final query = await firestore
                    .collection('users')
                    .where('email', isEqualTo: widget.user.email)
                    .limit(1)
                    .get();
                if (query.docs.isNotEmpty) {
                  await firestore.collection('users').doc(query.docs.first.id).update({
                    'name': updatedUser.name,
                    'avatar': updatedUser.avatar,
                    'password': updatedUser.password,
                    'is_2fa_enabled': updatedUser.is2FAEnabled,
                    'isAutoReply': isAutoReply == true,
                    'messageAutoReply': isAutoReply ? messageAutoReplyController.text : "",
                  });
                }
            
                widget.onSave(updatedUser);
                Navigator.pop(context, updatedUser);
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _signOut,
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}