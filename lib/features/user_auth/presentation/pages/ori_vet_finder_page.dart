// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter_typeahead/flutter_typeahead.dart';

// class VetClinic {
//   final String name;
//   final double lat;
//   final double lng;
//   final double rating;
//   final bool is24Hr;

//   VetClinic({
//     required this.name,
//     required this.lat,
//     required this.lng,
//     required this.rating,
//     required this.is24Hr,
//   });
// }

// class VetFinderPage extends StatefulWidget {
//   @override
//   _VetFinderPageState createState() => _VetFinderPageState();
// }

// class _VetFinderPageState extends State<VetFinderPage> {
//   late GoogleMapController _mapController;
//   Position? _currentPosition;
//   List<VetClinic> _vetClinics = [];
//   bool _sortByReview = false;
//   bool _only24Hr = false;
//   final String apiKey = 'YOUR-API-KEY';

//   @override
//   void initState() {
//     super.initState();
//     _determinePosition().then((pos) {
//       setState(() {
//         _currentPosition = pos;
//       });
//       _fetchNearbyVets();
//     });
//   }

//   Future<Position> _determinePosition() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return Future.error('Location services are disabled.');

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return Future.error('Location permissions are denied');
//       }
//     }

//     return await Geolocator.getCurrentPosition();
//   }

//   Future<void> _fetchNearbyVets({double? lat, double? lng}) async {
//     final locationLat = lat ?? _currentPosition?.latitude;
//     final locationLng = lng ?? _currentPosition?.longitude;
//     if (locationLat == null || locationLng == null) return;

//     final url =
//         "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$locationLat,$locationLng&key=$apiKey";

//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final List<VetClinic> clinics = [];

//       for (var result in data['results']) {
//         clinics.add(VetClinic(
//           name: result['name'],
//           lat: result['geometry']['location']['lat'],
//           lng: result['geometry']['location']['lng'],
//           rating: result['rating']?.toDouble() ?? 0.0,
//           is24Hr: result['opening_hours']?['open_now'] ?? false,
//         ));
//       }

//       setState(() {
//         _vetClinics = clinics;
//       });
//     } else {
//       throw Exception('Failed to fetch nearby vets');
//     }
//   }

//   List<VetClinic> _filteredClinics() {
//     List<VetClinic> filtered = _vetClinics;
//     if (_only24Hr) {
//       filtered = filtered.where((vet) => vet.is24Hr).toList();
//     }

//     if (_sortByReview) {
//       filtered.sort((a, b) => b.rating.compareTo(a.rating));
//     } else if (_currentPosition != null) {
//       filtered.sort((a, b) {
//         double distanceA = Geolocator.distanceBetween(
//           _currentPosition!.latitude,
//           _currentPosition!.longitude,
//           a.lat,
//           a.lng,
//         );
//         double distanceB = Geolocator.distanceBetween(
//           _currentPosition!.latitude,
//           _currentPosition!.longitude,
//           b.lat,
//           b.lng,
//         );
//         return distanceA.compareTo(distanceB);
//       });
//     }

//     return filtered;
//   }

//   Future<List<Map<String, dynamic>>> _getSearchSuggestions(String input) async {
//     final String url =
//         'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&types=geocode&language=en';
//     final response = await http.get(Uri.parse(url));
//     final data = json.decode(response.body);
//     if (data['status'] == 'OK') {
//       return List<Map<String, dynamic>>.from(data['predictions']);
//     } else {
//       return [];
//     }
//   }

//   Future<void> _selectSearchPlace(String placeId) async {
//     final url =
//         'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';
//     final response = await http.get(Uri.parse(url));
//     final data = json.decode(response.body);

//     if (data['status'] == 'OK') {
//       final location = data['result']['geometry']['location'];
//       final latLng = LatLng(location['lat'], location['lng']);
//       _mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));

//       setState(() {
//         _currentPosition = Position(
//           latitude: latLng.latitude,
//           longitude: latLng.longitude,
//           timestamp: DateTime.now(),
//           accuracy: 1.0,
//           altitude: 1.0,
//           altitudeAccuracy: 1.0,
//           heading: 1.0,
//           headingAccuracy: 1.0,
//           speed: 1.0,
//           speedAccuracy: 1.0,
//           floor: null,
//           isMocked: false,
//         );
//       });

//       _fetchNearbyVets(lat: latLng.latitude, lng: latLng.longitude);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Find Nearby Vets"),
//         actions: [
//           Row(
//             children: [
//               Text("⭐", style: TextStyle(fontSize: 16)),
//               Switch(
//                 value: _sortByReview,
//                 onChanged: (val) => setState(() => _sortByReview = val),
//               ),
//               Text("24H", style: TextStyle(fontSize: 16)),
//               Switch(
//                 value: _only24Hr,
//                 onChanged: (val) => setState(() => _only24Hr = val),
//               ),
//             ],
//           ),
//         ],
//         bottom: PreferredSize(
//           preferredSize: Size.fromHeight(60),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: TypeAheadField<Map<String, dynamic>>(
//               suggestionsCallback: (pattern) async =>
//                   await _getSearchSuggestions(pattern),
//               itemBuilder: (context, suggestion) {
//                 return ListTile(
//                   title: Text(suggestion['description']),
//                 );
//               },
//               onSelected: (suggestion) {
//                 _selectSearchPlace(suggestion['place_id']);
//               },
//               builder: (context, controller, focusNode) {
//                 return TextField(
//                   controller: controller,
//                   focusNode: focusNode,
//                   decoration: InputDecoration(
//                     hintText: "Search location...",
//                     fillColor: Colors.white,
//                     filled: true,
//                     prefixIcon: Icon(Icons.search),
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//       body: _currentPosition == null
//           ? Center(child: CircularProgressIndicator())
//           : Stack(
//               children: [
//                 GoogleMap(
//                   onMapCreated: (controller) {
//                     _mapController = controller;
//                   },
//                   initialCameraPosition: CameraPosition(
//                     target: LatLng(_currentPosition!.latitude,
//                         _currentPosition!.longitude),
//                     zoom: 14,
//                   ),
//                   myLocationEnabled: true,
//                   myLocationButtonEnabled: true,
//                   markers: _filteredClinics().map((vet) {
//                     return Marker(
//                       markerId: MarkerId(vet.name),
//                       position: LatLng(vet.lat, vet.lng),
//                       infoWindow: InfoWindow(
//                         title: vet.name,
//                         snippet:
//                             "${vet.rating} ⭐ - ${vet.is24Hr ? "Open Now" : "Closed"}",
//                       ),
//                     );
//                   }).toSet(),
//                 ),
//                 Positioned(
//                   bottom: 16,
//                   right: 16,
//                   child: FloatingActionButton(
//                     child: Icon(Icons.refresh),
//                     onPressed: _fetchNearbyVets,
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }
