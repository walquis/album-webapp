import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'metadata.dart';
import 'gallery.dart';
import 'image_utils.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('events')
                .orderBy('startAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No events yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return ListTile(
                title: Text(data['name'] ?? 'Untitled'),
                subtitle: Text(
                  (data['startAt'] as Timestamp?)?.toDate().toString() ?? '',
                ),
                onTap: () {
                  final id = docs[index].id;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventActions(eventId: id),
                    ),
                  );
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
      builder:
          (context) => AlertDialog(
            title: const Text('New event'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Create'),
              ),
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
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UploadScreen(eventId: eventId),
                    ),
                  ),
              child: const Text('Upload to this event'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventGalleryScreen(eventId: eventId),
                    ),
                  ),
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
  List<PlatformFile> selectedFiles = [];
  bool isProcessing = false;

  Future<void> _pickFiles() async {
    setState(() => status = 'Picking files...');
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => status = 'No files selected');
        return;
      }

      // Validate files
      List<PlatformFile> validFiles = [];
      List<String> invalidFiles = [];

      for (final file in result.files) {
        if (file.bytes == null) {
          invalidFiles.add('${file.name} (no data)');
          continue;
        }

        if (!ImageUtils.isValidFileType(file.name)) {
          invalidFiles.add('${file.name} (unsupported type)');
          continue;
        }

        if (!ImageUtils.isValidFileSize(file.bytes!.length)) {
          invalidFiles.add(
            '${file.name} (too large: ${ImageUtils.formatFileSize(file.bytes!.length)})',
          );
          continue;
        }

        validFiles.add(file);
      }

      setState(() {
        selectedFiles = validFiles;
        if (invalidFiles.isNotEmpty) {
          status = 'Invalid files: ${invalidFiles.join(', ')}';
        } else {
          status = 'Selected ${validFiles.length} valid file(s)';
        }
      });
    } catch (e) {
      setState(() => status = 'Error picking files: $e');
    }
  }

  Future<void> _uploadFiles() async {
    if (selectedFiles.isEmpty) {
      setState(() => status = 'No files selected');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => status = 'Not logged in');
      return;
    }

    setState(() {
      isProcessing = true;
      status = 'Processing and uploading ${selectedFiles.length} file(s)...';
    });

    int successCount = 0;
    int errorCount = 0;

    for (int i = 0; i < selectedFiles.length; i++) {
      final file = selectedFiles[i];
      try {
        setState(
          () =>
              status =
                  'Processing file ${i + 1}/${selectedFiles.length}: ${file.name}',
        );

        Uint8List? processedBytes = file.bytes!;
        Uint8List? thumbnailBytes;

        // Process image files
        if (ImageUtils.isImage(file.name)) {
          // Skip compression for small files to speed up upload
          if (file.bytes!.length < 2 * 1024 * 1024) {
            // Less than 2MB
            setState(
              () =>
                  status =
                      'Processing image ${i + 1}/${selectedFiles.length}: ${file.name} (skipping compression)',
            );
            processedBytes = file.bytes!; // Use original file
          } else {
            setState(
              () =>
                  status =
                      'Compressing image ${i + 1}/${selectedFiles.length}: ${file.name}',
            );

            // Compress image with aggressive settings for maximum speed
            processedBytes = await ImageUtils.compressImage(
              file.bytes!,
              quality: 50, // Very aggressive compression for speed
              maxWidth: 1000, // Smaller max size for faster processing
              maxHeight: 1000,
            );
          }

          setState(
            () =>
                status =
                    'Generating thumbnail ${i + 1}/${selectedFiles.length}: ${file.name}',
          );

          // Generate thumbnail
          thumbnailBytes = await ImageUtils.generateThumbnail(file.bytes!);
        }

        // Upload original/compressed file
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final originalRef = FirebaseStorage.instance.ref().child(
          'uploads/${user.uid}/${timestamp}_${file.name}',
        );

        setState(
          () =>
              status =
                  'Uploading file ${i + 1}/${selectedFiles.length}: ${file.name}',
        );

        final uploadTask = originalRef.putData(
          processedBytes!,
          SettableMetadata(
            customMetadata: {
              'uploadedBy': user.uid,
              'originalName': file.name,
              'fileType': ImageUtils.isImage(file.name) ? 'image' : 'video',
            },
          ),
        );

        await uploadTask.timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw Exception('Upload timeout for ${file.name}'),
        );

        final originalUrl = await originalRef.getDownloadURL();

        // Upload thumbnail if available
        String? thumbnailUrl;
        if (thumbnailBytes != null) {
          final thumbnailRef = FirebaseStorage.instance.ref().child(
            'thumbnails/${user.uid}/${timestamp}_thumb_${file.name}',
          );

          await thumbnailRef.putData(thumbnailBytes);
          thumbnailUrl = await thumbnailRef.getDownloadURL();
        }

        // Save to Firestore
        final meta = extractFromImageBytes(file.bytes!);
        await FirebaseFirestore.instance.collection('media').add({
          'uploaderUid': user.uid,
          'uploaderEmail': user.email,
          'uploadedAt': Timestamp.now(),
          'downloadUrl': originalUrl,
          'thumbnailUrl': thumbnailUrl,
          'fileName': file.name,
          'mimeType': file.extension,
          'fileType': ImageUtils.isImage(file.name) ? 'image' : 'video',
          'fileSize': processedBytes.length,
          'originalFileSize': file.bytes!.length,
          'eventId': widget.eventId,
          'takenAt': meta.takenAt,
          'geo': meta.geo,
        });

        successCount++;
        print('Successfully uploaded: ${file.name}');
      } catch (e) {
        errorCount++;
        print('Error uploading ${file.name}: $e');
        setState(() => status = 'Error uploading ${file.name}: $e');
      }
    }

    setState(() {
      isProcessing = false;
      selectedFiles.clear();
      status = 'Upload complete: $successCount successful, $errorCount failed';
    });
  }

  void _clearSelection() {
    setState(() {
      selectedFiles.clear();
      status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  32, // Account for app bar and padding
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File selection section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Files',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supported: Images (JPEG, PNG, GIF, WebP) and Videos (MP4, AVI, MOV, etc.)\nMax size: 10MB per file',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: isProcessing ? null : _pickFiles,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Pick Files'),
                            ),
                            if (selectedFiles.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed:
                                    isProcessing ? null : _clearSelection,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected files list
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Files (${selectedFiles.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height *
                                  0.3, // Max 30% of screen height
                              minHeight: 100,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: selectedFiles.length,
                              itemBuilder: (context, index) {
                                final file = selectedFiles[index];
                                final fileSize = ImageUtils.formatFileSize(
                                  file.bytes!.length,
                                );
                                final fileIcon = ImageUtils.getFileTypeIcon(
                                  file.name,
                                );

                                return ListTile(
                                  leading: Text(
                                    fileIcon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(fileSize),
                                  trailing:
                                      ImageUtils.isImage(file.name)
                                          ? const Icon(
                                            Icons.image,
                                            color: Colors.blue,
                                          )
                                          : const Icon(
                                            Icons.videocam,
                                            color: Colors.red,
                                          ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Upload section
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (widget.eventId != null)
                            Text(
                              'Uploading to event: ${widget.eventId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isProcessing ? null : _uploadFiles,
                              icon:
                                  isProcessing
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.cloud_upload),
                              label: Text(
                                isProcessing ? 'Processing...' : 'Upload Files',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Status section
                if (status != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color:
                        status!.contains('Error') || status!.contains('Invalid')
                            ? Colors.red[50]
                            : Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            status!.contains('Error') ||
                                    status!.contains('Invalid')
                                ? Icons.error
                                : Icons.info,
                            color:
                                status!.contains('Error') ||
                                        status!.contains('Invalid')
                                    ? Colors.red
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status!,
                              style: TextStyle(
                                color:
                                    status!.contains('Error') ||
                                            status!.contains('Invalid')
                                        ? Colors.red[800]
                                        : Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
