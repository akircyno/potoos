import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_button.dart';
import 'role_chip.dart';

class InviteForm extends StatefulWidget {
  const InviteForm({
    required this.onInvite,
    this.isSending = false,
    this.successMessage,
    this.errorMessage,
    super.key,
  });

  final bool isSending;
  final String? successMessage;
  final String? errorMessage;
  final Future<void> Function(String email, String role) onInvite;

  @override
  State<InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<InviteForm> {
  final emailController = TextEditingController();
  String role = 'Contributor';
  String? handledSuccessMessage;

  static const _roles = ['Contributor', 'Viewer'];
  static const _roleDescriptions = {
    'Contributor': 'Can upload, view, and download files.',
    'Viewer': 'Can view and download files only.',
  };

  @override
  void didUpdateWidget(covariant InviteForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    final successMessage = widget.successMessage;
    if (successMessage != null && successMessage != handledSuccessMessage) {
      handledSuccessMessage = successMessage;
      emailController.clear();
      role = 'Contributor';
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite someone.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          enabled: !widget.isSending,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final option in _roles)
              RoleChip(
                label: option,
                selected: role == option,
                onTap: () => setState(() => role = option),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _roleDescriptions[role] ?? '',
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: widget.isSending ? 'Sending...' : 'Send Invite',
          icon: Icons.send_outlined,
          onPressed: widget.isSending
              ? null
              : () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) return;
                  await widget.onInvite(email, role.toLowerCase());
                },
        ),
        if (widget.successMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.successMessage!,
            style: const TextStyle(
                color: Color(0xFF3B6D11),
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.errorMessage!,
            style: const TextStyle(
                color: AppColors.maroon,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
