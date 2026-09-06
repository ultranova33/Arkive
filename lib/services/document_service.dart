import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DocumentService {
  static const MethodChannel _storageChannel = MethodChannel(
    'com.arkive/storage',
  );

  Future<String> compileImagesToPdf(
    List<String> imagePaths, {
    String? fileName,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError.value(
        imagePaths,
        'imagePaths',
        'At least one scanned image is required.',
      );
    }

    final document = pw.Document();

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw FileSystemException('Scanned image does not exist.', imagePath);
      }

      final image = pw.MemoryImage(await imageFile.readAsBytes());
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final outputName = _normalisePdfName(fileName);
    final outputPath = path.join(directory.path, outputName);
    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(await document.save(), flush: true);
    await _excludeFromBackup(outputPath);
    return outputPath;
  }

  Future<void> _excludeFromBackup(String filePath) async {
    if (!Platform.isIOS) {
      return;
    }

    try {
      await _storageChannel.invokeMethod<void>(
        'excludeFromBackup',
        <String, String>{'filePath': filePath},
      );
    } on PlatformException catch (error) {
      throw FileSystemException(
        'Unable to exclude the PDF from iCloud backup: ${error.message}',
        filePath,
      );
    }
  }

  String _normalisePdfName(String? requestedName) {
    final baseName = requestedName?.trim().isNotEmpty == true
        ? requestedName!.trim()
        : 'arkive_document_${DateTime.now().millisecondsSinceEpoch}';
    final safeName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';
  }
}
