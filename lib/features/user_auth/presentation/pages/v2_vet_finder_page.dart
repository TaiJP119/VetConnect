import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Your Google API Key here:
const String googleApiKey = 'AIzaSyBYaINhvJikyGC4hI4U1c-XkrH6SVrZUBY';

// Simple model; adapt to your own if desired
class Place {
  final String name;
  final String address;
  final String? contact;
  final double lat;
  final double lng;
  final bool is24hrs;

  Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.contact,
    this.is24hrs = false,
  });
}

class VetFinderPage extends StatefulWidget {
  @override
  _VetFinderPageState createState() => _VetFinderPageState();
}

class _VetFinderPageState extends State<VetFinderPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  Position? _currentPosition;
  String _searchText = '';
  List<Place> _places = [];
  Set<Marker> _markers = {};
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 1. Get current location
  Future<void> _getCurrentLocation() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
      _moveMap(position.latitude, position.longitude);
    }
  }

  Future<void> _moveMap(double lat, double lng) async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
  }

  // 2. Search for any place
  Future<void> _searchPlaces(String query) async {
    if (_currentPosition == null) return;
    setState(() {
      _isLoading = true;
      _places.clear();
      _markers.clear();
    });
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}'
      '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&radius=5000'
      '&key=$googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      List<Place> foundPlaces = [];
      for (final result in body['results']) {
        final name = result['name'];
        final address = result['formatted_address'] ?? '';
        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];
        foundPlaces.add(Place(
            name: name, address: address, lat: lat, lng: lng, is24hrs: false));
      }
      setState(() {
        _places = foundPlaces;
        _addMarkers();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed.')),
      );
    }
  }

  // 3. Emergency 24hr Vet Search
  Future<void> _find24hrEmergencyVet() async {
    if (_currentPosition == null) return;
    setState(() {
      _isLoading = true;
      _places.clear();
      _markers.clear();
    });
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent("24 hour emergency vet")}'
      '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&radius=10000'
      '&key=$googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      List<Place> foundPlaces = [];
      for (final result in body['results']) {
        final name = result['name'];
        final address = result['formatted_address'] ?? '';
        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];
        foundPlaces.add(Place(
          name: name,
          address: address,
          lat: lat,
          lng: lng,
          is24hrs: true,
        ));
      }
      setState(() {
        _places = foundPlaces;
        _addMarkers();
        _isLoading = false;
      });
      if (foundPlaces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No 24hr emergency vets found nearby.')),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find emergency vet.')),
      );
    }
  }

  // 4. Add markers to map
  void _addMarkers() {
    final Set<Marker> newMarkers = {};
    if (_currentPosition != null) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(title: 'You are here'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    for (final place in _places) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(place.name),
          position: LatLng(place.lat, place.lng),
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
        ),
      );
    }
    setState(() {
      _markers = newMarkers;
    });
  }

  // 5. Google Directions API for ETA/Distance
  Future<Map<String, String>?> _getDistanceEta(Place place) async {
    if (_currentPosition == null) return null;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=${place.lat},${place.lng}'
      '&mode=driving'
      '&key=$googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['routes'] != null && body['routes'].isNotEmpty) {
        final leg = body['routes'][0]['legs'][0];
        return {
          'distance': leg['distance']['text'],
          'duration': leg['duration']['text'],
        };
      }
    }
    return null;
  }

  // 6. Open Google Maps (with name and lat/lng)
  Future<void> _openGoogleMaps(Place place) async {
    String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place.name)}@${place.lat},${place.lng}';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch Google Maps.')),
      );
    }
  }

  // 7. Call phone
  Future<void> _callPhone(String? contact) async {
    if (contact == null) return;
    final telUrl = 'tel:$contact';
    if (await canLaunch(telUrl)) {
      await launch(telUrl);
    }
  }

  // 8. Flip card design
  Widget _vetFlipCard(Place place) {
    return FutureBuilder<Map<String, String>?>(
      future: _getDistanceEta(place),
      builder: (context, snapshot) {
        final distance = snapshot.data?['distance'] ?? '-';
        final duration = snapshot.data?['duration'] ?? '-';
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          child: ExpansionTile(
            leading: Icon(
              place.is24hrs ? Icons.local_hospital : Icons.pets,
              color: place.is24hrs ? Colors.red : Colors.teal,
              size: 32,
            ),
            title: Text(
              place.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              place.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            children: [
              ListTile(
                title: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.teal, size: 20),
                    SizedBox(width: 4),
                    Expanded(
                        child: Text(place.address,
                            style: TextStyle(fontSize: 14))),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('$distance • $duration'),
                      ],
                    ),
                    if (place.contact != null)
                      GestureDetector(
                        onTap: () => _callPhone(place.contact),
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              place.contact!,
                              style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Tabs: Reviews, Photos, Google Maps
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reviews coming soon!')),
                        );
                      },
                      icon: Icon(Icons.reviews, color: Colors.teal),
                      label: Text('Reviews'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Photos coming soon!')),
                        );
                      },
                      icon: Icon(Icons.photo, color: Colors.teal),
                      label: Text('Photos'),
                    ),
                    TextButton.icon(
                      onPressed: () => _openGoogleMaps(place),
                      icon: Icon(Icons.map, color: Colors.teal),
                      label: Text('Open Map'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Places & Vets Nearby'),
        backgroundColor: Colors.teal[800],
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: "Locate Me",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'Search any place (e.g. "restaurant", "hospital")',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      prefixIcon: Icon(Icons.search),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    ),
                    onSubmitted: (value) {
                      _searchPlaces(value);
                    },
                  ),
                ),
                SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _find24hrEmergencyVet,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 10)),
                  icon: Icon(Icons.local_hospital, size: 20),
                  label: Text('24hr Vet'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _currentPosition == null
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude)
                          : LatLng(0, 0),
                      zoom: 14,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) {
                      if (!_mapController.isCompleted)
                        _mapController.complete(controller);
                    },
                  ),
          ),
          Expanded(
            flex: 3,
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _places.isEmpty
                    ? Center(
                        child: Text('No places found.\nTry searching above!',
                            textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (ctx, i) => _vetFlipCard(_places[i]),
                      ),
          ),
        ],
      ),
    );
  }
}
