import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:VetApp/services/notification_service.dart';

class NotificationIcon extends StatefulWidget {
  final String userId;
  const NotificationIcon({super.key, required this.userId});

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  final Set<String> _notifiedDocIds = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('userNotifications')
          .where('userId', isEqualTo: widget.userId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          unreadCount = docs.length;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;

            if (!_notifiedDocIds.contains(docId) &&
                data['type'] == 'calendar' &&
                data['isRead'] == false) {
              _notifiedDocIds.add(docId);

              NotificationService.scheduleSingleStageNotifications(
                eventId: data['eventId'] ?? docId,
                title: data['title'] ?? 'Event Reminder',
                dateTime: (data['eventDate'] as Timestamp).toDate(),
              );
            }
          }
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/notifications',
                  arguments: {'userId': FirebaseAuth.instance.currentUser!.uid},
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
