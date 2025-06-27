import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'manage_announcement_page.dart';
import 'manage_user_page.dart';
import 'report_inbox_page.dart'; // Import the Admin Report Inbox page
import '../features/user_auth/presentation/pages/profile_page.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ManageUsersPage(), // Users Management
      _buildAnnouncementTab(context), // Announcements
      AdminReportInboxPage(), // Report Inbox
      ProfilePage(), // Profile page
    ];
  }

  void _onItemTapped(int idx) {
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[600],
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Announcements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Reports', // Added Reports tab
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ANNOUNCEMENT/BANNER MANAGEMENT TAB (Your previous logic here)
  Widget _buildAnnouncementTab(BuildContext context) {
    return ManageAnnouncementsPage(); // Reuse your manager widget for managing announcements!
  }
}
