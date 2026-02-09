import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models/analysis_record.dart';

class CompareSkinScreen extends StatefulWidget {
  const CompareSkinScreen({super.key});

  @override
  State<CompareSkinScreen> createState() => _CompareSkinScreenState();
}

class _CompareSkinScreenState extends State<CompareSkinScreen> {
  AnalysisRecord? leftRecord;
  AnalysisRecord? rightRecord;
  String? aiAnalysis;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to newest two if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = context.read<AppState>().skinHistory;
      if (history.length >= 2) {
        setState(() {
          leftRecord = history[1]; // Older
          rightRecord = history[0]; // Newer
        });
        _runAnalysis();
      } else if (history.isNotEmpty) {
        setState(() {
          rightRecord = history[0];
        });
      }
    });
  }

  Future<void> _runAnalysis() async {
    if (leftRecord == null || rightRecord == null) return;
    setState(() {
      isLoading = true;
      aiAnalysis = null;
    });
    
    final result = await context.read<AppState>().compareTwoRecords(leftRecord!, rightRecord!);
    
    if (mounted) {
      setState(() {
        aiAnalysis = result;
        isLoading = false;
      });
    }
  }

  void _showSelector(bool forLeft) {
    final history = context.read<AppState>().skinHistory;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
      ),
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Choose From Past Analysis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (ctx, i) {
                final r = history[i];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(r.imageBytes, width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  title: Text(DateFormat('MMM dd, yyyy').format(r.createdAt)),
                  onTap: () {
                    setState(() {
                      if (forLeft) {
                        leftRecord = r;
                      } else {
                        rightRecord = r;
                      }
                    });
                    Navigator.pop(ctx);
                    _runAnalysis();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF45A17E);
    final lightGreen = const Color(0xFF99FFD8);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Compare Skin Health', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Comparison Images Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  // Left Image
                  Expanded(
                    child: GestureDetector(
                      onTap: () => leftRecord != null ? _showEnlarged(leftRecord!) : _showSelector(true),
                      child: _ComparisonImageFrame(
                        record: leftRecord,
                        labelColor: Colors.black.withOpacity(0.6),
                        labelTextColor: Colors.white,
                        placeholderIcon: Icons.add_photo_alternate_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Right Image
                  Expanded(
                    child: GestureDetector(
                      onTap: () => rightRecord != null ? _showEnlarged(rightRecord!) : _showSelector(false),
                      child: _ComparisonImageFrame(
                        record: rightRecord,
                        labelColor: lightGreen,
                        labelTextColor: Colors.black,
                        placeholderIcon: Icons.add_photo_alternate_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Selector Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showSelector(true),
                    child: const Text('Change Image 1'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showSelector(false),
                    child: const Text('Change Image 2'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // AI Analysis Box
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Progress Summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ))
                  else if (aiAnalysis != null)
                    Text(
                      aiAnalysis!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    )
                  else
                    const Text(
                      'Select two photos to see an AI analysis of your progress.',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnlarged(AnalysisRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(record.imageBytes, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                DateFormat('MMMM dd, yyyy').format(record.createdAt),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonImageFrame extends StatelessWidget {
  final AnalysisRecord? record;
  final Color labelColor;
  final Color labelTextColor;
  final IconData placeholderIcon;

  const _ComparisonImageFrame({
    required this.record,
    required this.labelColor,
    required this.labelTextColor,
    required this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: record != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(record!.imageBytes, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: labelColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat('MMM dd').format(record!.createdAt),
                        style: TextStyle(
                          color: labelTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Icon(placeholderIcon, size: 40, color: Colors.grey[400]),
            ),
    );
  }
}
