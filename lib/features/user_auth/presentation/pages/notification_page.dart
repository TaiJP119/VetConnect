import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatelessWidget {
  final String userId;
  const NotificationPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('userNotifications')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final docId = notifications[index].id;

              return ListTile(
                leading: Icon(data['type'] == 'calendar'
                    ? Icons.calendar_today
                    : Icons.notifications),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['body'] ?? ''),
                trailing: data['isRead'] == false
                    ? IconButton(
                        icon: const Icon(Icons.mark_email_read),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('userNotifications')
                              .doc(docId)
                              .update({'isRead': true});
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
