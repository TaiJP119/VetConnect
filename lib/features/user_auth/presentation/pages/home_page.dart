import 'package:VetApp/features/user_auth/presentation/pages/ai_page.dart';
import 'package:VetApp/features/user_auth/presentation/pages/vet_finder_page.dart';
import 'package:VetApp/widget/notification_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../global/common/toast.dart';
import '../../../../features/pet_management/models/pet_model.dart';
import '../../../../features/pet_management/screens/pet_profile_page.dart';
import '../../presentation/pages/calendar_page.dart';
import '../../presentation/pages/profile_page.dart'; // Make sure this exists

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Pages to display in each tab
  late final List<Widget> _pages;
//bottom icon change here also
  @override
  void initState() {
    super.initState();
    _pages = [
      _buildPetListPage(),
      const CalendarPage(),
      const AIPage(),
      VetFinderPage(),
      const ProfilePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildPetListPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Pets"),
        automaticallyImplyLeading: false,
        actions: [
          NotificationIcon(userId: FirebaseAuth.instance.currentUser!.uid),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, "/login", (route) => false);
              showToast(message: "Successfully signed out");
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Auto-sliding Banner Carousel ----
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return SizedBox(); // No banners

              final banners = snapshot.data!.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: CarouselSlider.builder(
                  itemCount: banners.length,
                  options: CarouselOptions(
                    height: 105,
                    autoPlay: true,
                    enlargeCenterPage: true,
                    viewportFraction: 0.92,
                    autoPlayInterval: Duration(seconds: 4),
                    enableInfiniteScroll: banners.length > 1,
                    enlargeStrategy: CenterPageEnlargeStrategy.height,
                    aspectRatio: 16 / 4,
                  ),
                  itemBuilder: (context, i, realIdx) {
                    final ann = banners[i];
                    final String banner = ann['banner'] ?? 'Announcement';
                    final String message = ann['message'] ?? '';
                    final String? url = ann['url']; // optional link field
                    final String? imageUrl =
                        ann['imageUrl']; // <-- get image url

                    return Material(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // --- Image Section with its own tap behavior ---
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.broken_image,
                                                    color: Colors.white70,
                                                    size: 48),
                                                Text('Could not load image',
                                                    style: TextStyle(
                                                        color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                            Icons.image_not_supported,
                                            size: 48),
                                  ),
                                ),
                              )
                            else
                              Icon(Icons.campaign,
                                  color: Colors.amber[900], size: 48),

                            SizedBox(width: 10),

                            // --- Text Section with its own tap handler ---
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  if (url != null && url.isNotEmpty) {
                                    final uri = Uri.tryParse(url);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Could not open link.')),
                                      );
                                    }
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(banner),
                                        content: Text(message),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text("Close"),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      banner,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      message.length > 48
                                          ? message.substring(0, 48) + "..."
                                          : message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.brown[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // --- Chevron Icon for visual cue (optional) ---
                            Icon(Icons.chevron_right, color: Colors.amber[900]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // ---- Pet List (as before)
          Expanded(
            child: StreamBuilder<List<PetModel>>(
              stream: _readPets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const Center(child: Text("No pets added yet."));

                final pets = snapshot.data!;
                return ListView.builder(
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(pet.name ?? "Unnamed Pet"),
                      subtitle: Text(pet.species ?? ""),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PetProfilePage(pet: pet),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(255, 238, 47, 1),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.pushNamed(context, "/addPet");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[600],
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'AI assist',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'MAP'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Stream<List<PetModel>> _readPets() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final petsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("pets");

    return petsRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => PetModel.fromSnapshot(doc)).toList());
  }
}
