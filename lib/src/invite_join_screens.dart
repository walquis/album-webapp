import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;
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

  String _getInviteLink(String token, String email) {
    if (kIsWeb) {
      // Get current origin (protocol + host + port)
      final origin = html.window.location.origin;
      return '$origin/accept-invite?token=$token&email=${Uri.encodeComponent(email)}';
    }
    // Fallback for non-web platforms
    return 'http://localhost:3000/accept-invite?token=$token&email=${Uri.encodeComponent(email)}';
  }

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
            'inviteLink': _getInviteLink(invite.token, email),
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
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if token/email provided via URL
    if (widget.token != null) tokenController.text = widget.token!;
    if (widget.email != null) emailController.text = widget.email!;
  }

  Future<void> _accept() async {
    if (!mounted) return;

    setState(() {
      error = null;
      _isLoading = true;
      _isSuccess = false;
    });

    final email = emailController.text.trim();
    final token = tokenController.text.trim();
    final inviteDoc = await _invites.validateInvite(email: email, token: token);
    if (inviteDoc == null) {
      if (mounted) {
        setState(() {
          error = 'Invalid invite';
          _isLoading = false;
        });
      }
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

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      }

      // Give a moment for the auth state to update, then the parent will redirect
      await Future.delayed(const Duration(seconds: 1));
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          _isLoading = false;
        });
      }
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
                if (_isSuccess) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Account created successfully!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Redirecting to your dashboard...'),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ] else ...[
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    enabled: !_isLoading,
                  ),
                  TextField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Invite token',
                    ),
                    enabled: !_isLoading,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                          ),
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                          ),
                          enabled: !_isLoading,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _accept,
                    child:
                        _isLoading
                            ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Creating account...'),
                              ],
                            )
                            : const Text('Create account and join'),
                  ),
                ],
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
