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
          print('Gallery snapshot state: ${snapshot.connectionState}');
          print('Gallery snapshot data: ${snapshot.data?.docs.length}');
          print('Looking for eventId: $eventId');
          
          if (snapshot.hasError) {
            print('Gallery error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          print('Found ${docs.length} media items');
          
          if (docs.isEmpty) return const Center(child: Text('No media yet for this event'));
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
              print('Gallery item $index: url=$url, uploader=$uploaderEmail');
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
                    : Image.network(
                        url, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image load error for $url: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(height: 4),
                                Text(
                                  'Error loading image',
                                  style: TextStyle(fontSize: 10, color: Colors.red),
                                ),
                                Text(
                                  url.length > 50 ? '${url.substring(0, 50)}...' : url,
                                  style: TextStyle(fontSize: 8, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
              );
            },
          );
        },
      ),
    );
  }
}


