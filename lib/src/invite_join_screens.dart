import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? status;

  Future<void> _createEmailTemplate() async {
    // Create the email template if it doesn't exist
    final templateRef = FirebaseFirestore.instance
        .collection('emailTemplates')
        .doc('invite');
    final templateDoc = await templateRef.get();

    if (!templateDoc.exists) {
      await templateRef.set({
        'subject': 'You\'re invited to join {{familyId}} family album!',
        'html': '''
          <html>
            <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <h2 style="color: #333;">You're invited to join {{familyId}} family album!</h2>
              
              <p>Hello!</p>
              
              <p>You've been invited by {{adminEmail}} to join the <strong>{{familyId}}</strong> family album. This is a private space where your family can share photos and videos from special events.</p>
              
              <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <h3 style="margin-top: 0;">How to join:</h3>
                <ol>
                  <li>Click the link below to accept your invitation</li>
                  <li>Create your account with your first and last name</li>
                  <li>Start uploading and viewing family photos!</li>
                </ol>
              </div>
              
              <div style="text-align: center; margin: 30px 0;">
                <a href="{{inviteLink}}" 
                   style="background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
                  Accept Invitation
                </a>
              </div>
              
              <p style="color: #666; font-size: 14px;">
                If the button doesn't work, copy and paste this link into your browser:<br>
                <a href="{{inviteLink}}">{{inviteLink}}</a>
              </p>
              
              <p style="color: #666; font-size: 12px; margin-top: 30px;">
                This invitation was sent by {{adminEmail}}. If you didn't expect this invitation, you can safely ignore this email.
              </p>
            </body>
          </html>
        ''',
        'text': '''
          You're invited to join {{familyId}} family album!
          
          Hello!
          
          You've been invited by {{adminEmail}} to join the {{familyId}} family album. This is a private space where your family can share photos and videos from special events.
          
          How to join:
          1. Click the link below to accept your invitation
          2. Create your account with your first and last name  
          3. Start uploading and viewing family photos!
          
          Accept invitation: {{inviteLink}}
          
          This invitation was sent by {{adminEmail}}. If you didn't expect this invitation, you can safely ignore this email.
        ''',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _send() async {
    final email = emailController.text.trim();
    final familyId = familyController.text.trim();
    if (email.isEmpty || familyId.isEmpty) return;

    setState(() => status = 'Creating invite...');

    try {
      final invite = await _invites.createInvite(
        email: email,
        familyId: familyId,
      );

      // Ensure email template exists
      await _createEmailTemplate();

      // Queue email using firestore-send-email extension
      await FirebaseFirestore.instance.collection('mail').add({
        'to': email,
        'template': {
          'name': 'invite',
          'data': {
            'inviteToken': invite.token,
            'familyId': familyId,
            'inviteLink':
                'https://your-domain.com/accept-invite?token=${invite.token}&email=${Uri.encodeComponent(email)}',
            'adminEmail': FirebaseAuth.instance.currentUser?.email ?? 'admin',
          },
        },
      });

      setState(() {
        lastToken = invite.token;
        status = 'Invite sent to $email';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
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
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Invitee email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: familyController,
              decoration: const InputDecoration(labelText: 'Family ID'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _send, child: const Text('Send Invite')),
            if (status != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      status!.contains('Error')
                          ? Colors.red[50]
                          : Colors.green[50],
                  border: Border.all(
                    color:
                        status!.contains('Error') ? Colors.red : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status!,
                  style: TextStyle(
                    color:
                        status!.contains('Error')
                            ? Colors.red[800]
                            : Colors.green[800],
                  ),
                ),
              ),
            ],
            if (lastToken != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Invite Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Token: $lastToken'),
              const SizedBox(height: 8),
              const Text(
                'The invitee will receive an email with a link to join.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MemberAcceptInviteScreen extends StatefulWidget {
  const MemberAcceptInviteScreen({super.key, this.token, this.email});

  final String? token;
  final String? email;

  @override
  State<MemberAcceptInviteScreen> createState() =>
      _MemberAcceptInviteScreenState();
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

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if token/email provided via URL
    if (widget.token != null) tokenController.text = widget.token!;
    if (widget.email != null) emailController.text = widget.email!;
  }

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
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );
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
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(labelText: 'Invite token'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _accept,
                  child: const Text('Create account and join'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
