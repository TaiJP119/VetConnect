import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:VetApp/features/user_auth/presentation/pages/sign_up_page.dart';
import 'package:VetApp/features/user_auth/presentation/widgets/form_container_widget.dart';
import 'package:VetApp/global/common/toast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_auth_implementation/firebase_auth_services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

Future<void> saveUserTokenToFirestore(String userId) async {
  final fcmToken = await FirebaseMessaging.instance.getToken();

  if (fcmToken != null) {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': fcmToken,
    });
  }
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigning = false;
  final FirebaseAuthService _auth = FirebaseAuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Welcome to BEE!"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Login",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 30,
              ),
              FormContainerWidget(
                controller: _emailController,
                hintText: "Email",
                isPasswordField: false,
              ),
              SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _passwordController,
                hintText: "Password",
                isPasswordField: true,
              ),
              SizedBox(
                height: 30,
              ),
              GestureDetector(
                onTap: () {
                  _signIn();
                },
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 238, 47, 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _isSigning
                        ? CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              GestureDetector(
                onTap: () {
                  _signInWithGoogle(context); // Pass context here
                },
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.google,
                          color: Colors.white,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          "Sign in with Google",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?"),
                  SizedBox(
                    width: 5,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                        (route) => false,
                      );
                    },
                    child: Text(
                      "Sign Up",
                      style: TextStyle(
                        color: const Color.fromRGBO(255, 238, 47, 1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _signIn() async {
    setState(() {
      _isSigning = true;
    });

    String email = _emailController.text;
    String password = _passwordController.text;

    User? user = await _auth.signInWithEmailAndPassword(email, password);

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = userDoc.data()?['userRole'];

      // Save FCM token to Firestore
      await saveUserTokenToFirestore(user.uid);

      switch (role) {
        case 'vet':
          Navigator.pushNamedAndRemoveUntil(
              context, "/vetHome", (route) => false);
          showToast(message: "Successfully signed in as Vet");
          break;
        case 'customer':
          Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
          showToast(message: "Successfully signed in as Customer");
          break;
        case 'admin':
          Navigator.pushNamedAndRemoveUntil(
              context, "/adminHome", (route) => false);
          showToast(message: "Successfully signed in as Admin");
          break;
        default:
          showToast(message: "Unknown role. Contact support.");
          await FirebaseAuth.instance.signOut();
      }
    } else {
      showToast(message: "Login failed");
    }

    setState(() {
      _isSigning = false;
    });
  }

  // Updated _signInWithGoogle method
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      User? user = await _auth.signInWithGoogle(context); // Sign in

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': user.email,
            'username': user.displayName ?? '',
            'userRole': 'customer',
            'contact': '',
            'address': '',
          });

          // ✅ Save FCM token after new account
          await saveUserTokenToFirestore(user.uid);

          showToast(message: "Account created. Signed in as Customer.");
          Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
          return;
        }

        final role = userDoc.data()?['userRole'];

        // ✅ Save FCM token for existing account
        await saveUserTokenToFirestore(user.uid);

        switch (role) {
          case 'vet':
            Navigator.pushNamedAndRemoveUntil(
                context, "/vetHome", (route) => false);
            showToast(message: "Successfully signed in as Vet");
            break;
          case 'customer':
            Navigator.pushNamedAndRemoveUntil(
                context, "/home", (route) => false);
            showToast(message: "Successfully signed in as Customer");
            break;
          case 'admin':
            Navigator.pushNamedAndRemoveUntil(
                context, "/adminHome", (route) => false);
            showToast(message: "Successfully signed in as Admin");
            break;
          case 'pending_vet':
            showToast(message: "Awaiting admin approval. Please wait.");
            await FirebaseAuth.instance.signOut();
            break;
          default:
            showToast(message: "Unknown role. Contact support.");
            await FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      showToast(message: "Error occurred while signing in with Google: $e");
    }
  }

  Future<void> saveUserTokenToFirestore(String userId) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();

    // Make sure the token is not null before saving it to Firestore
    if (fcmToken != null) {
      try {
        // Update the Firestore user's document with the FCM token
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': fcmToken,
        });
        print("FCM Token saved successfully for user: $userId");
      } catch (error) {
        print("Error saving FCM Token: $error");
      }
    } else {
      print("FCM Token is null");
    }
  }
}
