import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarHelper {
  /// Returns true if photoUrl is a valid image
  static bool hasImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return false;
    return photoUrl.startsWith('data:image') ||
        photoUrl.startsWith('http');
  }

  /// Returns an ImageProvider for the given URL
  static ImageProvider? getImageProvider(String? photoUrl) {
    if (!hasImage(photoUrl)) return null;
    if (photoUrl!.startsWith('data:image')) {
      return MemoryImage(decodeBase64(photoUrl));
    }
    return CachedNetworkImageProvider(photoUrl);
  }

  /// Returns a Widget (for places where ImageProvider doesn't work)
  static Widget buildImage(String? photoUrl, {BoxFit fit = BoxFit.cover}) {
    if (!hasImage(photoUrl)) return const SizedBox.shrink();
    if (photoUrl!.startsWith('data:image')) {
      return Image.memory(decodeBase64(photoUrl), fit: fit);
    }
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: fit,
      placeholder: (c, u) => Container(color: Colors.grey[200]),
      errorWidget: (c, u, e) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.person, color: Colors.grey),
      ),
    );
  }

  static Uint8List decodeBase64(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
