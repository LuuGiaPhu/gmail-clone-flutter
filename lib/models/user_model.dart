class UserModel {
  final String? id;
  final String? name;
  final String email;
  final String? avatar;
  final String? phone;
  final String? password;
  final int isGoogleAccount;
  final int is2FAEnabled;
  final bool isAutoReply;
  final String? messageAutoReply;
  final int totalMail;
  final String view;
  final String search;
  final bool notification;
  final int darkMode;

  // Thêm các trường mới
  final bool findingByDate;
  final bool findingAttach;
  final DateTime? fromDate;
  final DateTime? toDate;

  // Thêm trường tag_filter kiểu String
  final String? tagFilter;

  UserModel({
    this.id,
    this.name,
    required this.email,
    this.avatar,
    this.phone,
    this.password,
    required this.isGoogleAccount,
    required this.is2FAEnabled,
    this.isAutoReply = false,
    this.messageAutoReply,
    this.totalMail = 0,
    this.view = "basic",
    this.search = "basic",
    this.notification = true,
    this.darkMode = 0,
    this.findingByDate = false,
    this.findingAttach = false,
    this.fromDate,
    this.toDate,
    this.tagFilter, // thêm vào constructor
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final dynamic raw2FA = map['is2FAEnabled'];
    int parsed2FA = 0;
    if (raw2FA is bool) {
      parsed2FA = raw2FA ? 1 : 0;
    } else if (raw2FA is int) {
      parsed2FA = raw2FA;
    }
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      avatar: map['avatar'],
      phone: map['phone'],
      password: map['password'],
      isGoogleAccount: map['isGoogleAccount'] ?? 0,
      is2FAEnabled: parsed2FA,
      isAutoReply: map['isAutoReply'] ?? false,
      messageAutoReply: map['messageAutoReply'],
      totalMail: map['total_mail'] ?? 0,
      view: map['view'] ?? "basic",
      search: map['search'] ?? "basic",
      notification: map['notification'] ?? true,
      darkMode: map['dark_mode'] ?? 0,
      findingByDate: map['finding_by_date'] ?? false,
      findingAttach: map['finding_attach'] ?? false,
      fromDate: map['from_date'] != null
          ? (map['from_date'] is DateTime
              ? map['from_date']
              : DateTime.tryParse(map['from_date'].toString()))
          : null,
      toDate: map['to_date'] != null
          ? (map['to_date'] is DateTime
              ? map['to_date']
              : DateTime.tryParse(map['to_date'].toString()))
          : null,
      tagFilter: map['tag_filter'], // thêm vào fromMap
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'phone': phone,
      'password': password,
      'isGoogleAccount': isGoogleAccount,
      'is2FAEnabled': is2FAEnabled,
      'isAutoReply': isAutoReply,
      'messageAutoReply': messageAutoReply,
      'total_mail': totalMail,
      'view': view,
      'search': search,
      'notification': notification,
      'dark_mode': darkMode,
      'finding_by_date': findingByDate,
      'finding_attach': findingAttach,
      'from_date': fromDate?.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
      'tag_filter': tagFilter, // thêm vào toMap
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    String? phone,
    String? password,
    int? isGoogleAccount,
    int? is2FAEnabled,
    bool? isAutoReply,
    String? messageAutoReply,
    int? totalMail,
    String? view,
    String? search,
    bool? notification,
    int? darkMode,
    bool? findingByDate,
    bool? findingAttach,
    DateTime? fromDate,
    DateTime? toDate,
    String? tagFilter, // thêm vào copyWith
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      isGoogleAccount: isGoogleAccount ?? this.isGoogleAccount,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      isAutoReply: isAutoReply ?? this.isAutoReply,
      messageAutoReply: messageAutoReply ?? this.messageAutoReply,
      totalMail: totalMail ?? this.totalMail,
      view: view ?? this.view,
      search: search ?? this.search,
      notification: notification ?? this.notification,
      darkMode: darkMode ?? this.darkMode,
      findingByDate: findingByDate ?? this.findingByDate,
      findingAttach: findingAttach ?? this.findingAttach,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      tagFilter: tagFilter ?? this.tagFilter, // thêm vào copyWith
    );
  }
}