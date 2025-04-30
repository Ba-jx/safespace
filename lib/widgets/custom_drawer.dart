import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/logout_helper.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).userName;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFD8BFD8)),
            accountName: Text(userName.isNotEmpty ? userName : 'User'),
            accountEmail: const Text(''), // or show email if available
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFFD8BFD8)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
