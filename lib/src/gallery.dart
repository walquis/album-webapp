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
        stream:
            FirebaseFirestore.instance
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

          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          print('Found ${docs.length} media items');

          if (docs.isEmpty)
            return const Center(child: Text('No media yet for this event'));
          return SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(docs.length, (index) {
                final data = docs[index].data();
                final url = data['downloadUrl'] as String?;
                final thumbnailUrl = data['thumbnailUrl'] as String?;
                final uploaderEmail = data['uploaderEmail'] as String?;
                final fileType = data['fileType'] as String?;
                final fileName = data['fileName'] as String?;
                print(
                  'Gallery item $index: url=$url, thumbnail=$thumbnailUrl, uploader=$uploaderEmail',
                );
                print('File type: $fileType, File name: $fileName');

                return SizedBox(
                  width: 200, // Fixed width - never changes
                  height: 200, // Fixed height - never changes
                  child: Stack(
                    children: [
                      _buildMediaWidget(
                        url: url,
                        thumbnailUrl: thumbnailUrl,
                        fileType: fileType,
                        fileName: fileName,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              if (fileType == 'video')
                                const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              Expanded(
                                child: Text(
                                  uploaderEmail ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaWidget({
    String? url,
    String? thumbnailUrl,
    String? fileType,
    String? fileName,
  }) {
    if (url == null) {
      return const ColoredBox(color: Colors.grey);
    }

    // Use thumbnail for images if available, otherwise use original
    final displayUrl =
        (fileType == 'image' && thumbnailUrl != null) ? thumbnailUrl : url;

    if (fileType == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Video thumbnail or placeholder
          if (thumbnailUrl != null)
            ClipRect(
              child: Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Video thumbnail load error for $thumbnailUrl: $error');
                  return _buildErrorWidget(thumbnailUrl);
                },
                loadingBuilder:
                    (context, child, loadingProgress) => _buildLoadingWidget(),
              ),
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Icon(Icons.videocam, size: 48, color: Colors.grey),
            ),
          // Play button overlay
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      );
    } else {
      // Image
      return ClipRect(
        child: Image.network(
          displayUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Image load error for $displayUrl: $error');
            return _buildErrorWidget(displayUrl);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final progress =
                loadingProgress.cumulativeBytesLoaded /
                (loadingProgress.expectedTotalBytes ?? 1);
            return Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Loading... ${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Large image - may take a moment',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildErrorWidget(String url) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(height: 4),
          const Text(
            'Error loading',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          Text(
            url.length > 50 ? '${url.substring(0, 50)}...' : url,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () {
              // Open URL in new tab for debugging
              if (url.isNotEmpty) {
                // This will help debug if the URL is accessible
                print('Attempting to open URL: $url');
              }
            },
            child: const Text('Test URL', style: TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
