import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
                .orderBy('takenAt', descending: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

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
                final fileType = data['fileType'] as String?;
                final fileName = data['fileName'] as String?;

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
                        // Delete button (appears on hover)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _HoverDeleteButton(
                            onDelete:
                                () => _showDeleteDialog(context, docs[index]),
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

  void _showDeleteDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final fileName = data['fileName'] as String? ?? 'this image';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Image'),
            content: Text('Are you sure you want to delete "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteImage(context, doc);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteImage(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final data = doc.data();
      final downloadUrl = data['downloadUrl'] as String?;
      final thumbnailUrl = data['thumbnailUrl'] as String?;

      // Delete from Firebase Storage
      if (downloadUrl != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(downloadUrl);
          await ref.delete();
        } catch (e) {
          // Error deleting main image, continue
        }
      }

      if (thumbnailUrl != null) {
        try {
          final thumbnailRef = FirebaseStorage.instance.refFromURL(
            thumbnailUrl,
          );
          await thumbnailRef.delete();
        } catch (e) {
          // Error deleting thumbnail, continue
        }
      }

      // Delete from Firestore (this triggers rebuild)
      await doc.reference.delete();

      // Show success message if context is still mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
      }
    } catch (e) {
      // Show error message if context is still mounted
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting image: $e')));
      }
    }
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                thumbnailUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          displayUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
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
                // Handle video tap - could open in new tab or show video player
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
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _focusNode = FocusNode();
    // Request focus after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_currentIndex + 1} of ${widget.mediaDocs.length}'),
            const Text(
              'Use arrow keys to navigate, ESC to exit',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _previousImage();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _nextImage();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
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

class _HoverDeleteButton extends StatefulWidget {
  const _HoverDeleteButton({required this.onDelete});

  final VoidCallback onDelete;

  @override
  State<_HoverDeleteButton> createState() => _HoverDeleteButtonState();
}

class _HoverDeleteButtonState extends State<_HoverDeleteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: _isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
      ),
    );
  }
}
