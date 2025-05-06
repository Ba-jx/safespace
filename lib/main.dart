import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/device_provider.dart';
import 'providers/theme_provider.dart';

// Screens
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      child: MaterialApp(
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
          '/': (_) => const RoleSelectionScreen(),
          '/login': (_) => const PatientLoginScreen(),
          '/doctor/login': (_) => const DoctorLoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/symptom-tracking': (_) => const SymptomTrackingScreen(),
          '/real-time-monitor': (_) => const RealTimeMonitorScreen(),
          '/doctor/communication': (_) => const DoctorCommunicationScreen(),
          '/patient/communication': (_) => const PatientCommunicationScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/appointments/book': (_) => const AppointmentBookingScreen(),
          '/appointments/list': (_) => const AppointmentListScreen(),
          '/doctor/dashboard': (_) => const DoctorDashboardScreen(),
          '/doctor/patients': (_) => const ViewPatientsScreen(),
          '/doctor/create-patient': (context) => const DoctorCreatesPatientScreen(),
          '/doctor/appointments': (_) => const ManageAppointmentsScreen(),
        },
      ),
    );
  }
}
