import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart' show AppState;
import '../services/gemini_service.dart' show ScanAnalysis, ScanMode;
import '../widgets/routine_dialog.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, this.recordId});

  final String? recordId;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final GlobalKey _globalKey = GlobalKey();

  Future<void> _shareScreenshot() async {
    try {
      // Add small delay to ensure rendering matches what we want to capture
      await Future.delayed(const Duration(milliseconds: 100));
      
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
          debugPrint('Boundary is null');
          return;
      }

      // Ensure high resolution
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/analysis_result.png');
        await file.writeAsBytes(pngBytes);
        
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out my analysis result from Foryou AI!',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      debugPrint('Error sharing screenshot: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share screenshot: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Analysis Results',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareScreenshot,
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          ScanAnalysis? analysis;
          Uint8List? imageBytes;
          if (widget.recordId != null) {
            final record = state.getRecordById(widget.recordId!);
            analysis = record?.analysis;
            imageBytes = record?.imageBytes;
          } else {
            analysis = state.lastAnalysis;
            imageBytes = state.lastScanImage;
          }
          if (analysis == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Scan to see results',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/scanner'),
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Open Scanner'),
                  ),
                ],
              ),
            );
          }

          // Use SingleChildScrollView + RepaintBoundary to capture full height
          return SingleChildScrollView(
            child: RepaintBoundary(
              key: _globalKey,
              child: Container(
                color: const Color(0xFFF6F8F7), // Capture background color too
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header: image with same radius as others
                    if (imageBytes != null && imageBytes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 240,
                          ),
                        ),
                      ),
              
                    // 1. Warning Container (Safety Red Flag)
                    if (_hasSafetyAlert(analysis))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SafetyRedFlagCard(analysis: analysis),
                      ),
              
                    // 2. Identification Container
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _IdentificationCard(analysis: analysis),
                    ),
                    
                    // Add To Routine Button ISOLATED
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _showEnhancedRoutineDialog(context, analysis!, state),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF99FFD8), // #99FFD8
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Add to my routine',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
              
                    // 3. AI Reasoning Container
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AIReasoningCard(analysis: analysis),
                    ),
              
                    // 4. Recommendation Container
                    // Show regardless of type if there are recommendations to parse
                    _RecommendationCard(analysis: analysis),
              
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _hasSafetyAlert(ScanAnalysis a) {
    if (a.safetyAlert.isEmpty || a.safetyAlert.toLowerCase() == 'none identified') return false;
    return true;
  }
  
  void _showEnhancedRoutineDialog(BuildContext context, ScanAnalysis analysis, AppState appState) {
    // Only show if there are recommendations? User said: 
    // "shouldnt show recommended care products listview as an option ... because there is none"
    // But the dialog itself is for creating a routine. Basic fields are Title and Time.
    // If no recommendations, we just don't show the list inside the dialog.
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineDialog(analysis: analysis, appState: appState),
    );
  }
}

class _SafetyRedFlagCard extends StatelessWidget {
  const _SafetyRedFlagCard({required this.analysis});

  final ScanAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7F51), // #FF7F51
        borderRadius: BorderRadius.circular(16),
        // No border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deep Analysis Result',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 3,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  analysis.safetyAlert,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({required this.analysis});

  final ScanAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF45A17E); // #45A17E
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Identification" label with checkbox
          Row(
            children: [
              // Circle Checkbox
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: greenColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Identification',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey, // Light grey
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Product Name / Identification Title
          Text(
            analysis.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) + 2,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          // "High confidence"
          Text(
            '${_capitalize(analysis.confidence)} confidence',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: greenColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';
}


class _AIReasoningCard extends StatelessWidget {
  const _AIReasoningCard({required this.analysis});

  final ScanAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    if (analysis.aiReasoning.isEmpty || analysis.aiReasoning == 'N/A') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Remove Icon as requested
          Text(
            'AI Reasoning & Logic',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: 12),
          // Reasoning Text (No dot points)
          Text(
            analysis.aiReasoning.replaceAll('•', '').replaceAll('-', ' ').trim(), // Simple cleanup
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.analysis});

  final ScanAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final recommendations = analysis.recommendations;
    if (recommendations.isEmpty) return const SizedBox.shrink();

    const titleColor = Color(0xFF45A17E);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: titleColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Recommendations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended for use with ${analysis.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendations.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(context, 'What it does', item.whatItDoes),
                  _buildDetailRow(context, 'Relevance with ${analysis.name}', item.whyItsGood),
                  _buildDetailRow(context, 'How to use', item.howToUse),
                  _buildDetailRow(context, 'Ingredients', item.ingredients),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchSearch(item.productName),
                      icon: const Icon(Icons.search, size: 16, color: Colors.white),
                      label: const Text('Search for Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF45A17E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    if (value.isEmpty || value.toLowerCase() == 'n/a') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _launchSearch(String query) async {
    final uri = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch search: $e');
    }
  }
}
