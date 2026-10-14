import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
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
      print('❌ IMAGE ERROR: $e');
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
      print('❌ VIDEO ERROR: $e');
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
      print('❌ FILE ERROR: $e');
      return null;
    }
  }

  Future<String?> uploadVoice(File file) async {
    try {
      final response = await _cloudinary.uploadFile(CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Video,
        folder: 'chatly/voice',
      ));
      return response.secureUrl;
    } catch (e) {
      print('❌ VOICE ERROR: $e');
      return null;
    }
  }
}
