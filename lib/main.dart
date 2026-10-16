import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/chat_service.dart';
import 'screens/chat_list_screen.dart';
import 'screens/call_screen.dart';
import 'services/call_service.dart';
import 'models/user_model.dart';
import 'services/chat_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (data['type'] == 'incoming_call') {
    final params = CallKitParams(
      id: data['callId'] ?? const Uuid().v4(),
      nameCaller: data['callerName'] ?? 'Unknown',
      appName: 'Chatly',
      type: data['callType'] == 'video' ? 1 : 0,
      duration: 30000,
      extra: {
        'callId': data['callId'],
        'callerId': data['callerId'],
        'callType': data['callType'],
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        textAccept: 'Accept',
        textDecline: 'Decline',
        isFullScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  const androidDetails = AndroidNotificationDetails(
    'chatly_channel',
    'Chatly Messages',
    channelDescription: 'Chat message notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: details,
  );
}

Future<void> _setupFcm() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
  );

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((message) {
    _showLocalNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('Notification tapped: ${message.data}');
  });
}

Future<void> _requestAllPermissions() async {
  try {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.location,
      Permission.contacts,
    ].request();
  } catch (e) {
    print('Permission error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _requestAllPermissions();
  
  // Start global workers
  _startGlobalWorkers();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _setupFcm();
  runApp(const MyApp());
}

void _startGlobalWorkers() {
  // Scheduled messages check every 30 seconds
  Future.delayed(const Duration(seconds: 5), () async {
    try {
      final service = ChatService();
      if (FirebaseAuth.instance.currentUser != null) {
        await service.processAllScheduledMessages();
      }
    } catch (e) {
      print('Scheduled worker error: \$e');
    }
    _startGlobalWorkers();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Chatly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (FirebaseAuth.instance.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      // App foreground mein aaya — online karo
      _chatService.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App background mein gaya — offline karo
      _chatService.updateOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          _startIncomingCallListener();
          return const ChatListScreen();
        }
        return const AuthScreen();
      },
    );
  }

  void _startIncomingCallListener() {
    // CallKit event listener (3.1.6 API)
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;

      if (event is CallEventActionCallAccept) {
        final params = event.callKitParams;
        final extra = params.extra;
        if (extra != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => CallScreen(
                callId: extra['callId'] ?? '',
                otherUserId: extra['callerId'] ?? '',
                otherUserName: params.nameCaller ?? 'Unknown',
                callType: extra['callType'] ?? 'audio',
                isCaller: false,
              ),
            ),
          );
        }
      } else if (event is CallEventActionCallDecline) {
        final params = event.callKitParams;
        final extra = params.extra;
        if (extra != null) {
          CallService().rejectCall(extra['callId']);
        }
      }
    });

    final callService = CallService();
    callService.listenIncomingCalls().listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final callId = data['callId'] as String;
      final callerId = data['callerId'] as String;
      final callType = data['callType'] as String;

      final chatService = ChatService();
      final caller = await chatService.getUserById(callerId);

      if (caller != null && navigatorKey.currentState != null) {
        // Show incoming call screen
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: callId,
              otherUserId: callerId,
              otherUserName: caller.name,
              otherUserPhoto: caller.photoUrl,
              callType: callType,
              isCaller: false,
            ),
          ),
        );
      }
    });
  }
}
