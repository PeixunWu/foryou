import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class RoutineItemScreen extends StatelessWidget {
  const RoutineItemScreen({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Routine Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
               // Confirm delete
               showDialog(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text('Delete Item?'),
                   content: const Text('Are you sure you want to remove this from your routine?'),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                     TextButton(
                       onPressed: () {
                         Provider.of<AppState>(context, listen: false).removeRoutineItem(index);
                         Navigator.pop(ctx); // Close dialog
                         Navigator.pop(context); // Close screen
                       }, 
                       child: const Text('Delete', style: TextStyle(color: Colors.red)),
                     ),
                   ],
                 ),
               );
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          // Safety check
          if (index < 0 || index >= state.morningRoutine.length) {
             return const Center(child: Text('Item not found'));
          }
          final item = state.morningRoutine[index];
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: item.done ? const Color(0xFF99FFD8) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.done ? Icons.check_circle : Icons.circle_outlined,
                                  size: 16, 
                                  color: item.done ? Colors.black : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.done ? 'Done' : 'To Do',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (item.time.isNotEmpty) 
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              item.time,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Button
                 SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => state.toggleRoutine(index),
                    icon: Icon(item.done ? Icons.undo : Icons.check),
                    label: Text(item.done ? 'Mark as Not Done' : 'Mark as Done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: item.done ? Colors.grey[300] : const Color(0xFF99FFD8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Details Section
                if (item.details.isNotEmpty) ...[
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item.details,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
