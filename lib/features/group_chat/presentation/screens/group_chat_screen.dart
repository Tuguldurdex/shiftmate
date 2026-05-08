import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers.dart';
import '../../domain/chat_message.dart';
import '../../domain/group_chat_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/group_info_panel.dart';
import '../widgets/slash_command_menu.dart';
import '../widgets/typing_indicator.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSlashMenu = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).selectGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();
    final showSlash = text.startsWith('/ai');
    if (showSlash != _showSlashMenu) {
      setState(() => _showSlashMenu = showSlash);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openGroupInfo(GroupChat group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => GroupInfoPanel(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final group = chatState.groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => chatState.groups.first,
    );
    final messages = chatState.messagesByGroup[widget.groupId] ?? [];
    final typingUsers = chatState.typingUsersByGroup[widget.groupId] ?? [];
    final aiIsThinking = chatState.aiIsThinking && chatState.aiThinkingGroupId == widget.groupId;
    final currentUserId = ref.read(authProvider).user?.id ?? 'emp1';
    final groqConnected = ref.watch(groqConnectionProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(group, groqConnected),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser = message.senderId == currentUserId;
                      final isAi = message.senderId == 'ai_assistant';
                      final showSender = !isCurrentUser &&
                          (index == 0 || messages[index - 1].senderId != message.senderId);
                      final previousMessage = index > 0 ? messages[index - 1] : null;
                      final isConsecutive = previousMessage != null && previousMessage.senderId == message.senderId;

                      return _buildMessageBubble(
                        message,
                        isCurrentUser,
                        isAi,
                        showSender,
                        isConsecutive,
                        currentUserId,
                      );
                    },
                  ),
          ),
          if (aiIsThinking) const TypingIndicator(userName: 'ShiftMate AI', isAi: true),
          if (typingUsers.isNotEmpty && !aiIsThinking) _buildTypingIndicator(typingUsers),
          if (_showSlashMenu)
            SlashCommandMenu(
              onSelect: (command) {
                _messageController.text = '$command ';
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _messageController.text.length),
                );
                setState(() => _showSlashMenu = false);
              },
            ),
          _buildMessageInput(group),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(GroupChat group, bool groqConnected) {
    return AppBar(
      title: GestureDetector(
        onTap: () => _openGroupInfo(group),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallAvatar(group),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      '${group.memberCount} members • ${group.onlineMemberCount} online',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: groqConnected ? AppTheme.accentColor : AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            context.go('/group-chat');
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _openGroupInfo(group),
        ),
      ],
    );
  }

  Widget _buildSmallAvatar(GroupChat group) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: group.iconType == GroupIconType.color
            ? Color(int.parse(group.iconColor!.replaceAll('#', '0xFF')))
            : AppTheme.primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: group.iconType == GroupIconType.emoji && group.iconEmoji != null
            ? Text(group.iconEmoji!, style: const TextStyle(fontSize: 18))
            : const Icon(Icons.chat_bubble, color: AppTheme.primaryColor, size: 18),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textLight),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Say hello! \u{1F44B}', style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isCurrentUser,
    bool isAi,
    bool showSender,
    bool isConsecutive,
    String currentUserId,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: isConsecutive ? 2 : 8, bottom: isConsecutive ? 2 : 8),
      child: Row(
        mainAxisAlignment: isAi
            ? MainAxisAlignment.start
            : (isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            showSender ? _buildAvatar(message.senderInitials, message.senderName, isAi: isAi) : const SizedBox(width: 36),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAi ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                        ),
                        if (isAi) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('AI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          ),
                        ],
                      ],
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAi
                        ? const Color(0xFFEEEDFE)
                        : (isCurrentUser
                            ? (message.type == MessageType.mention ? AppTheme.primaryColor.withValues(alpha: 0.85) : AppTheme.primaryColor)
                            : AppTheme.surfaceColor),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : (isConsecutive ? 16 : 4)),
                      bottomRight: Radius.circular(isCurrentUser ? (isConsecutive ? 16 : 4) : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isAi ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageText(message, isCurrentUser, isAi),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.formattedTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: isAi ? AppTheme.textSecondary : (isCurrentUser ? Colors.white.withValues(alpha: 0.7) : AppTheme.textLight),
                            ),
                          ),
                          if (isAi && message.aiModel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(message.aiModel!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                            ),
                          ],
                          if (isCurrentUser && message.readCount > 0) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.done_all, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 2),
                            Text('${message.readCount}', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7))),
                          ],
                        ],
                      ),
                      if (isAi) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: AppTheme.textSecondary,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: message.messageText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(message.feedbackPositive == true ? Icons.thumb_up : Icons.thumb_up_outlined, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: message.feedbackPositive == true ? AppTheme.accentColor : AppTheme.textSecondary,
                              onPressed: () {
                                ref.read(chatProvider.notifier).updateAiFeedback(widget.groupId, message.id, true);
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(message.feedbackPositive == false ? Icons.thumb_down : Icons.thumb_down_outlined, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: message.feedbackPositive == false ? AppTheme.errorColor : AppTheme.textSecondary,
                              onPressed: () {
                                ref.read(chatProvider.notifier).updateAiFeedback(widget.groupId, message.id, false);
                              },
                            ),
                            if (message.responseTimeMs != null) ...[
                              const Spacer(),
                              Text('${message.responseTimeMs}ms', style: const TextStyle(fontSize: 9, color: AppTheme.textLight)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageText(ChatMessage message, bool isCurrentUser, bool isAi) {
    final textColor = isAi ? AppTheme.textPrimary : (isCurrentUser ? Colors.white : AppTheme.textPrimary);
    if (message.mentionedUserIds.isEmpty && !isAi) {
      return Text(message.messageText, style: TextStyle(color: textColor, fontSize: 14));
    }

    final textParts = message.messageText.split(' ');
    return RichText(
      text: TextSpan(
        children: textParts.map((part) {
          if (part.startsWith('@')) {
            return TextSpan(
              text: '$part ',
              style: TextStyle(color: isCurrentUser ? Colors.yellow : AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 14),
            );
          }
          return TextSpan(text: '$part ', style: TextStyle(color: textColor, fontSize: 14));
        }).toList(),
      ),
    );
  }

  Widget _buildAvatar(String initials, String name, {bool isAi = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAi ? AppTheme.primaryColor : _getColorForName(name),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isAi
            ? const Text('\u{1F916}', style: TextStyle(fontSize: 16))
            : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
      ),
    );
  }

  Color _getColorForName(String name) {
    final colors = [AppTheme.primaryColor, AppTheme.accentColor, AppTheme.warningColor, AppTheme.errorColor];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildTypingIndicator(List<String> typingUsers) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();
    final name = typingUsers.first;
    return TypingIndicator(userName: name);
  }

  Widget _buildMessageInput(GroupChat group) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message... (use @ai for AI)',
                hintStyle: const TextStyle(color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  ref.read(chatProvider.notifier).sendMessage(text);
                  _messageController.clear();
                  _scrollToBottom();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: AppTheme.primaryColor,
            onPressed: () {
              final text = _messageController.text.trim();
              if (text.isNotEmpty) {
                ref.read(chatProvider.notifier).sendMessage(text);
                _messageController.clear();
                _scrollToBottom();
              }
            },
          ),
        ],
      ),
    );
  }
}
