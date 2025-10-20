
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 


import 'views/auth/auth_page.dart';


import 'views/dashboards/owner_dashboard.dart';
import 'views/dashboards/vet_dashboard.dart';
import 'views/dashboards/shelter_dashboard.dart';


import 'views/owner/pets_screen.dart';


import 'views/vet/appointments_view.dart';

import 'views/shelter/listings_view.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  Widget _getInitialScreen() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection("users").doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            String role = snapshot.data!["role"];
            switch (role) {
              case "Vet":
                return const VetDashboard();
              case "Shelter":
                return const ShelterDashboard();
              default:
                return const OwnerDashboard();
            }
          } else {
            return const AuthPage();
          }
        },
      );
    } else {
     
      return const AuthPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawfectCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: _getInitialScreen(),
      routes: {
        '/owner': (context) => const OwnerDashboard(),
        '/vet': (context) => const VetDashboard(),
        '/shelter': (context) => const ShelterDashboard(),

        '/pets': (context) => const PetsScreen(),

        '/vetAppointments': (context) => const AppointmentScreen(),

        '/shelterListings': (context) => const ListingsView(),
      },
    );
  }
}
