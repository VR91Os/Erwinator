import 'package:flutter/material.dart';

const photoExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};
const videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};

String fileExtensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
}

String fileNameWithoutExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? fileName : fileName.substring(0, dot);
}

// Erkennt den Dateityp automatisch anhand der Dateiendung.
String detectFileType(String extension) {
  if (extension == 'pdf') return 'pdf';
  if (photoExtensions.contains(extension)) return 'photo';
  if (videoExtensions.contains(extension)) return 'video';
  return 'document';
}

IconData fileTypeIcon(String fileType) {
  switch (fileType) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'photo':
      return Icons.image;
    case 'video':
      return Icons.videocam;
    default:
      return Icons.insert_drive_file;
  }
}

String fileTypeLabel(String fileType) {
  switch (fileType) {
    case 'pdf':
      return 'PDF';
    case 'photo':
      return 'Foto';
    case 'video':
      return 'Video';
    default:
      return 'Dokument';
  }
}
