import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventGalleryScreen extends StatelessWidget {
  const EventGalleryScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Gallery')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('media')
            .where('eventId', isEqualTo: eventId)
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No media yet'));
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final url = data['downloadUrl'] as String?;
              final uploaderEmail = data['uploaderEmail'] as String?;
              return GridTile(
                footer: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    uploaderEmail ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                child: url == null
                    ? const ColoredBox(color: Colors.grey)
                    : Image.network(url, fit: BoxFit.cover),
              );
            },
          );
        },
      ),
    );
  }
}


