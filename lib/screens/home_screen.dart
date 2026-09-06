import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database_helper.dart';
import '../services/document_service.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _builtInCategories = [
    'Land Deeds',
    'Property Tax',
    'Identity',
    'Contracts',
  ];

  final DatabaseHelper _database = DatabaseHelper.instance;
  final DocumentService _documentService = DocumentService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _documents = [];
  List<String> _customCategories = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  bool _isScanning = false;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories => [
    'All',
    ..._builtInCategories,
    ..._customCategories,
  ];

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadDocuments();
  }

  Future<void> _loadCategories() async {
    final customCategories = await _database.getCustomCategories();
    if (!mounted) {
      return;
    }

    setState(() => _customCategories = customCategories);
  }

  Future<void> _loadDocuments() async {
    final requestId = ++_loadRequestId;
    final documents = await _database.getAllDocuments(
      query: _searchController.text.trim(),
      category: _selectedCategory == 'All' ? '' : _selectedCategory,
    );
    if (!mounted || requestId != _loadRequestId) {
      return;
    }

    setState(() {
      _documents = documents;
      _isLoading = false;
    });
  }

  Future<void> _scanDocument() async {
    if (_isScanning) {
      return;
    }

    setState(() => _isScanning = true);
    try {
      final imagePaths = await CunningDocumentScanner.getPictures();
      if (!mounted || imagePaths == null || imagePaths.isEmpty) {
        return;
      }

      final details = await _showDocumentDetails();
      if (!mounted || details == null) {
        return;
      }

      final pdfPath = await _documentService.compileImagesToPdf(
        imagePaths,
        fileName: details.title,
      );
      final fileSize = await File(pdfPath).length();
      await _database.insertDocument({
        'title': details.title,
        'category': details.category,
        'filePath': pdfPath,
        'pageCount': imagePaths.length,
        'fileSize': _formatFileSize(fileSize),
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _loadDocuments();
      _showMessage('Document saved to your vault.');
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Unable to save document: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<_DocumentDetails?> _showDocumentDetails() async {
    final titleController = TextEditingController();
    var category = _categories.firstWhere(
      (item) => item != 'All',
      orElse: () => _builtInCategories.first,
    );

    final details = await showModalBottomSheet<_DocumentDetails>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Save scanned document',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Document title',
                    hintText: 'e.g. 2026 Land Deed',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: _categories
                      .where((item) => item != 'All')
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a document title.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(
                      context,
                    ).pop(_DocumentDetails(title: title, category: category));
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save to Arkive'),
                ),
              ],
            ),
          );
        },
      ),
    );
    titleController.dispose();
    return details;
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final categoryName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Insurance',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    final normalizedName = categoryName?.trim() ?? '';
    if (!mounted || normalizedName.isEmpty) {
      return;
    }

    final alreadyExists = _categories.any(
      (category) => category.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (alreadyExists) {
      _showMessage(
        'That category already exists or matches a built-in category.',
        isError: true,
      );
      return;
    }

    try {
      final added = await _database.addCustomCategory(normalizedName);
      if (!mounted) {
        return;
      }
      if (!added) {
        _showMessage(
          'That category already exists or matches a built-in category.',
          isError: true,
        );
        return;
      }

      await _loadCategories();
      setState(() => _selectedCategory = normalizedName);
      await _loadDocuments();
    } on Object catch (error) {
      _showMessage('Unable to add category: $error', isError: true);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final title = document['title'] as String? ?? 'this document';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('“$title” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _database.deleteDocument(
        document['id'] as int,
        document['filePath'] as String,
      );
      await _loadDocuments();
      _showMessage('Document deleted.');
    } on Object catch (error) {
      _showMessage('Unable to delete document: $error', isError: true);
    }
  }

  void _openDocument(Map<String, dynamic> document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen(
          title: document['title'] as String? ?? 'Document',
          filePath: document['filePath'] as String,
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    return date == null
        ? 'Unknown date'
        : DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARKIVE'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle theme',
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _loadDocuments(),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search document titles',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: Icon(Icons.tune_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _categories.length) {
                    return ActionChip(
                      avatar: const Icon(Icons.add, size: 17),
                      label: const Text('Add category'),
                      onPressed: _addCategory,
                    );
                  }
                  final category = _categories[index];
                  final selected = category == _selectedCategory;
                  return FilterChip(
                    selected: selected,
                    label: Text(category),
                    labelStyle: TextStyle(
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                      _loadDocuments();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildDocumentList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _scanDocument,
        icon: _isScanning
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: Text(_isScanning ? 'Scanning...' : 'Scan Document'),
      ),
    );
  }

  Widget _buildDocumentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_documents.isEmpty) {
      return _EmptyState(onScan: _scanDocument);
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _documents.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _DocumentCard(
          document: _documents[index],
          formattedDate: _formatDate(_documents[index]['createdAt'] as String?),
          onTap: () => _openDocument(_documents[index]),
          onDelete: () => _deleteDocument(_documents[index]),
        ),
      ),
    );
  }
}

class _DocumentDetails {
  const _DocumentDetails({required this.title, required this.category});

  final String title;
  final String category;
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.formattedDate,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> document;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = document['category'] as String? ?? 'Uncategorized';
    final title = document['title'] as String? ?? 'Untitled document';
    final pageCount = document['pageCount'] as int? ?? 0;
    final fileSize = document['fileSize'] as String? ?? 'Unknown size';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Tag(label: category),
                        Text(
                          '$pageCount ${pageCount == 1 ? 'page' : 'pages'}  •  $fileSize',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Delete document',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 54,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your vault is empty',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your first land document to keep it private and close at hand.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan Document'),
            ),
          ],
        ),
      ),
    );
  }
}
