import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecord {
  final String id;
  final String title;
  final String? date;
  final String? note;
  final List<String> fileUrls;

  HealthRecord({
    required this.id,
    required this.title,
    this.date,
    this.note,
    required this.fileUrls,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json, String id) {
    return HealthRecord(
      id: id,
      title: json['title']?.toString() ?? 'Untitled',
      date: json['date']?.toString(),
      note: json['note']?.toString(),
      fileUrls: json['fileUrls'] != null && json['fileUrls'] is List
          ? List<String>.from(json['fileUrls'].map((item) => item.toString()))
          : [],
    );
  }
}
