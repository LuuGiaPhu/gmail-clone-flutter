# Gmail Clone - Flutter Application

A full-featured Gmail clone application built with Flutter, supporting multiple platforms (Android, iOS, Web, Windows, macOS, Linux).

## 🌐 Live Demo

**Web Application:** [https://flutter-email-459809.web.app](https://flutter-email-459809.web.app)

Try the app directly in your browser without any installation!

## 📱 Features

### Core Email Features
- **Email Management**
  - Compose, send, and receive emails
  - Draft management with auto-save
  - Schedule emails for future delivery
  - Rich text editor with formatting options
  - File attachments support (images, documents, etc.)
  
- **Organization**
  - Inbox with primary, social, promotions, updates, and forums categories
  - Starred emails
  - Important emails
  - Spam filtering
  - Trash management
  - Snooze emails
  - Custom tag filters
  - Search functionality (basic and advanced)

### User Features
- **Authentication**
  - Google Sign-In integration
  - Phone number registration
  - Persistent login sessions
  
- **Notifications**
  - Real-time email notifications (Firebase Cloud Messaging)
  - Sound alerts for new emails
  - Foreground and background notification support
  - Web push notifications
  - Customizable notification settings

- **User Interface**
  - Dark mode support
  - Basic and Advanced view modes
  - Responsive design for all platforms
  - Animated splash screen with Lottie
  - Custom fonts and styling

### Advanced Features
- **Search**
  - Basic search (subject and content)
  - Advanced search (with attachments, date range)
  - Tag-based filtering
  - Category-based filtering

- **Data Sync**
  - Real-time data synchronization with Firebase Firestore
  - Auto-refresh every 10 seconds
  - Offline support with local caching (Sembast)

## 🛠️ Tech Stack

### Frontend
- **Flutter SDK**: ^3.6.2
- **Dart**: Latest stable version

### Backend Services
- **Firebase Authentication**: User authentication
- **Firebase Firestore**: NoSQL database for emails and user data
- **Firebase Storage**: File attachments storage
- **Firebase Cloud Messaging**: Push notifications
- **Firebase Functions**: Server-side logic (Node.js)

### Key Packages
- `google_sign_in`: ^6.2.1 - Google authentication
- `firebase_core`: ^2.30.0 - Firebase initialization
- `cloud_firestore`: ^4.17.0 - Firestore database
- `firebase_auth`: ^4.17.4 - Authentication
- `firebase_storage`: ^11.6.6 - File storage
- `firebase_messaging`: ^14.7.10 - Push notifications
- `sembast`: ^3.6.0 & `sembast_web`: ^2.1.0 - Local database
- `flutter_quill`: ^10.8.2 - Rich text editor
- `image_picker`: ^1.0.0 & `file_picker`: ^6.1.1 - File selection
- `flutter_local_notifications`: ^17.1.2 - Local notifications
- `lottie`: ^3.1.0 - Animated splash screen
- `permission_handler`: ^11.3.1 - Permission management
- `shared_preferences`: ^2.2.2 - Local storage

## 📋 Prerequisites

- Flutter SDK (>=3.6.2)
- Dart SDK (>=3.6.2)
- Firebase project setup
- Android Studio / Xcode / VS Code
- Node.js (for Firebase Functions)

## 🚀 Installation

### 1. Clone the repository
```bash
git clone https://github.com/LuuGiaPhu/gmail-clone-flutter.git
cd gmail-clone-flutter
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Firebase Setup

#### a. Create a Firebase project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable the following services:
   - Authentication (Google Sign-In, Phone)
   - Firestore Database
   - Cloud Storage
   - Cloud Messaging
   - Cloud Functions

#### b. Configure Firebase for each platform

**Android:**
1. Add Android app in Firebase Console
2. Download `google-services.json`
3. Place it in `android/app/`

**iOS:**
1. Add iOS app in Firebase Console
2. Download `GoogleService-Info.plist`
3. Place it in `ios/Runner/`

**Web:**
1. Add Web app in Firebase Console
2. Copy the Firebase configuration
3. Update the configuration in `lib/main.dart` (lines 125-133)

#### c. Firestore Security Rules
Copy the rules from `firestore.rules` to your Firebase Console

#### d. Deploy Firebase Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Update Firebase Configuration

⚠️ **IMPORTANT**: Replace the Firebase configuration in `lib/main.dart` with your own:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.firebasestorage.app",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
    measurementId: "YOUR_MEASUREMENT_ID",
  ),
);
```

### 5. Google Sign-In Configuration

Update the Google Sign-In client ID in `lib/main.dart`:
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: kIsWeb ? 'YOUR_WEB_CLIENT_ID' : null,
);
```

## 🏃 Running the Application

### Run on specific platform
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### Build for production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## 📁 Project Structure

```
gmail_homepage/
├── android/              # Android-specific code
├── ios/                  # iOS-specific code
├── web/                  # Web-specific code
├── windows/              # Windows-specific code
├── macos/                # macOS-specific code
├── linux/                # Linux-specific code
├── lib/                  # Flutter application code
│   ├── main.dart        # Application entry point
│   ├── controllers/     # Business logic controllers
│   ├── models/          # Data models
│   ├── compose_mail_screen.dart
│   ├── mail_detail_screen.dart
│   ├── user_info_screen.dart
│   ├── phone_register_screen.dart
│   └── ...
├── assets/              # Images, fonts, animations
├── functions/           # Firebase Cloud Functions
├── firestore.rules      # Firestore security rules
├── storage.rules        # Storage security rules
└── pubspec.yaml         # Project dependencies
```

## 🔒 Security Notes

**DO NOT commit the following files:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json` (if contains sensitive data)
- `.env` files
- Any files containing API keys or credentials

These files are already added to `.gitignore`.

## 🗄️ Database Structure

### Collections

#### users
- id, email, phone, name, avatar
- notification, view, search, dark_mode settings
- tag_filter, finding_by_date, from_date, to_date
- fcmTokenAndroid, fcmTokenWeb

#### mails
- id, senderId, senderName, senderAvatar
- subject, content, createdAt
- important, is_drafts
- cc, bcc

#### mails_users
- id, mailId, receiverId
- starred, important, is_read
- is_spam, trash, is_snoozed, snoozed_time
- is_social, is_promotions, is_updates, is_forums
- is_outbox, tag

#### mail_attachments
- id, mailId, name, url, type, size

## 🎨 Customization

### Change App Icon
Update the icon in `assets/icon.png` and run:
```bash
flutter pub run flutter_launcher_icons:main
```

### Modify Theme
Edit theme settings in `lib/main.dart` (lines 250-280)

### Add Custom Fonts
1. Add font files to `assets/fonts/`
2. Update `pubspec.yaml`
3. Use in your widgets

## 🐛 Troubleshooting

### Firebase initialization error
- Check if `google-services.json` / `GoogleService-Info.plist` is in the correct location
- Verify Firebase configuration matches your project

### Notifications not working
- Ensure FCM is enabled in Firebase Console
- Check notification permissions on device
- Verify service worker is registered (Web)

### Build errors
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

## 📝 License

This project is for educational purposes. Please use responsibly and comply with Google's terms of service.

## 👥 Contributors

- **Luu Gia Phu** - Initial work

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All package contributors

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Note**: This is a clone project for learning purposes. It is not affiliated with or endorsed by Google LLC.
