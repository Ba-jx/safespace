import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'providers/user_provider.dart'; // ✅ Add this
import 'screens/role_selection_screen.dart';
import 'screens/patient_login_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/doctor_create_patient_screen.dart';
import 'screens/manage_appointments_screen.dart';
import 'screens/view_patients_screen.dart';
import 'screens/doctor_communication_screen.dart';
import 'screens/patient_communication_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()), // ✅ Important
      ],
      child: const SafeSpaceApp(),
    ),
  );
}

class SafeSpaceApp extends StatelessWidget {
  const SafeSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xfffff9f7fc),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const RoleSelectionScreen(),
        '/patient/login': (context) => const PatientLoginScreen(),
        '/doctor/login': (context) => const DoctorLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/doctor/dashboard': (context) => const DoctorDashboardScreen(),
        '/doctor/create-patient': (context) => const DoctorCreatesPatientScreen(),
        '/doctor/appointments': (context) => const ManageAppointmentsScreen(),
        '/doctor/patients': (context) => const ViewPatientsScreen(),
        '/doctor/communication': (context) => const DoctorCommunicationScreen(),
        '/patient/communication': (context) => const PatientCommunicationScreen(),
      },
    );
  }
}
