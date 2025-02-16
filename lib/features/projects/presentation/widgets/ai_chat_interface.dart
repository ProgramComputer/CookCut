import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/recipe_assistant_service.dart';
import '../../domain/models/recipe_suggestion.dart';
import 'video_command_confirmation_bubble.dart';
import '../../data/services/ffmpeg_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AIChatInterface extends StatefulWidget {
  final String projectId;
  final VoidCallback onClose;
  final Function(String) onTimestampTap;

  const AIChatInterface({
    super.key,
    required this.projectId,
    required this.onClose,
    required this.onTimestampTap,
  });

  @override
  State<AIChatInterface> createState() => _AIChatInterfaceState();
}

class _AIChatInterfaceState extends State<AIChatInterface>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late final AnimationController _keyboardAnimationController;
  late final Animation<double> _keyboardAnimation;
  late final RecipeAssistantService _recipeAssistant;

  @override
  void initState() {
    super.initState();
    _keyboardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _keyboardAnimation = CurvedAnimation(
      parent: _keyboardAnimationController,
      curve: Curves.easeOutCubic,
    );

    _recipeAssistant = RecipeAssistantService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
      if (keyboardVisible) {
        _keyboardAnimationController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _keyboardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        projectId: widget.projectId,
      ));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _recipeAssistant.getRecipeSuggestions(
        query: text,
        projectId: widget.projectId,
        recipeData: {}, // Project-wide analysis doesn't need specific recipe data
      );

      if (mounted) {
        final suggestion = RecipeSuggestion.fromJson(response);
        print('\n=== Video Commands Debug ===');
        print('Has videoCommands: ${suggestion.videoCommands != null}');
        print('VideoCommands length: ${suggestion.videoCommands?.length ?? 0}');
        if (suggestion.videoCommands?.isNotEmpty ?? false) {
          suggestion.videoCommands!.forEach((command) {
            print('\nCommand Details:');
            print('- Operation: ${command.operation}');
            print('- Description: ${command.description}');
            print('- FFmpeg Command: ${command.ffmpegCommand}');
            print('- Input Files: ${command.inputFiles}');
            print('- Output File: ${command.outputFile}');
            print('- Expected Duration: ${command.expectedDuration}');
            print('- Start Time: ${command.startTime}');
            print('- End Time: ${command.endTime}');
            print('- Metadata: ${command.metadata}');
          });
        } else {
          print('No video commands in response');
        }
        print('=== End Video Commands Debug ===\n');
        setState(() {
          _messages.add(ChatMessage(
            text: suggestion.response,
            isUser: false,
            suggestion: suggestion,
            onTimestampTap: widget.onTimestampTap,
            onCommandTap: _handleVideoCommand,
            projectId: widget.projectId,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Sorry, I encountered an error: ${e.toString()}",
            isUser: false,
            projectId: widget.projectId,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleVideoCommand(VideoCommand command) {
    setState(() {
      _messages.add(ChatMessage(
        text:
            'Video processing completed successfully! You can find the processed video in your media library.',
        isUser: false,
        suggestion: null,
        projectId: widget.projectId,
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RepaintBoundary(
                    child: _buildMessageList(),
                  ),
                ),
                if (_isTyping) _buildTypingIndicator(),
                RepaintBoundary(
                  child: _buildInputArea(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            const Text(
              '🧑‍🍳Cook Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return ChatMessage(
          text: message.text,
          isUser: message.isUser,
          suggestion: message.suggestion,
          onTimestampTap: message.onTimestampTap,
          onCommandTap: message.onCommandTap,
          projectId: message.projectId,
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: const Text(
          'AI is typing...',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return AnimatedBuilder(
      animation: _keyboardAnimation,
      builder: (context, child) => Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom *
                  _keyboardAnimation.value +
              8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: child,
      ),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _keyboardAnimationController.forward();
          } else {
            _keyboardAnimationController.reverse();
          }
        },
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSubmit,
                keyboardType: TextInputType.multiline,
                onEditingComplete: () {
                  // Prevent default enter behavior
                },
                onChanged: (value) {
                  // Trigger setState to rebuild with current input value
                  setState(() {});
                },
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    // Remove single newline characters (from regular Enter)
                    if (newValue.text.endsWith('\n') &&
                        !newValue.text.endsWith('\n\n')) {
                      _handleSubmit(_messageController.text.trim());
                      return TextEditingValue.empty;
                    }
                    // Keep shift+enter newlines (they come as double newlines)
                    if (newValue.text.endsWith('\n\n')) {
                      return TextEditingValue(
                        text: newValue.text
                            .substring(0, newValue.text.length - 1),
                        selection: TextSelection.collapsed(
                          offset: newValue.text.length - 1,
                        ),
                      );
                    }
                    return newValue;
                  }),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _handleSubmit(_messageController.text),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final RecipeSuggestion? suggestion;
  final Function(String)? onTimestampTap;
  final Function(VideoCommand)? onCommandTap;
  final String? projectId;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.suggestion,
    this.onTimestampTap,
    this.onCommandTap,
    this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: isUser ? Colors.blue : Colors.green,
              child: Icon(
                isUser ? Icons.person : Icons.assistant,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.blue.withOpacity(0.1)
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(text),
                      if (!isUser &&
                          suggestion?.mediaAnalyses?.isNotEmpty == true)
                        ..._buildFrameAnalysis(context),
                    ],
                  ),
                ),
                if (!isUser && suggestion?.videoCommands?.isNotEmpty == true)
                  ..._buildCommandButtons(context),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: isUser ? Colors.blue : Colors.green,
              child: Icon(
                isUser ? Icons.person : Icons.assistant,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFrameAnalysis(BuildContext context) {
    final analyses = suggestion!.mediaAnalyses!
        .where((media) => media.type == 'video')
        .map((media) => media.analysis)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (analyses.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 8),
      Text(
        'Frame Analysis',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 8),
      ...analyses.expand((analysis) {
        final frameAnalysis = analysis['frameAnalysis'] as List?;
        if (frameAnalysis == null) return <Widget>[];

        return frameAnalysis
            .where((frame) => frame['isSignificant'] == true)
            .map((frame) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => onTimestampTap?.call(frame['timestamp']),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Timestamp: ${frame['timestamp']}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            frame['analysis'] as String? ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList();
      }).toList(),
    ];
  }

  List<Widget> _buildCommandButtons(BuildContext context) {
    return suggestion!.videoCommands!.map((command) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: FilledButton.icon(
          onPressed: () async {
            try {
              if (projectId == null) {
                throw Exception('Project ID is required for video processing');
              }

              final ffmpegService = FFmpegService();
              await ffmpegService.exportVideoWithOverlays(
                videoUrl: command.inputFiles.first,
                textOverlays: [],
                timerOverlays: [],
                recipeOverlays: [],
                aspectRatio: 16 / 9,
                projectId: projectId!,
                backgroundMusic: null,
              );

              if (onCommandTap != null) {
                onCommandTap!(command);
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error processing video: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          icon: const Icon(Icons.movie_edit, size: 16),
          label: const Text('Confirm'),
        ),
      );
    }).toList();
  }
}
