import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;
import 'screens.dart';
import 'invite_join_screens.dart';

class AlbumWebApp extends StatelessWidget {
  const AlbumWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Album',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _RootRouter(),
      routes: {'/accept-invite': (context) => const _AcceptInviteRoute()},
      onGenerateRoute: (settings) {
        // Handle hash-based routing for web
        if (kIsWeb && settings.name != null) {
          final uri = Uri.parse(settings.name!);
          if (uri.path == '/accept-invite') {
            return MaterialPageRoute(
              builder: (context) => const _AcceptInviteRoute(),
              settings: settings,
            );
          }
        }
        return null;
      },
    );
  }
}

class _AcceptInviteRoute extends StatefulWidget {
  const _AcceptInviteRoute();

  @override
  State<_AcceptInviteRoute> createState() => _AcceptInviteRouteState();
}

class _AcceptInviteRouteState extends State<_AcceptInviteRoute> {
  String? token;
  String? email;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _parseUrlParameters();
  }

  void _parseUrlParameters() {
    if (kIsWeb) {
      // Parse URL parameters from the current URL
      final uri = Uri.parse(html.window.location.href);
      token = uri.queryParameters['token'];
      email = uri.queryParameters['email'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // If user is logged in, show a success message and redirect
        if (authSnapshot.hasData) {
          // Auto-redirect after a short delay (only once)
          if (!_hasRedirected) {
            _hasRedirected = true;
            Future.delayed(const Duration(seconds: 2), () {
              if (kIsWeb) {
                html.window.history.pushState(null, '', '/');
                html.window.location.reload();
              }
            });
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Welcome!')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the main app by changing the URL
                      if (kIsWeb && !_hasRedirected) {
                        _hasRedirected = true;
                        html.window.history.pushState(null, '', '/');
                        html.window.location.reload();
                      }
                    },
                    child: const Text('Go to Dashboard'),
                  ),
                ],
              ),
            ),
          );
        }

        // If no token/email, show error
        if (token == null || email == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Accept Invitation')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Invalid invite link. Please check your email for the correct link.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const _LoginScreen(),
                          ),
                        ),
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show invite acceptance form
        return Scaffold(
          appBar: AppBar(title: const Text('Accept Invitation')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Welcome! Please complete your account setup:'),
                const SizedBox(height: 16),
                Expanded(
                  child: MemberAcceptInviteScreen(token: token, email: email),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    // Check if this is an invite link first
    if (kIsWeb) {
      final uri = Uri.parse(html.window.location.href);
      if (uri.path.contains('accept-invite') ||
          uri.fragment.contains('accept-invite')) {
        return const _AcceptInviteRoute();
      }
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const _LoginScreen();
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = userSnap.data?.data()?['role'] as String?;
            if (role == 'admin') {
              return const AdminHome();
            }
            return const MemberHome();
          },
        );
      },
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;

  Future<void> _login() async {
    setState(() => error = null);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _login, child: const Text('Sign in')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome();

  Future<void> _showEventSelector(BuildContext context) async {
    // Get list of events
    final eventsSnapshot =
        await FirebaseFirestore.instance
            .collection('events')
            .orderBy('startAt', descending: true)
            .get();

    if (eventsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No events found. Create an event first.'),
        ),
      );
      return;
    }

    // Show event selection dialog
    final selectedEventId = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Event'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eventsSnapshot.docs.length,
                itemBuilder: (context, index) {
                  final doc = eventsSnapshot.docs[index];
                  final data = doc.data();
                  return ListTile(
                    title: Text(data['name'] ?? 'Untitled'),
                    subtitle: Text(
                      (data['startAt'] as Timestamp?)?.toDate().toString() ??
                          '',
                    ),
                    onTap: () => Navigator.pop(context, doc.id),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (selectedEventId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadScreen(eventId: selectedEventId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EventsScreen()),
                  ),
              child: const Text('Manage events'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminInviteScreen(),
                    ),
                  ),
              child: const Text('Send invite'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showEventSelector(context),
              child: const Text('Upload media'),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberHome extends StatelessWidget {
  const MemberHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EventsScreen()),
                  ),
              child: const Text('View events'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberAcceptInviteScreen(),
                    ),
                  ),
              child: const Text('Accept invite'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  ),
              child: const Text('Upload media'),
            ),
          ],
        ),
      ),
    );
  }
}
