class UserRole {
  static const admin = 'admin';
  static const member = 'member';
}

class UserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? familyId;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.familyId,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'familyId': familyId,
      };
}

class InviteStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const revoked = 'revoked';
}

class Invite {
  final String id;
  final String email;
  final String familyId;
  final String token;
  final String createdBy;
  final String status;

  const Invite({
    required this.id,
    required this.email,
    required this.familyId,
    required this.token,
    required this.createdBy,
    required this.status,
  });
}


