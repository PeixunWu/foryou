import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/coach_message.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF45A17E);
    final DateFormat dayFormatter = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F7),
        body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Skin Health Progress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).pushNamed('/settings'),
                  ),
                ],
              ),
            ),
            
            // Skin Photo History Section
            Consumer<AppState>(
              builder: (context, state, _) {
                final skinHistory = state.skinHistory;
                
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: skinHistory.isEmpty
                                ? InkWell(
                                    onTap: () {
                                      state.preferredScannerMode = ScanMode.skin;
                                      state.setTabIndex(1);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400, size: 32),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'No skin scans yet. Take a scan to see history.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 110,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      itemCount: skinHistory.length,
                                      itemBuilder: (context, index) {
                                        final record = skinHistory[index];
                                        final date = _formatShortDate(record.createdAt);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 70,
                                                height: 70,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.memory(record.imageBytes, fit: BoxFit.cover),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                date,
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (skinHistory.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/compare_skin'),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF99FFD8),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Compare',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'AI Assistant',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Consumer<AppState>(
                    builder: (_, state, __) {
                      final history = state.coachHistory;
                      String? lastDay;

                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          const SizedBox(height: 16),
                          _AgentBubble(
                            message: 'Ask me anything about your skin health or routine!',
                            accentColor: green,
                          ),
                          const SizedBox(height: 16),
                          
                          for (int i = 0; i < history.length; i++) ...[
                            if (dayFormatter.format(history[i].timestamp) != lastDay) ...[
                              _buildDateHeader(dayFormatter.format(history[i].timestamp)),
                              const SizedBox(height: 12),
                            ],
                            _buildMessageBubble(history[i], green),
                            const SizedBox(height: 8),
                            // Update lastDay
                            if (dayFormatter.format(history[i].timestamp) != lastDay) 
                               Builder(builder: (context) { 
                                 lastDay = dayFormatter.format(history[i].timestamp);
                                 return const SizedBox.shrink();
                               }),
                          ],
                          
                          if (state.coachLoading)
                            _AgentBubble(
                              message: 'Analyzing...',
                              isThinking: true,
                              accentColor: green,
                            ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            
            _ChatInput(
              controller: _controller,
              onSend: () {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                context.read<AppState>().sendCoachMessage(text);
                _controller.clear();
                FocusScope.of(context).unfocus();
                // Scroll to bottom
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              accentColor: green,
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Center(
      child: Text(
        date,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(CoachMessage msg, Color green) {
    if (msg.isUser) {
      return _UserBubble(message: msg.text, accentColor: green);
    } else {
      return _AgentBubble(message: msg.text, accentColor: green);
    }
  }

  String _formatShortDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}";
  }
}

class _AgentBubble extends StatelessWidget {
  const _AgentBubble({
    required this.message,
    this.isThinking = false,
    required this.accentColor,
  });

  final String message;
  final bool isThinking;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.only(
            topLeft: Radius.zero,
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.face_2, size: 20, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: isThinking
                  ? Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    )
                  : Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.accentColor});

  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: Radius.zero,
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}



class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.accentColor,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      color: const Color(0xFFF6F8F7),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ask Foru AI...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: 1,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send, color: Color(0xFF45A17E)),
              style: IconButton.styleFrom(backgroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
