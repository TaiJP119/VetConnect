import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget? child;
  const SplashScreen({super.key, this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => widget.child!),
          (route) => false);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // body: Center(
      //   child: Text(
      //     "Bee app",
      //     style: TextStyle(
      //       color: const Color.fromRGBO(255, 238, 47, 1),
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      // ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Bee app",
              style: TextStyle(
                color: const Color.fromRGBO(255, 238, 47, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
            Image.asset('assets/images/bee_logo.jpg', width: 120),
            SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromRGBO(255, 238, 47, 1)),
            ),
          ],
        ),
      ),

    );
  }
}
