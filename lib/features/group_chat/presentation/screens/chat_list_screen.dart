import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/group_chat_model.dart';
import '../providers/chat_provider.dart';
import 'create_group_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final groups = chatState.groups;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Chats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () => _showNewGroupDialog(context, ref),
            tooltip: 'New Group',
          ),
        ],
      ),
      body: groups.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final messages = chatState.messagesByGroup[group.id] ?? [];
                final lastMessage = messages.isNotEmpty ? messages.last : null;
                final unreadCount = chatState.getUnreadCount(group.id);

                return _buildGroupTile(
                  context,
                  ref,
                  group,
                  lastMessage,
                  unreadCount,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppTheme.textLight,
          ),
          const SizedBox(height: 16),
          const Text(
            'No groups yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a group to start chatting',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showNewGroupDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
    WidgetRef ref,
    dynamic group,
    dynamic lastMessage,
    int unreadCount,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          ref.read(chatProvider.notifier).selectGroup(group.id);
          context.push('/group-chat/${group.id}');
        },
        leading: Stack(
          children: [
            _buildGroupAvatar(group),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surfaceColor, width: 1.5),
                ),
                child: Text(
                  '${group.onlineMemberCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          group.name,
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: lastMessage != null
            ? Text(
                '${lastMessage.senderName}: ${lastMessage.messageText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              )
            : Text(
                '${group.memberCount} members',
                style: const TextStyle(color: AppTheme.textLight),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              lastMessage?.formattedTime ?? '',
              style: TextStyle(
                fontSize: 11,
                color: unreadCount > 0 ? AppTheme.primaryColor : AppTheme.textLight,
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (unreadCount > 0)
              const SizedBox(height: 4),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(dynamic group) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: group.iconType == GroupIconType.color
            ? Color(int.parse(group.iconColor!.replaceAll('#', '0xFF')))
            : AppTheme.primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: group.iconType == GroupIconType.emoji && group.iconEmoji != null
            ? Text(
                group.iconEmoji!,
                style: const TextStyle(fontSize: 24),
              )
            : const Icon(
                Icons.chat_bubble,
                color: AppTheme.primaryColor,
                size: 24,
              ),
      ),
    );
  }

  void _showNewGroupDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const CreateGroupScreen(),
      ),
    );
  }
}
