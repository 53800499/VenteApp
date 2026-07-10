import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/auth_error_humanizer.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../bloc/auth_bloc.dart';

class EmergencyUnlockPage extends StatefulWidget {
  const EmergencyUnlockPage({super.key});

  @override
  State<EmergencyUnlockPage> createState() => _EmergencyUnlockPageState();
}

class _EmergencyUnlockPageState extends State<EmergencyUnlockPage>
    with SingleTickerProviderStateMixin {
  final _tokenController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  late final TabController _tabController;
  bool _otpSent = false;
  bool _otpSubmitting = false;
  String? _otpError;
  String? _maskedPhone;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  ({int shopId, int? userId}) _contextIds() {
    final state = context.read<AuthBloc>().state;
    return switch (state) {
      AuthLocked(:final lockScreen) => (
          shopId: lockScreen.shopId,
          userId: lockScreen.users.length == 1
              ? lockScreen.users.first.id
              : null,
        ),
      _ => (shopId: 1, userId: null),
    };
  }

  void _submitToken() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    final ids = _contextIds();
    context.read<AuthBloc>().add(
          AuthEmergencyUnlockRequested(
            recoveryToken: token,
            shopId: ids.shopId,
            userId: ids.userId,
          ),
        );
  }

  Future<void> _requestOtp() async {
    final phone = normalizeBeninPhone(_phoneController.text.trim());
    if (phone.isEmpty) return;

    setState(() {
      _otpSubmitting = true;
      _otpError = null;
    });

    try {
      final result = await sl<RequestWhatsappOtp>()(phone: phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _maskedPhone = result.maskedPhone;
        _devCode = result.devCode;
        _otpSubmitting = false;
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _otpError = humanizeAuthErrorMessage(failure.message);
        _otpSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _otpError = friendlyErrorMessage(error);
        _otpSubmitting = false;
      });
    }
  }

  void _submitOtp() {
    final phone = normalizeBeninPhone(_phoneController.text.trim());
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    final ids = _contextIds();
    context.read<AuthBloc>().add(
          AuthEmergencyUnlockWhatsappRequested(
            phone: phone,
            code: code,
            shopId: ids.shopId,
            userId: ids.userId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Déblocage d\'urgence'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Jeton'),
            Tab(text: 'WhatsApp'),
          ],
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TokenTab(
                controller: _tokenController,
                onSubmit: _submitToken,
              ),
              _WhatsappTab(
                phoneController: _phoneController,
                codeController: _codeController,
                otpSent: _otpSent,
                otpSubmitting: _otpSubmitting,
                otpError: _otpError,
                maskedPhone: _maskedPhone,
                devCode: _devCode,
                onRequestOtp: _requestOtp,
                onSubmitOtp: _submitOtp,
                onEditPhone: () => setState(() {
                  _otpSent = false;
                  _codeController.clear();
                  _otpError = null;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenTab extends StatelessWidget {
  const _TokenTab({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            icon: Icons.vpn_key_outlined,
            title: 'Jeton de récupération',
            subtitle:
                'Saisissez le jeton généré lors de l\'installation pour débloquer l\'accès.',
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Jeton de récupération',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.key_outlined),
            ),
            maxLines: 4,
          ),
          const Spacer(),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: const Text('Débloquer'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WhatsappTab extends StatelessWidget {
  const _WhatsappTab({
    required this.phoneController,
    required this.codeController,
    required this.otpSent,
    required this.otpSubmitting,
    required this.otpError,
    required this.maskedPhone,
    required this.devCode,
    required this.onRequestOtp,
    required this.onSubmitOtp,
    required this.onEditPhone,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool otpSent;
  final bool otpSubmitting;
  final String? otpError;
  final String? maskedPhone;
  final String? devCode;
  final VoidCallback onRequestOtp;
  final VoidCallback onSubmitOtp;
  final VoidCallback onEditPhone;

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            icon: Icons.chat_outlined,
            title: 'OTP WhatsApp',
            subtitle:
                'Recevez un code sur votre numéro enregistré pour débloquer l\'accès.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!otpSent) ...[
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro WhatsApp',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ] else ...[
            Text(
              'Code envoyé au ${maskedPhone ?? phoneController.text.trim()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (kDebugMode && devCode != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Code dev : $devCode',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code OTP',
                prefixIcon: Icon(Icons.sms_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            TextButton(
              onPressed: onEditPhone,
              child: const Text('Modifier le numéro'),
            ),
          ],
          if (otpError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              otpError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const Spacer(),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final blocLoading = state is AuthLoading;
              final loading = blocLoading || otpSubmitting;
              return FilledButton.icon(
                onPressed: loading
                    ? null
                    : (otpSent ? onSubmitOtp : onRequestOtp),
                icon: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(otpSent
                        ? Icons.lock_open_outlined
                        : Icons.send_outlined),
                label: Text(otpSent ? 'Débloquer' : 'Envoyer le code'),
              );
            },
          ),
        ],
      ),
    );
  }
}
