import 'dart:async';

import 'package:TimeliNUS/models/userModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
// Thrown if during the sign up process if a failure occurs.

class AuthenticationFailture implements Exception {
  String cause;
  AuthenticationFailture(this.cause);

  @override
  String toString() {
    return "Authentication Failure: " + cause;
  }
}

class SignUpFailure implements AuthenticationFailture {
  String cause;
  SignUpFailure(this.cause);
}

/// Thrown during the login process if a failure occurs.
class LogInWithEmailAndPasswordFailure implements Exception {}

/// Thrown during the sign in with google process if a failure occurs.
class LogInWithGoogleFailure implements Exception {}

/// Thrown during the logout process if a failure occurs.
class LogOutFailure implements Exception {}

class AuthenticationRepository {
  /// {@macro authentication_repository}
  AuthenticationRepository({
    FirebaseAuth.FirebaseAuth firebaseAuth,
    GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.FirebaseAuth.instance;
  // _googleSignIn = googleSignIn ??
  //     GoogleSignIn(
  //       scopes: [
  //         'email',
  //         'https://www.googleapis.com/auth/calendar',
  //       ],
  // );

  final FirebaseAuth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
    ],
  );
  User _currentUser;

  /// Stream of [User] which will emit the current user when
  /// the authentication state changes.
  ///
  /// Emits [User.empty] if the user is not authenticated.
  Stream<User> get user {
    return _firebaseAuth.userChanges().map((firebaseUser) {
      final user = firebaseUser == null ? User.empty : firebaseUser.toUser;
      _currentUser = user;
      return user;
    });
  }

  /// Returns the current cached user.
  /// Defaults to [User.empty] if there is no cached user.
  User get currentUser {
    return _currentUser;
  }

  /// Creates a new user with the provided [email] and [password].
  ///
  /// Throws a [SignUpFailure] if an exception occurs.
  Future<void> signUp({@required String email, @required String password, @required String name}) async {
    try {
      FirebaseAuth.UserCredential credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      List<Future> promises = [];
      promises.add(credential.user.updateProfile(displayName: name));
      promises.add(FirebaseFirestore.instance
          .collection('user')
          .doc(credential.user.uid)
          .set({'name': name, 'email': email, 'project': [], 'todo': [], 'meeting': []}));
      Future.wait(promises);
      // await _firebaseAuth.signOut();
      print(_firebaseAuth.currentUser);
    } on FirebaseAuth.FirebaseAuthException catch (err) {
      throw AuthenticationFailture(err.code);
    }
  }

  /// Starts the Sign In with Google Flow.
  ///
  /// Throws a [logInWithGoogle] if an exception occurs.
  Future<void> logInWithGoogle() async {
    try {
      final storage = new FlutterSecureStorage();
      print('scopes : ' + _googleSignIn.scopes.toString());
      final googleUser = await _googleSignIn.signIn();
      final googleAuth = await googleUser.authentication;
      final credential = FirebaseAuth.GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      print('writing access: ' + credential.accessToken);
      await storage.write(key: 'accessToken', value: credential.accessToken);
      FirebaseAuth.UserCredential cred = await _firebaseAuth.signInWithCredential(credential);
      await (FirebaseFirestore.instance
          .collection('user')
          .doc(cred.user.uid)
          .set({'name': cred.user.displayName, 'email': cred.user.email, 'project': [], 'todo': [], 'meeting': []}));
    } on FirebaseAuth.FirebaseAuthException catch (err) {
      throw AuthenticationFailture(err.code);
    }
  }

  /// Signs in with the provided [email] and [password].
  ///
  /// Throws a [LogInWithEmailAndPasswordFailure] if an exception occurs.
  Future<void> logInWithEmailAndPassword({
    @required String email,
    @required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuth.FirebaseAuthException catch (err) {
      throw AuthenticationFailture(err.code);
    }
  }

  /// Signs out the current user which will emit
  /// [User.empty] from the [user] Stream.
  ///
  /// Throws a [LogOutFailure] if an exception occurs.
  Future<void> logOut() async {
    try {
      await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut(), _googleSignIn.disconnect()]);
    } on Exception {
      throw LogOutFailure();
    }
  }

  Future<void> saveTokenToDatabase(String token, String userId) async {
    // Assume user is logged in for this example
    // String userId = FirebaseAuth.FirebaseAuth.instance.currentUser.uid;
    await FirebaseFirestore.instance.collection('user').doc(userId).update({
      'tokens': FieldValue.arrayUnion([token]),
    });
  }

  static Future<List<User>> findUsersByRef(List<dynamic> refs) async {
    List<User> users = [];
    for (DocumentReference documentReference in refs) {
      final DocumentSnapshot temp = await documentReference.get();
      User documentSnapshotTask = User.fromJson(temp.data(), temp.id, ref: temp.reference);
      users.add(documentSnapshotTask);
    }
    return users;
  }

  Future<void> updateProfilePicture(String url) async {
    // Assume user is logged in for this example
    // String userId = FirebaseAuth.FirebaseAuth.instance.currentUser.uid;
    await _firebaseAuth.currentUser.updateProfile(photoURL: url);
    await FirebaseFirestore.instance.collection('user').doc(_firebaseAuth.currentUser.uid).update({
      'photoURL': url,
    });
  }

  Future<void> refreshToken() async {
    print("Token Refresh");
    final storage = new FlutterSecureStorage();
    final GoogleSignInAccount googleSignInAccount = await _googleSignIn.signInSilently();
    final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
    print('refreshToken: ' + googleSignInAuthentication.serverAuthCode);
    print('accessToken: ' + googleSignInAuthentication.accessToken);

    final FirebaseAuth.AuthCredential credential = FirebaseAuth.GoogleAuthProvider.credential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );
    FirebaseAuth.UserCredential cred = await _firebaseAuth.signInWithCredential(credential);
    await storage.write(key: 'accessToken', value: googleSignInAuthentication.accessToken);
    // return googleSignInAuthentication.accessToken; // New refreshed token
    return;
  }
}

extension on FirebaseAuth.User {
  User get toUser {
    return User(
        id: uid,
        email: email,
        name: displayName,
        ref: FirebaseFirestore.instance.collection('user').doc(uid),
        profilePicture: (photoURL ?? 'https://via.placeholder.com/500x500'));
  }
}
