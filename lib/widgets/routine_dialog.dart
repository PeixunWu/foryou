import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/gemini_service.dart' show ScanAnalysis;

class RoutineDialog extends StatefulWidget {
  const RoutineDialog({super.key, this.analysis, required this.appState});

  final ScanAnalysis? analysis;
  final AppState appState;

  @override
  State<RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<RoutineDialog> {
  late TextEditingController _titleController;
  TimeOfDay? _selectedTime;
  final Set<String> _selectedItems = {};
  List<String> _availableItems = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.analysis?.name ?? '');
    _parseAvailableItems();
  }

  void _parseAvailableItems() {
    if (widget.analysis == null) return;
    final a = widget.analysis!;
    final items = <String>{};

    for (final rec in a.recommendations) {
      if (rec.productName.isNotEmpty && rec.productName.toLowerCase() != 'n/a') {
        items.add(rec.productName);
      }
    }
    _availableItems = items.toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                'Create Routine',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          // Title Input
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Routine Title',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF45A17E))),
            ),
          ),
          const SizedBox(height: 16),
          // Time Picker
          InkWell(
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF45A17E),
                          ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF45A17E),
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (t != null) {
                setState(() => _selectedTime = t);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: _selectedTime != null ? const Color(0xFF45A17E) : Colors.grey, width: _selectedTime != null ? 2 : 1),
                borderRadius: BorderRadius.circular(4),
                color: _selectedTime != null ? const Color(0xFFF0FDF4) : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: _selectedTime != null ? const Color(0xFF45A17E) : Colors.grey),
                  const SizedBox(width: 12),
                   Expanded(
                    child: Text(
                      _selectedTime == null ? 'Select Time (Required)' : _selectedTime!.format(context),
                      style: TextStyle(
                        color: _selectedTime == null ? Colors.grey : Colors.black,
                        fontSize: 16,
                        fontWeight: _selectedTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Recommended Items List
          if (_availableItems.isNotEmpty) ...[
             Text(
              'Select items to include:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableItems.length,
                itemBuilder: (context, index) {
                  final item = _availableItems[index];
                  final isSelected = _selectedItems.contains(item);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedItems.add(item);
                        } else {
                          _selectedItems.remove(item);
                        }
                      });
                    },
                    title: Text(item, style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF45A17E),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _selectedTime == null
                ? () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Time Required'),
                        content: const Text('Please select a time for this routine item.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF45A17E)),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                : null,
            child: FilledButton(
              onPressed: _selectedTime == null
                  ? null
                  : () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) return;
                      
                      final timeStr = _selectedTime!.format(context);
                      final detailsBuilder = StringBuffer();
                      if (_selectedItems.isNotEmpty) {
                        for (final item in _selectedItems) {
                          detailsBuilder.writeln('• $item');
                        }
                      }
                      
                      widget.appState.addRoutineItem(title, timeStr, detailsBuilder.toString().trim());
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine created')));
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF99FFD8),
                disabledBackgroundColor: Colors.grey[300], // Greyed out
                foregroundColor: Colors.black,
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    );
  }
}
