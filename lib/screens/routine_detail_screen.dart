import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/routine_dialog.dart';
import 'routine_item_screen.dart';

class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text(
          'My Routine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => RoutineDialog(appState: Provider.of<AppState>(context, listen: false)),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final items = state.morningRoutine;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No routine items yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items from scan results or manually',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey('${item.label}_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Delete Routine?"),
                        content: const Text("Are you sure you want to delete this item?"),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel", style: TextStyle(color: Color(0xFF45A17E))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  state.removeRoutineItem(index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.label} deleted')),
                  );
                },
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide.none,
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => state.toggleRoutine(index),
                      child: Icon(
                        item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: item.done ? green : Theme.of(context).colorScheme.outline,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        // No strikethrough
                        // color: item.done ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    subtitle: item.time.isNotEmpty ? Text(item.time) : null,
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RoutineItemScreen(index: index),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
