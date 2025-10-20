import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

                return GestureDetector(
                  onTap: () => _openCarousel(context, docs, index),
                  child: SizedBox(
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
                        if (fileType == 'video')
                          const Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  void _openCarousel(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => MediaCarouselScreen(
              mediaDocs: docs,
              initialIndex: initialIndex,
            ),
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

class MediaCarouselScreen extends StatefulWidget {
  const MediaCarouselScreen({
    super.key,
    required this.mediaDocs,
    required this.initialIndex,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> mediaDocs;
  final int initialIndex;

  @override
  State<MediaCarouselScreen> createState() => _MediaCarouselScreenState();
}

class _MediaCarouselScreenState extends State<MediaCarouselScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.mediaDocs.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} of ${widget.mediaDocs.length}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _previousImage();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _nextImage();
            }
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.mediaDocs.length,
              itemBuilder: (context, index) {
                final data = widget.mediaDocs[index].data();
                final url = data['downloadUrl'] as String?;
                final uploaderEmail = data['uploaderEmail'] as String?;
                final fileType = data['fileType'] as String?;
                final fileName = data['fileName'] as String?;

                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Stack(
                      children: [
                        if (url != null)
                          Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 48,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Error loading image',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Text(
                                'No image available',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        // Uploader info overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                if (fileType == 'video')
                                  const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Uploaded by: ${uploaderEmail ?? 'Unknown'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  fileName ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Navigation arrows
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _previousImage,
                    backgroundColor: Colors.black54,
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.mediaDocs.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _nextImage,
                    backgroundColor: Colors.black54,
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
