import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'metadata.dart';
import 'gallery.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('events').orderBy('startAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No events yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return ListTile(
                title: Text(data['name'] ?? 'Untitled'),
                subtitle: Text((data['startAt'] as Timestamp?)?.toDate().toString() ?? ''),
                onTap: () {
                  final id = docs[index].id;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventActions(eventId: id)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: const _CreateEventButton(),
    );
  }
}

class _CreateEventButton extends StatefulWidget {
  const _CreateEventButton();

  @override
  State<_CreateEventButton> createState() => _CreateEventButtonState();
}

class _CreateEventButtonState extends State<_CreateEventButton> {
  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New event'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await FirebaseFirestore.instance.collection('events').add({
      'name': name,
      'startAt': Timestamp.now(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _create,
      child: const Icon(Icons.add),
    );
  }
}

class EventActions extends StatelessWidget {
  const EventActions({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Actions')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UploadScreen(eventId: eventId))),
              child: const Text('Upload to this event'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventGalleryScreen(eventId: eventId))),
              child: const Text('View gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, this.eventId});
  final String? eventId;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? status;

  Future<void> _pickAndUpload() async {
    setState(() => status = 'Picking files...');
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.any);
    if (result == null) {
      setState(() => status = 'Cancelled');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => status = 'Uploading ${result.files.length} file(s)...');
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final meta = extractFromImageBytes(bytes);
      final ref = FirebaseStorage.instance.ref().child('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await ref.putData(bytes, SettableMetadata(customMetadata: {
        'uploadedBy': user.uid,
        'originalName': file.name,
      }));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('media').add({
        'uploaderUid': user.uid,
        'uploaderEmail': user.email,
        'uploadedAt': Timestamp.now(),
        'downloadUrl': url,
        'fileName': file.name,
        'mimeType': file.extension,
        'eventId': widget.eventId,
        'takenAt': meta.takenAt,
        'geo': meta.geo,
      });
    }
    setState(() => status = 'Done');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(onPressed: _pickAndUpload, child: const Text('Pick files and upload')),
            if (status != null) Padding(padding: const EdgeInsets.all(12), child: Text(status!)),
          ],
        ),
      ),
    );
  }
}


