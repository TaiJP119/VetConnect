import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // ------------------ Initialization for Local Notifications ------------------
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    tz.initializeTimeZones();
  }

  // ------------------ Schedule Local Calendar Notification ------------------
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required DateTime scheduledTime,
  }) async {
    final tz.TZDateTime tzDateTime = tz.TZDateTime.from(
      scheduledTime.subtract(const Duration(minutes: 10)), // 10 mins before
      tz.local,
    );

    await _notifications.zonedSchedule(
      id,
      'Event Reminder',
      title,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_channel',
          'Event Notifications',
          channelDescription: 'Reminder for pet events',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  // ------------------ Cancel Local Notification ------------------
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // ------------------ Firestore (FCM/Calendar) Notification Save ------------------
  static Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String body,
    required String type, // 'fcm' or 'calendar'
  }) async {
    // Step 1: Store notification in Firestore (userNotifications collection)
    try {
      await FirebaseFirestore.instance.collection('userNotifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print("Notification stored in Firestore.");
    } catch (e) {
      print("Error storing notification in Firestore: $e");
    }

    // Step 2: Send FCM Notification (for FCM type)
    if (type == 'fcm') {
      await _sendFCMNotification(userId, title, body);
    }

    // Step 3: Send Local Notification (for Calendar type or others)
    if (type == 'calendar') {
      await _sendLocalNotification(title, body);
    }
  }

  // ------------------ Send FCM Notification via HTTP (Data-only) ------------------
  static Future<void> _sendFCMNotification(
      String userId, String title, String body) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final fcmToken = userDoc['fcmToken'];

    if (fcmToken != null) {
      final serverKey = 'YOUR_SERVER_KEY'; // FCM server key
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      final payload = {
        'to': fcmToken,
        'data': {
          'title': title, // Send the title in data field
          'body': body, // Send the body in data field
          'type': 'fcm', // You can add extra data, like 'type', etc.
        },
      };

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      try {
        final response = await http.post(
          url,
          headers: headers,
          body: json.encode(payload),
        );

        if (response.statusCode == 200) {
          print('FCM data-only notification sent successfully!');
        } else {
          print('Failed to send notification: ${response.body}');
        }
      } catch (e) {
        print('Error sending notification: $e');
      }
    }
  }

  // ------------------ Send Local Notification ------------------
  static Future<void> _sendLocalNotification(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'event_channel',
        'Event Notifications',
        channelDescription: 'Reminder for pet events',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _notifications.show(0, title, body, details);
  }
}
