import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Apna Cloud Name yahan single quotes mein daalo
  static const String _cloudName = 'zu5p2wfv';
  static const String _uploadPreset = 'chatly_uploads';

  final CloudinaryPublic _cloudinary =
      CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

  Future<String?> uploadImage(File file) async {
    try {
      final response = await _cloudinary.uploadFile(CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
        folder: 'chatly/images',
      ));
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary image upload error: $e');
      return null;
    }
  }

  Future<String?> uploadVideo(File file) async {
    try {
      final response = await _cloudinary.uploadFile(CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Video,
        folder: 'chatly/videos',
      ));
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary video upload error: $e');
      return null;
    }
  }

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      final response = await _cloudinary.uploadFile(CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Auto,
        folder: 'chatly/files',
      ));
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary file upload error: $e');
      return null;
    }
  }
}
