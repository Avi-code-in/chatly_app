import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String? senderName;
  final String? timestamp;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    this.senderName,
    this.timestamp,
  });

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        await Gal.putImageBytes(
          response.bodyBytes,
          name: 'Chatly_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved to gallery!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: senderName != null
            ? Text(
                senderName!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Save to gallery',
            onPressed: () => _saveToGallery(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (c, u) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (c, u, e) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image,
                        color: Colors.white54, size: 60),
                    SizedBox(height: 12),
                    Text('Failed to load',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function — tap any URL to view fullscreen
void showFullScreenImage(
  BuildContext context,
  String imageUrl, {
  String? senderName,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullScreenImage(
        imageUrl: imageUrl,
        senderName: senderName,
      ),
    ),
  );
}

/// Avatar tap helper - view profile picture fullscreen
void showProfilePicture(
  BuildContext context, {
  required String name,
  String? photoUrl,
  String? subtitle,
}) {
  if (photoUrl == null || photoUrl.isEmpty) return;

  Widget imageWidget;
  if (photoUrl.startsWith('data:image')) {
    imageWidget = Image.memory(
      _decodeBase64(photoUrl),
      fit: BoxFit.cover,
    );
  } else {
    imageWidget = CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      placeholder: (c, u) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (c, u, e) => const Icon(Icons.person,
          color: Colors.white54, size: 100),
    );
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: AspectRatio(
                aspectRatio: 1,
                child: imageWidget,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Uint8List _decodeBase64(String dataUrl) {
  return base64Decode(dataUrl.split(',').last);
}
