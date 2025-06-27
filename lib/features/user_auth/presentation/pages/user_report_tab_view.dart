import 'package:flutter/material.dart';
import 'user_report_page.dart';
import 'user_report_history_page.dart';

class UserReportTabView extends StatelessWidget {
  const UserReportTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
          appBar: AppBar(
            title: const Text("Report Center"),
            bottom: const TabBar(
              tabs: [
                Tab(text: "Submit Report"),
                Tab(text: "My Reports"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              UserReportPage(), // Used to submit reports
              const UserReportHistoryPage() // Already filters by current user's userId
            ],
          )),
    );
  }
}
