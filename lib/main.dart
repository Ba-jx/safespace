import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/device_provider.dart';
import 'providers/theme_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/symptom_tracking_screen.dart';
import 'screens/real_time_monitor_screen.dart';
import 'screens/doctor_communication_screen.dart';
import 'screens/patient_communication_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/appointment_booking_screen.dart';
import 'screens/appointment_list_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/patient_login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/view_patients_screen.dart';
import 'screens/manage_appointments_screen.dart';
import 'screens/doctor_create_patient_screen.dart';
import 'screens/doctor_appointment_calendar.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("⏪ Background message: ${message.notification?.title} - ${message.notification?.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const SafeSpaceApp());
}

class SafeSpaceApp extends StatelessWidget {
  const SafeSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MaterialAppWithFCM(),
    );
  }
}

class MaterialAppWithFCM extends StatefulWidget {
  const MaterialAppWithFCM({super.key});

  @override
  State<MaterialAppWithFCM> createState() => _MaterialAppWithFCMState();
}

class _MaterialAppWithFCMState extends State<MaterialAppWithFCM> {
  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  // Foreground handler with fallback
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'];
    final body = notification?.body ?? data['body'];

    if (title != null && body != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Notifications',
            channelDescription: 'General app notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }

    print('🔔 Foreground Notification: $title - $body');
  });

  // Tapped from background
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

  // Tapped from terminated
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessageNavigation(initialMessage);
  }

  final token = await fcm.getToken();
  final user = FirebaseAuth.instance.currentUser;
  print("📱 FCM Token: $token");

  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }
}
  
  void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    print("📲 Notification tapped, navigating to type: $type");

    switch (type) {
      case 'chat_patient':
        navigatorKey.currentState?.pushNamed('/patient/communication');
        break;
      case 'chat_doctor':
        navigatorKey.currentState?.pushNamed('/doctor/communication');
        break;
      case 'appointment_patient':
        navigatorKey.currentState?.pushNamed('/appointments/list');
        break;
      case 'appointment_doctor':
        navigatorKey.currentState?.pushNamed('/doctor/calendar');
        break;
      case 'monitor':
        navigatorKey.currentState?.pushNamed('/doctor/patients');
        break;
      default:
        navigatorKey.currentState?.pushNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Safe Space',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFFF5F3F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD8BFD8),
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF1E1B2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2640),
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/role-selection': (_) => const RoleSelectionScreen(),
        '/login': (_) => const PatientLoginScreen(),
        '/doctor/login': (_) => const DoctorLoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/symptom-tracking': (_) => const SymptomTrackingScreen(),
        '/real-time-monitor': (_) => const RealTimeMonitorScreen(),
        '/doctor/communication': (_) => const DoctorCommunicationScreen(),
        '/patient/communication': (_) => const PatientCommunicationScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/appointments/book': (_) => const AppointmentBookingScreen(),
        '/appointments/list': (_) => const PatientAppointmentCalendar(),
        '/doctor/dashboard': (_) => const DoctorDashboardScreen(),
        '/doctor/patients': (_) => const ViewPatientsScreen(),
        '/doctor/create-patient': (_) => const DoctorCreatesPatientScreen(),
        '/doctor/appointments': (_) => const ManageAppointmentsScreen(),
        '/doctor/calendar': (_) => const DoctorAppointmentCalendar(),
      },
    );
  }
}
