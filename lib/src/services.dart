import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class InviteService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final Random _rng = Random.secure();

  String _generateToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
  }

  Future<Invite> createInvite({required String email, required String familyId}) async {
    final token = _generateToken();
    final doc = await _db.collection('invites').add({
      'email': email.toLowerCase(),
      'familyId': familyId,
      'token': token,
      'createdBy': _auth.currentUser?.uid,
      'status': InviteStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return Invite(
      id: doc.id,
      email: email.toLowerCase(),
      familyId: familyId,
      token: token,
      createdBy: _auth.currentUser!.uid,
      status: InviteStatus.pending,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> validateInvite({required String email, required String token}) async {
    final snap = await _db
        .collection('invites')
        .where('email', isEqualTo: email.toLowerCase())
        .where('token', isEqualTo: token)
        .where('status', isEqualTo: InviteStatus.pending)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  Future<void> acceptInvite(String inviteId, String userId) async {
    await _db.collection('invites').doc(inviteId).update({
      'status': InviteStatus.accepted,
      'acceptedBy': userId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }
}

class UserService {
  final _db = FirebaseFirestore.instance;

  Future<void> upsertUser(UserProfile user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }
}


