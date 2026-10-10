import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/card_item.dart';
import '../models/folder.dart';

class CardFormScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;
  final CardItem? card;

  const CardFormScreen({
    super.key,
    required this.helper,
    required this.folder,
    this.card,
  });

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;

  late String _selectedSuit;
  late int _selectedFolderId;

  List<Folder> _folders = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.card?.title ?? '');

    _notesController = TextEditingController(text: widget.card?.notes ?? '');

    _imageController = TextEditingController(text: widget.card?.imageRef ?? '');

    _selectedSuit = widget.card?.suit ?? 'Hearts';
    _selectedFolderId = widget.card?.folderId ?? widget.folder.id!;

    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await widget.helper.getFoldersWithCounts();

      if (!mounted) return;

      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load folders: $error';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final imageText = _imageController.text.trim();

    final card = CardItem(
      id: widget.card?.id,
      title: _titleController.text.trim(),
      suit: _selectedSuit,
      notes: _notesController.text.trim(),
      imageRef: imageText.isEmpty ? null : imageText,
      folderId: _selectedFolderId,
    );

    try {
      if (_isEditing) {
        final updated = await widget.helper.updateCard(card);

        if (updated == 0) {
          throw StateError('Card was not found.');
        }
      } else {
        await widget.helper.insertCard(card);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not save card: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Card' : 'Add Card')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
          ? const Center(child: Text('No folders available.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Card title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a card title.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedSuit,
                      decoration: const InputDecoration(
                        labelText: 'Suit',
                        border: OutlineInputBorder(),
                      ),
                      items: DatabaseHelper.supportedSuits
                          .map(
                            (suit) => DropdownMenuItem(
                              value: suit,
                              child: Text(suit),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSuit = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedFolderId,
                      decoration: const InputDecoration(
                        labelText: 'Folder',
                        border: OutlineInputBorder(),
                      ),
                      items: _folders
                          .where((folder) => folder.id != null)
                          .map(
                            (folder) => DropdownMenuItem<int>(
                              value: folder.id!,
                              child: Text(folder.name),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFolderId = value;
                                });
                              }
                            },
                      validator: (value) {
                        if (value == null ||
                            !_folders.any((folder) => folder.id == value)) {
                          return 'Select a valid folder.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _imageController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Image reference (optional)',
                        hintText: 'URL or asset path',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton(
                      onPressed: _saving ? null : _saveCard,
                      child: Text(_saving ? 'Saving...' : 'Save Card'),
                    ),

                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
