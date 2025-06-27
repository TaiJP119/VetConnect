import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:VetApp/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:VetApp/features/user_auth/presentation/pages/login_page.dart';
import 'package:VetApp/features/user_auth/presentation/widgets/form_container_widget.dart';
import 'package:VetApp/global/common/toast.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactController =
      TextEditingController(); // Contact field
  final TextEditingController _addressController =
      TextEditingController(); // Address field

  bool isSigningUp = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose(); // Dispose contact field
    _addressController.dispose(); // Dispose address field
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("BEEt SignUp"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Sign Up",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              FormContainerWidget(
                controller: _usernameController,
                hintText: "Username",
                isPasswordField: false,
              ),
              const SizedBox(height: 10),
              FormContainerWidget(
                controller: _emailController,
                hintText: "Email",
                isPasswordField: false,
              ),
              const SizedBox(height: 10),
              FormContainerWidget(
                controller: _passwordController,
                hintText: "Password",
                isPasswordField: true,
              ),
              const SizedBox(height: 10),
              FormContainerWidget(
                controller: _contactController,
                hintText: "Contact Number",
                isPasswordField: false,
              ),
              const SizedBox(height: 10),
              FormContainerWidget(
                controller: _addressController,
                hintText: "Address",
                isPasswordField: false,
              ),
              const SizedBox(height: 30),
              if (isSigningUp)
                const CircularProgressIndicator(color: Colors.amber)
              else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: () => _signUp("customer"),
                  child: const Text(
                    "Register as Normal User",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: () => _signUp("pending_vet"),
                  child: const Text(
                    "Register as Vet",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold),
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

  // In sign-up logic (for assigning roles manually by the admin)
  // Sign-Up page logic remains mostly the same, just make sure these fields are used when creating the user.
  Future<void> _signUp(String role) async {
    setState(() => isSigningUp = true);

    String username = _usernameController.text;
    String email = _emailController.text;
    String password = _passwordController.text;
    String contact = _contactController.text;
    String address = _addressController.text;

    User? user = await _auth.signUpWithEmailAndPassword(email, password);

    if (user != null) {
      String finalRole = 'customer'; // Default role is customer
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['userRole'] == 'admin') {
          finalRole = 'admin'; // Preserve admin role
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'username': username,
        'userRole': finalRole,
        'contact': contact,
        'address': address,
      });

      // Save FCM Token after user creation
      await saveUserTokenToFirestore(user.uid);

      showToast(
          message: role == "pending_vet"
              ? "Vet registration successful. Awaiting admin approval."
              : "User successfully created.");
      Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
    } else {
      showToast(message: "Error during sign-up.");
    }

    setState(() => isSigningUp = false);
  }
}
