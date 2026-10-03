import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyA6EQChPz0nVd8VZtODQ7Qke855-8ttP04",
            authDomain: "surpl-app.firebaseapp.com",
            projectId: "surpl-app",
            storageBucket: "surpl-app.firebasestorage.app",
            messagingSenderId: "165451396509",
            appId: "1:165451396509:web:1eca2b0c4729e126ebab74"));
  } else {
    await Firebase.initializeApp();
  }
}
