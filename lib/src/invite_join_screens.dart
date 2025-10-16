import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'services.dart';

class AdminInviteScreen extends StatefulWidget {
  const AdminInviteScreen({super.key});

  @override
  State<AdminInviteScreen> createState() => _AdminInviteScreenState();
}

class _AdminInviteScreenState extends State<AdminInviteScreen> {
  final emailController = TextEditingController();
  final familyController = TextEditingController();
  final InviteService _invites = InviteService();
  String? lastToken;

  Future<void> _send() async {
    final email = emailController.text.trim();
    final familyId = familyController.text.trim();
    if (email.isEmpty || familyId.isEmpty) return;
    final invite = await _invites.createInvite(email: email, familyId: familyId);
    setState(() => lastToken = invite.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Invite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Invitee email')),
            const SizedBox(height: 8),
            TextField(controller: familyController, decoration: const InputDecoration(labelText: 'Family ID')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _send, child: const Text('Create invite')),
            if (lastToken != null) ...[
              const SizedBox(height: 16),
              Text('Invite token: $lastToken'),
              const Text('Share invite link with email and token.'),
            ]
          ],
        ),
      ),
    );
  }
}

class MemberAcceptInviteScreen extends StatefulWidget {
  const MemberAcceptInviteScreen({super.key});

  @override
  State<MemberAcceptInviteScreen> createState() => _MemberAcceptInviteScreenState();
}

class _MemberAcceptInviteScreenState extends State<MemberAcceptInviteScreen> {
  final emailController = TextEditingController();
  final tokenController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final passwordController = TextEditingController();
  final InviteService _invites = InviteService();
  final UserService _users = UserService();
  String? error;

  Future<void> _accept() async {
    setState(() => error = null);
    final email = emailController.text.trim();
    final token = tokenController.text.trim();
    final inviteDoc = await _invites.validateInvite(email: email, token: token);
    if (inviteDoc == null) {
      setState(() => error = 'Invalid invite');
      return;
    }
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: passwordController.text);
      final user = cred.user!;
      final data = inviteDoc.data()!;
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        role: UserRole.member,
        familyId: data['familyId'] as String,
      );
      await _users.upsertUser(profile);
      await _invites.acceptInvite(inviteDoc.id, user.uid);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept Invite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: tokenController, decoration: const InputDecoration(labelText: 'Invite token')),
                Row(children: [
                  Expanded(child: TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First name'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last name'))),
                ]),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 12),
                FilledButton(onPressed: _accept, child: const Text('Create account and join')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


