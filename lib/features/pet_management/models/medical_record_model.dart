import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicalRecordType {
  medicalHistory,
  ectoparasite,
  worm,
  heartworm,
  notes,
  vaccination,
}

String medicalRecordTypeToString(MedicalRecordType type) {
  switch (type) {
    case MedicalRecordType.medicalHistory:
      return "Medical/Surgical History";
    case MedicalRecordType.ectoparasite:
      return "Ectoparasite Treatment";
    case MedicalRecordType.worm:
      return "Intestinal Worm (Fecal Exam)";
    case MedicalRecordType.heartworm:
      return "Heartworm Test";
    case MedicalRecordType.notes:
      return "Other Medical Notes";
    case MedicalRecordType.vaccination:
      return "Vaccination";
  }
}

MedicalRecordType medicalRecordTypeFromString(String? str) {
  switch (str) {
    case 'medicalHistory':
      return MedicalRecordType.medicalHistory;
    case 'ectoparasite':
      return MedicalRecordType.ectoparasite;
    case 'worm':
      return MedicalRecordType.worm;
    case 'heartworm':
      return MedicalRecordType.heartworm;
    case 'notes':
      return MedicalRecordType.notes;
    case 'vaccination':
      return MedicalRecordType.vaccination;
    default:
      return MedicalRecordType.notes;
  }
}

class MedicalRecord {
  final String? id;
  final MedicalRecordType type;
  final DateTime date;
  final Map<String, dynamic> data; // Type-specific fields
  final List<String> fileUrls;

  MedicalRecord({
    this.id,
    required this.type,
    required this.date,
    required this.data,
    required this.fileUrls,
  });

  factory MedicalRecord.fromSnapshot(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final String typeStr = d['type'] as String? ?? 'notes';
    final Timestamp? dateStamp = d['date'] as Timestamp?;
    final Map<String, dynamic> dataMap = d['data'] != null
        ? Map<String, dynamic>.from(d['data'])
        : <String, dynamic>{};

    // Patch: Convert nextVisitDate (and others if needed) from Timestamp to DateTime
    if (dataMap['nextVisitDate'] != null &&
        dataMap['nextVisitDate'] is Timestamp) {
      dataMap['nextVisitDate'] =
          (dataMap['nextVisitDate'] as Timestamp).toDate();
    }

    // If you have other fields that may be Timestamp, repeat here:
    // if (dataMap['anotherDateField'] != null && dataMap['anotherDateField'] is Timestamp) {
    //   dataMap['anotherDateField'] = (dataMap['anotherDateField'] as Timestamp).toDate();
    // }

    return MedicalRecord(
      id: doc.id,
      type: medicalRecordTypeFromString(typeStr),
      date: (dateStamp != null) ? dateStamp.toDate() : DateTime.now(),
      data: dataMap,
      fileUrls: (d['fileUrls'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    final dataCopy = Map<String, dynamic>.from(data);
    if (dataCopy['nextVisitDate'] is DateTime) {
      dataCopy['nextVisitDate'] = Timestamp.fromDate(dataCopy['nextVisitDate']);
    }
    return {
      'type': type.toString().split('.').last,
      'date': Timestamp.fromDate(date),
      'data': dataCopy,
      'fileUrls': fileUrls,
    };
  }
}
