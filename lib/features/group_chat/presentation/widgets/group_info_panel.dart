import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers.dart';
import '../../domain/group_chat_model.dart';
import '../providers/chat_provider.dart';
import 'employee_picker.dart';
import 'ai_settings_panel.dart';

class GroupInfoPanel extends ConsumerStatefulWidget {
  final GroupChat group;

  const GroupInfoPanel({super.key, required this.group});

  @override
  ConsumerState<GroupInfoPanel> createState() => _GroupInfoPanelState();
}

class _GroupInfoPanelState extends ConsumerState<GroupInfoPanel> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isEditing = false;

  String get _currentUserId {
    final auth = ref.read(authProvider);
    return auth.user?.id ?? 'emp1';
  }

  bool get _isAdmin => widget.group.isAdmin(_currentUserId);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descController = TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(chatProvider.select((s) =>
        s.groups.firstWhere((g) => g.id == widget.group.id,
            orElse: () => widget.group)));

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroupInfoSection(group),
                const SizedBox(height: 24),
                _buildMembersSection(group),
                const SizedBox(height: 24),
                AiSettingsPanel(group: group),
                const SizedBox(height: 24),
                if (_isAdmin) _buildAdminActions(group),
                const SizedBox(height: 16),
                _buildDangerActions(group),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Group Info',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoSection(GroupChat group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildGroupAvatar(group),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberCount} members • ${group.onlineMemberCount} online',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (_isAdmin && !_isEditing)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => setState(() => _isEditing = true),
              ),
          ],
        ),
        if (group.description != null) ...[
          const SizedBox(height: 12),
          Text(
            group.description!,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupAvatar(GroupChat group) {
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
            ? Text(group.iconEmoji!, style: const TextStyle(fontSize: 28))
            : const Icon(Icons.chat_bubble, color: AppTheme.primaryColor, size: 28),
      ),
    );
  }

  Widget _buildMembersSection(GroupChat group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () => _showAddMembersDialog(group),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...group.members.map((member) => _buildMemberTile(group, member)),
      ],
    );
  }

  Widget _buildMemberTile(GroupChat group, GroupMember member) {
    final isCurrentUser = member.id == _currentUserId;
    final isAi = member.id == 'ai_assistant';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAi ? AppTheme.secondaryColor : _getColorForMember(member),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isAi
                      ? const Text('🤖', style: TextStyle(fontSize: 20))
                      : Text(
                          member.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              if (member.isOnline && !isAi)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surfaceColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${member.name}${isCurrentUser ? ' (You)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    if (isAi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (member.jobTitle != null)
                  Text(
                    member.jobTitle!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: member.role == MemberRole.admin
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              member.role == MemberRole.admin ? 'Admin' : 'Member',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: member.role == MemberRole.admin
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          if (_isAdmin && !isCurrentUser && !isAi)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) => _handleMemberAction(group, member, value),
              itemBuilder: (context) => [
                if (member.role == MemberRole.member)
                  const PopupMenuItem(value: 'promote', child: Text('Promote to Admin')),
                if (member.role == MemberRole.admin)
                  const PopupMenuItem(value: 'demote', child: Text('Demote to Member')),
                const PopupMenuItem(
                    value: 'remove', child: Text('Remove', style: TextStyle(color: AppTheme.errorColor))),
              ],
            ),
        ],
      ),
    );
  }

  Color _getColorForMember(GroupMember member) {
    final colors = [AppTheme.primaryColor, AppTheme.accentColor, AppTheme.warningColor, AppTheme.errorColor];
    final hash = member.name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildAdminActions(GroupChat group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.emoji_objects, color: AppTheme.textSecondary),
          title: const Text('Change Group Icon'),
          onTap: () => _showIconPicker(group),
        ),
      ],
    );
  }

  Widget _buildDangerActions(GroupChat group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.exit_to_app, color: AppTheme.warningColor),
          title: const Text('Leave Group', style: TextStyle(color: AppTheme.warningColor)),
          onTap: () => _showLeaveDialog(group),
        ),
        if (_isAdmin)
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
            title: const Text('Delete Group', style: TextStyle(color: AppTheme.errorColor)),
            onTap: () => _showDeleteDialog(group),
          ),
      ],
    );
  }

  void _handleMemberAction(GroupChat group, GroupMember member, String action) {
    switch (action) {
      case 'promote':
        ref.read(chatProvider.notifier).changeMemberRole(group.id, member.id, MemberRole.admin);
        break;
      case 'demote':
        ref.read(chatProvider.notifier).changeMemberRole(group.id, member.id, MemberRole.member);
        break;
      case 'remove':
        _showRemoveMemberDialog(group, member);
        break;
    }
  }

  void _showAddMembersDialog(GroupChat group) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: EmployeePicker(
            preselected: [],
            excludeIds: group.members.map((m) => m.id).toList(),
            onConfirm: (selected) {
              for (final member in selected) {
                ref.read(chatProvider.notifier).addMember(group.id, member);
              }
            },
          ),
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(GroupChat group, GroupMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).removeMember(group.id, member.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(GroupChat group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave ${group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).leaveGroup(group.id, _currentUserId);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(GroupChat group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).deleteGroup(group.id);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showIconPicker(GroupChat group) {
    final emojis = [
      '\u{1F465}', '\u{1F4BC}', '\u{1F3E2}', '\u{1F3AF}',
      '\u{1F680}', '\u{1F4A1}', '\u{1F525}', '\u{1F393}',
      '\u{1F48E}', '\u{1F527}', '\u{1F3E0}', '\u{2764}\uFE0F',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Group Icon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Emoji Icons:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          ref.read(chatProvider.notifier).updateGroupInfo(
                                group.id,
                                iconType: GroupIconType.emoji,
                                iconEmoji: e,
                              );
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
