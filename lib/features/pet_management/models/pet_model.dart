import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String? id;
  final String? name;
  final String? species;
  final String? breed;
  final String? gender;
  final String? birthday;
  final String? imageUrl;
  final String? microchipNumber;
  final String? colorMark;
  final String? address;
  final String? contactNumber;
  final String? natured;

  PetModel({
    this.id,
    this.name,
    this.species,
    this.breed,
    this.gender,
    this.birthday,
    this.imageUrl,
    this.microchipNumber,
    this.colorMark,
    this.address,
    this.contactNumber,
    this.natured,
  });

  factory PetModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetModel(
      id: doc.id,
      name: data['name'],
      species: data['species'],
      breed: data['breed'],
      gender: data['gender'],
      birthday: data['birthday'],
      imageUrl: data['imageUrl'],
      microchipNumber: data['microchipNumber'],
      colorMark: data['colorMark'],
      address: data['address'],
      contactNumber: data['contactNumber'],
      natured: data['natured'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "species": species,
      "breed": breed,
      "gender": gender,
      "birthday": birthday,
      "imageUrl": imageUrl ?? "",
      "microchipNumber": microchipNumber ?? "",
      "colorMark": colorMark ?? "",
      "address": address ?? "",
      "contactNumber": contactNumber ?? "",
      "natured": natured ?? "",
    };
  }
}
