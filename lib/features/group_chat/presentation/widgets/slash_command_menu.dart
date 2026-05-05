import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SlashCommandMenu extends StatelessWidget {
  final Function(String command) onSelect;

  const SlashCommandMenu({super.key, required this.onSelect});

  static const commands = [
    SlashCommand(
      command: '/ai ask [question]',
      description: 'Ask the AI a question',
      icon: Icons.smart_toy_outlined,
    ),
    SlashCommand(
      command: '/ai summarize',
      description: 'Summarize recent messages',
      icon: Icons.summarize_outlined,
    ),
    SlashCommand(
      command: '/ai translate [language]',
      description: 'Translate last message',
      icon: Icons.translate_outlined,
    ),
    SlashCommand(
      command: '/ai draft [topic]',
      description: 'Draft a message on a topic',
      icon: Icons.edit_note_outlined,
    ),
    SlashCommand(
      command: '/ai action-items',
      description: 'Extract action items from chat',
      icon: Icons.task_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: commands.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final cmd = commands[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cmd.icon, size: 18, color: AppTheme.secondaryColor),
              ),
              title: Text(
                cmd.command,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                cmd.description,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelect(cmd.command),
            );
          },
        ),
      ),
    );
  }
}

class SlashCommand {
  final String command;
  final String description;
  final IconData icon;

  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
  });
}
