import 'package:VetApp/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

Future<void> cancelNotifications(String eventId) async {
  await _localNotifications.cancel(eventId.hashCode);
  await _localNotifications.cancel(eventId.hashCode + 1);
  await _localNotifications.cancel(eventId.hashCode + 2);
}

Future<void> scheduleNotifications(
    String eventId, String title, DateTime dateTime) async {
  int id1 = eventId.hashCode;
  int id2 = eventId.hashCode + 1;
  int id3 = eventId.hashCode + 2;

  const details = NotificationDetails(
    android: AndroidNotificationDetails('your_channel_id', 'Reminders',
        importance: Importance.max, priority: Priority.high),
  );

  // Local notifications
  await _localNotifications.zonedSchedule(
    id1,
    'Upcoming Event',
    '$title in 1 hour!',
    tz.TZDateTime.from(dateTime.subtract(const Duration(hours: 1)), tz.local),
    details,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );

  await _localNotifications.zonedSchedule(
    id2,
    'Upcoming Event',
    '$title in 10 minutes!',
    tz.TZDateTime.from(
        dateTime.subtract(const Duration(minutes: 10)), tz.local),
    details,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );

  await _localNotifications.zonedSchedule(
    id3,
    'Event Started',
    '$title is starting now!',
    tz.TZDateTime.from(dateTime, tz.local),
    details,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );

  // Now, store the event notification in Firestore
  final userId = FirebaseAuth.instance.currentUser!.uid;

  await NotificationService.sendUserNotification(
    userId: userId,
    title: 'Event Reminder',
    body: '$title is starting soon!',
    type: 'calendar', // Calendar reminder type
  );
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class AddEventPage extends StatefulWidget {
  final DocumentSnapshot? existingEvent;

  const AddEventPage({super.key, this.existingEvent});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _petNameController = TextEditingController();
  DateTime? _selectedDateTime;
  String? _existingGoogleEventId;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: [gcal.CalendarApi.calendarScope]);

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();

    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!['title'];
      _petNameController.text = widget.existingEvent!['petName'];
      _selectedDateTime = (widget.existingEvent!['date'] as Timestamp).toDate();
      _existingGoogleEventId = widget.existingEvent!['googleEventId'];
    }
  }

  void _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    final petName = _petNameController.text.trim();
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (title.isEmpty || _selectedDateTime == null) return;

    String docId;
    String? googleEventId;
    final eventData = {
      'title': title,
      'petName': petName,
      'date': Timestamp.fromDate(_selectedDateTime!),
    };

    if (widget.existingEvent != null) {
      docId = widget.existingEvent!.id;
      googleEventId =
          widget.existingEvent!.data().toString().contains('googleEventId')
              ? widget.existingEvent!['googleEventId']
              : null;

      await cancelNotifications(docId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(docId)
          .update(eventData);
    } else {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .add(eventData);
      docId = docRef.id;
      await docRef.update({'eventId': docId});
    }

    await scheduleNotifications(docId, title, _selectedDateTime!);

    final shouldSync = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sync with Google Calendar?"),
        content: const Text(
            "Would you like to sync this event with your Google Calendar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (shouldSync == true) {
      final newGoogleEventId = await _syncGoogleCalendarEvent(
        existingEventId: googleEventId,
        title: title,
        description: 'Pet: $petName',
        startTime: _selectedDateTime!,
        endTime: _selectedDateTime!.add(const Duration(minutes: 30)),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(docId)
          .update({'googleEventId': newGoogleEventId});
    }

    Navigator.pop(context);
  }

  Future<String?> _syncGoogleCalendarEvent({
    String? existingEventId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final client = GoogleHttpClient(await account.authHeaders);
      final calendar = gcal.CalendarApi(client);

      final event = gcal.Event(
        summary: title,
        description: description,
        start: gcal.EventDateTime(
            dateTime: startTime, timeZone: 'Asia/Kuala_Lumpur'),
        end: gcal.EventDateTime(
            dateTime: endTime, timeZone: 'Asia/Kuala_Lumpur'),
      );

      if (existingEventId != null) {
        final updatedEvent =
            await calendar.events.update(event, 'primary', existingEventId);
        return updatedEvent.id;
      } else {
        final createdEvent = await calendar.events.insert(event, 'primary');
        return createdEvent.id;
      }
    } catch (e) {
      print("❌ Google Calendar sync error: $e");
      return null;
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.existingEvent == null) return;

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final docId = widget.existingEvent!.id;
    final googleEventId =
        widget.existingEvent!.data().toString().contains('googleEventId')
            ? widget.existingEvent!['googleEventId']
            : null;

    await cancelNotifications(docId);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(docId)
        .delete();

    if (googleEventId != null) {
      try {
        final account = await _googleSignIn.signIn();
        if (account != null) {
          final client = GoogleHttpClient(await account.authHeaders);
          final calendar = gcal.CalendarApi(client);
          await calendar.events.delete('primary', googleEventId);
        }
      } catch (e) {
        print("❌ Failed to delete Google Calendar event: $e");
      }
    }

    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null) return;

    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    setState(() {
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _selectedDateTime != null
        ? DateFormat.yMMMd().add_jm().format(_selectedDateTime!)
        : 'Select Date & Time';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEvent != null ? "Edit Event" : "Add Event"),
        actions: [
          if (widget.existingEvent != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteEvent)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Event Title")),
            TextField(
                controller: _petNameController,
                decoration: const InputDecoration(labelText: "Pet Name")),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(displayTime)),
                ElevatedButton(
                    onPressed: _pickDateTime,
                    child: const Text("Pick Date & Time")),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveEvent,
              child: Text(
                  widget.existingEvent != null ? "Update Event" : "Save Event"),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
