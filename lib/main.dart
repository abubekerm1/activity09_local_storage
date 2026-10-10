import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'screens/folders_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );

    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fall Festival Roster',
      home: DirectoryScreen(helper: helper),
    );
  }
}

class DirectoryScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const DirectoryScreen({super.key, required this.helper});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];

  bool _busy = false;
  bool _loading = true;

  String? _errorMessage;
  String? _feedbackMessage;

  int _recordCount = 0;
  int? _selectedId;

  bool get _isEditing => _selectedId != null;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _rows = rows;
        _recordCount = count;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Database read failed: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            'Could not load the festival roster. Press Refresh to try again.';
      });
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a name.';
    }

    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an age.';
    }

    final age = int.tryParse(value.trim());

    if (age == null) {
      return 'Age must be a whole number.';
    }

    if (age < 0 || age > 130) {
      return 'Age must be from 0 through 130.';
    }

    return null;
  }

  Future<void> _saveGuest() async {
    if (_busy) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (age == null) {
      return;
    }

    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });

    bool writeSucceeded = false;
    String successMessage = '';

    try {
      if (_isEditing) {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: _selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (updated == 0) {
          if (mounted) {
            setState(() {
              _feedbackMessage =
                  'Guest was not found. The roster will be refreshed.';
            });
          }

          await _refreshAfterWrite();
          return;
        }

        writeSucceeded = true;
        successMessage = 'Updated $updated row.';
      } else {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        writeSucceeded = true;
        successMessage = 'Saved guest with ID $id.';
      }

      if (writeSucceeded) {
        _clearForm();

        try {
          final rows = await widget.helper.queryAllRows();
          final count = await widget.helper.queryRowCount();

          if (!mounted) {
            return;
          }

          setState(() {
            _rows = rows;
            _recordCount = count;
            _errorMessage = null;
            _feedbackMessage = successMessage;
          });
        } catch (error, stackTrace) {
          debugPrint('Refresh after save failed: $error\n$stackTrace');

          if (!mounted) {
            return;
          }

          setState(() {
            _feedbackMessage = 'Saved, but refresh failed. Press Refresh.';
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Database write failed: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage =
            'Could not save this guest. Check the information and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshAfterWrite() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _rows = rows;
        _recordCount = count;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Refresh failed: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not refresh the festival roster. Press Refresh to try again.';
      });
    }
  }

  void _editGuest(Map<String, dynamic> row) {
    if (_busy) {
      return;
    }

    setState(() {
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName].toString();
      _ageController.text = row[DatabaseHelper.columnAge].toString();
      _feedbackMessage = null;
    });
  }

  void _cancelEdit() {
    if (_busy) {
      return;
    }

    _clearForm();

    setState(() {
      _feedbackMessage = 'Edit canceled.';
    });
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();

    if (mounted) {
      setState(() {
        _selectedId = null;
      });
    }
  }

  Future<void> _deleteGuest(Map<String, dynamic> row) async {
    if (_busy) {
      return;
    }

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id, $name from the festival roster?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });

    try {
      final deleted = await widget.helper.delete(id);

      if (deleted == 0) {
        if (mounted) {
          setState(() {
            _feedbackMessage =
                'Guest ID $id was not found. The roster will be refreshed.';
          });
        }

        await _refreshAfterWrite();
        return;
      }

      if (_selectedId == id) {
        _nameController.clear();
        _ageController.clear();
        _selectedId = null;
      }

      try {
        final rows = await widget.helper.queryAllRows();
        final count = await widget.helper.queryRowCount();

        if (!mounted) {
          return;
        }

        setState(() {
          _rows = rows;
          _recordCount = count;
          _errorMessage = null;
          _feedbackMessage = 'Deleted $deleted row.';
        });
      } catch (error, stackTrace) {
        debugPrint('Refresh after delete failed: $error\n$stackTrace');

        if (!mounted) {
          return;
        }

        setState(() {
          _feedbackMessage = 'Deleted, but refresh failed. Press Refresh.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage =
            'Could not delete this guest. Press Refresh and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshButtonPressed() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });

    try {
      await _loadRows();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Card Folders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoldersScreen(helper: widget.helper),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateAge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _saveGuest,
                          child: Text(_isEditing ? 'Save' : 'Add'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy || !_isEditing ? null : _cancelEdit,
                          child: const Text('Cancel Edit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Record count: $_recordCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _busy ? null : _refreshButtonPressed,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 8),
              Text(_feedbackMessage!),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _busy ? null : _refreshButtonPressed,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _rows.isEmpty
                  ? const Center(child: Text('No festival guests yet'))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];

                        final id = row[DatabaseHelper.columnId];
                        final name = row[DatabaseHelper.columnName];
                        final age = row[DatabaseHelper.columnAge];

                        return Card(
                          child: ListTile(
                            title: Text('$name'),
                            subtitle: Text('ID: $id   Age: $age'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _editGuest(row),
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteGuest(row),
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
