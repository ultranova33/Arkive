import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../services/document_service.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.filePath,
  });

  final String title;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => _export(context),
            tooltip: 'Export document',
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        fitEachPage: true,
        onError: (error) => _showError(context, error.toString()),
        onPageError: (page, error) =>
            _showError(context, 'Unable to render page $page: $error'),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await DocumentService().exportDocument(filePath);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
