import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/folder.dart';
import 'cards_screen.dart';

class FoldersScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const FoldersScreen({super.key, required this.helper});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFolderForm([Folder? folder]) async {
    if (_busy) return;

    final controller = TextEditingController(text: folder?.name ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(folder == null ? 'Add Folder' : 'Edit Folder'),
                content: Form(
                  key: formKey,
                  child: TextFormField(
                    controller: controller,
                    autofocus: true,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Folder name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a folder name.';
                      }
                      return null;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() => saving = true);

                            try {
                              final name = controller.text.trim();

                              if (folder == null) {
                                await widget.helper.insertFolder(
                                  Folder(
                                    name: name,
                                    createdAt: DateTime.now().toIso8601String(),
                                  ),
                                );
                              } else {
                                final changed = await widget.helper
                                    .updateFolder(
                                      Folder(
                                        id: folder.id,
                                        name: name,
                                        createdAt: folder.createdAt,
                                      ),
                                    );
                                if (changed == 0) {
                                  throw StateError('Folder was not found.');
                                }
                              }

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              await _loadFolders();
                              _message('Folder saved.');
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not save folder: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy || folder.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}" and all its cards?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final deleted = await widget.helper.deleteFolder(folder.id!);
      if (deleted == 0) {
        _message('Folder was not found.');
      } else {
        _message('Folder deleted.');
      }
      await _loadFolders();
    } catch (error) {
      _message('Could not delete folder: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(Folder folder) async {
    if (folder.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardsScreen(helper: widget.helper, folder: folder),
      ),
    );

    if (mounted) await _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Folders'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _loadFolders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _showFolderForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Folder'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(
                onPressed: _loadFolders,
                child: Text('$_error\nTap to retry'),
              ),
            )
          : _folders.isEmpty
          ? const Center(child: Text('No folders yet. Add a folder.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];

                return Card(
                  child: ListTile(
                    title: Text(folder.name),
                    subtitle: Text(
                      'ID: ${folder.id} | Cards: ${folder.cardCount}',
                    ),
                    onTap: () => _openFolder(folder),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Folder',
                          onPressed: _busy
                              ? null
                              : () => _showFolderForm(folder),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Folder',
                          onPressed: _busy ? null : () => _deleteFolder(folder),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
