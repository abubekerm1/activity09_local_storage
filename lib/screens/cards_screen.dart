import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/folder.dart';
import '../models/card_item.dart';
import 'card_form_screen.dart';

class CardsScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;

  const CardsScreen({super.key, required this.helper, required this.folder});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CardItem> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final cards = await widget.helper.getCards(widget.folder.id!);

      if (!mounted) return;

      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load cards: $error';
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCardForm([CardItem? card]) async {
    if (_busy) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardFormScreen(
          helper: widget.helper,
          folder: widget.folder,
          card: card,
        ),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      await _loadCards();
    }
  }

  Future<void> _deleteCard(CardItem card) async {
    if (_busy || card.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Card?'),
          content: Text('Delete "${card.title}" (ID: ${card.id})?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final deleted = await widget.helper.deleteCard(card.id!);

      if (deleted == 0) {
        _message('Card was not found.');
      } else {
        _message('Card deleted.');
      }

      await _loadCards();
    } catch (error) {
      _message('Could not delete card: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _cardImage(CardItem card) {
    final reference = card.imageRef?.trim();

    if (reference == null || reference.isEmpty) {
      return _suitPlaceholder(card.suit);
    }

    final uri = Uri.tryParse(reference);

    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return Image.network(
        reference,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _suitPlaceholder(card.suit);
        },
      );
    }

    if (reference.startsWith('assets/')) {
      return Image.asset(
        reference,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _suitPlaceholder(card.suit);
        },
      );
    }

    return _suitPlaceholder(card.suit);
  }

  Widget _suitPlaceholder(String suit) {
    const symbols = {
      'Hearts': '♥',
      'Diamonds': '♦',
      'Clubs': '♣',
      'Spades': '♠',
    };

    return SizedBox(
      width: 52,
      height: 52,
      child: Center(
        child: Text(symbols[suit] ?? '?', style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            onPressed: _busy ? null : _loadCards,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Cards',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openCardForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(
                onPressed: _loadCards,
                child: Text('$_error\nTap to retry'),
              ),
            )
          : _cards.isEmpty
          ? const Center(child: Text('No cards in this folder yet.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];

                return Card(
                  child: ListTile(
                    leading: _cardImage(card),
                    title: Text(card.title),
                    subtitle: Text(
                      'ID: ${card.id} | ${card.suit}\n'
                      '${card.notes}',
                    ),
                    isThreeLine: card.notes.isNotEmpty,
                    onTap: () => _openCardForm(card),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _busy ? null : () => _openCardForm(card),
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Card',
                        ),
                        IconButton(
                          onPressed: _busy ? null : () => _deleteCard(card),
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Card',
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
