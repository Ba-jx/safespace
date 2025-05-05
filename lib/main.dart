import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/home_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/patient_login_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/patient_communication_screen.dart';
import 'screens/doctor_communication_screen.dart';
import 'screens/manage_appointments_screen.dart';
import 'screens/view_patients_screen.dart';
import 'screens/appointment_booking_screen.dart';
import 'screens/appointment_list_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/patient_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/doctor_register_patient_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SafeSpaceApp());
}

class SafeSpaceApp extends StatelessWidget {
  const SafeSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Space',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const RoleSelectionScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/doctor/login': (_) => const DoctorLoginScreen(),
        '/patient/login': (_) => const PatientLoginScreen(),
        '/doctor/dashboard': (_) => const DoctorDashboardScreen(),
        '/patient/communication': (_) => const PatientCommunicationScreen(),
        '/doctor/communication': (_) => const DoctorCommunicationScreen(),
        '/doctor/appointments': (_) => const ManageAppointmentsScreen(),
        '/doctor/patients': (_) => const ViewPatientsScreen(),
        '/book-appointment': (_) => const AppointmentBookingScreen(),
        '/appointment-list': (_) => const AppointmentListScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/doctor/register-patient': (_) => const DoctorRegisterPatientScreen(),
      },
    );
  }
}
