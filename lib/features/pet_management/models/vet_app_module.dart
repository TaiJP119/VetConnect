import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VetAppointmentPage extends StatefulWidget {
  @override
  _VetAppointmentPageState createState() => _VetAppointmentPageState();
}

class _VetAppointmentPageState extends State<VetAppointmentPage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPendingAppointments() {
    return firestore
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedDate')
        .snapshots();
  }

  Future<void> updateAppointmentStatus(
      String appointmentId, String status, String? note) async {
    await firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
      'note': note ?? '',
      'updatedDate': DateTime.now(),
    });
    // Trigger notification to customer here (Firebase Cloud Messaging integration)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Appointments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: getPendingAppointments(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          final appointments = snapshot.data!.docs;
          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index].data() as Map;
              return Card(
                child: ListTile(
                  title: Text(
                      "${appointment['petName']} - ${appointment['reason']}"),
                  subtitle: Text(
                      "Date: ${appointment['requestedDate'].toDate().toString().substring(0, 16)}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => updateAppointmentStatus(
                            appointments[index].id, 'approved', null),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => updateAppointmentStatus(
                            appointments[index].id,
                            'rejected',
                            'Schedule conflict'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
