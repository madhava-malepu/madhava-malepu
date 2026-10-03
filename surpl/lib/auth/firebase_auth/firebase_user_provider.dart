import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../base_auth_user_provider.dart';
import '/services/notification_service.dart';
import '/services/cart_service.dart';

export '../base_auth_user_provider.dart';

class SurplFirebaseUser extends BaseAuthUser {
  SurplFirebaseUser(this.user);
  User? user;
  bool get loggedIn => user != null;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: user?.uid,
        email: user?.email,
        displayName: user?.displayName,
        photoUrl: user?.photoURL,
        phoneNumber: user?.phoneNumber,
      );

  @override
  Future? delete() => user?.delete();

  @override
  Future? updateEmail(String email) => user?.verifyBeforeUpdateEmail(email);

  @override
  Future? updatePassword(String newPassword) async {
    await user?.updatePassword(newPassword);
  }

  @override
  Future? sendEmailVerification() => user?.sendEmailVerification();

  @override
  bool get emailVerified {
    // Reloads the user when checking in order to get the most up to date
    // email verified status.
    if (loggedIn && !user!.emailVerified) {
      refreshUser();
    }
    return user?.emailVerified ?? false;
  }

  @override
  Future refreshUser() async {
    await FirebaseAuth.instance.currentUser
        ?.reload()
        .then((_) => user = FirebaseAuth.instance.currentUser);
  }

  static BaseAuthUser fromUserCredential(UserCredential userCredential) =>
      fromFirebaseUser(userCredential.user);
  static BaseAuthUser fromFirebaseUser(User? user) => SurplFirebaseUser(user);
}

Stream<BaseAuthUser> surplFirebaseUserStream() => FirebaseAuth.instance
        .authStateChanges()
        .debounce((user) => user == null && !loggedIn
            ? TimerStream(true, const Duration(seconds: 1))
            : Stream.value(user))
        .map<BaseAuthUser>(
      (user) {
        currentUser = SurplFirebaseUser(user);
        // Fix for FCM tokens never being saved: the app-startup call in
        // main.dart runs before login, when currentUserUid is empty, so
        // it silently no-ops. This runs every time auth state changes to
        // a real, logged-in user - the point where the save actually
        // needs to happen for notifications to work at all.
        if (user != null) {
          NotificationService.saveTokenForCurrentUser();
        } else {
          // CartService is a global singleton, not scoped to a user
          // session. Clearing it here (not just on the explicit sign-out
          // button) catches every way a session can end - token expiry,
          // forced sign-out, or any other path - not only the one UI
          // button. Safe to call even if already empty.
          CartService().clear();
        }
        return currentUser!;
      },
    );
