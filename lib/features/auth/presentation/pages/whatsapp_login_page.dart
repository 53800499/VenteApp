import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../bloc/auth_bloc.dart';

/// Connexion par numéro WhatsApp et code OTP.
class WhatsappLoginPage extends StatefulWidget {
  const WhatsappLoginPage({
    super.key,
    this.showBackButton = true,
  });

  final bool showBackButton;

  @override
  State<WhatsappLoginPage> createState() => _WhatsappLoginPageState();
}

class _WhatsappLoginPageState extends State<WhatsappLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _requestOtp(String phone) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthWhatsappOtpRequested(phone: phone));
  }

  void _verifyOtp(String phone) {
    if (_codeController.text.trim().length < 4) return;
    context.read<AuthBloc>().add(
          AuthWhatsappOtpVerifyRequested(
            phone: phone,
            code: _codeController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthWhatsappLogin) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final phone = state.phone ?? _phoneController.text.trim();
        final isCodeStep = state.step == WhatsappLoginStep.code;

        return Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: ResponsivePage(
                maxWidth: Breakpoints.formMaxWidth,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (widget.showBackButton)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: state.isSubmitting
                              ? null
                              : () => context
                                  .read<AuthBloc>()
                                  .add(const AuthWhatsappLoginCancelled()),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: PageHeader(
                        icon: Icons.chat_outlined,
                        title: isCodeStep
                            ? 'Vérifiez votre code'
                            : 'Connexion WhatsApp',
                        subtitle: isCodeStep
                            ? 'Entrez le code reçu sur WhatsApp au ${state.maskedPhone ?? phone}.'
                            : 'Nous enverrons un code de vérification sur votre numéro WhatsApp.',
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!isCodeStep) ...[
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: !state.isSubmitting,
                                  decoration: const InputDecoration(
                                    labelText: 'Numéro WhatsApp',
                                    hintText: '+229 01 97 00 00 00',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    final value = _phoneController.text.trim();
                                    if (value.isNotEmpty) {
                                      _requestOtp(value);
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Le numéro est requis.';
                                    }
                                    if (!isValidPhone(value)) {
                                      return 'Numéro invalide (indicatif pays requis, ex. +229…).';
                                    }
                                    return null;
                                  },
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _codeController,
                                  enabled: !state.isSubmitting,
                                  decoration: const InputDecoration(
                                    labelText: 'Code de vérification',
                                    prefixIcon: Icon(Icons.sms_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  onFieldSubmitted: (_) => _verifyOtp(phone),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => context.read<AuthBloc>().add(
                                              AuthWhatsappOtpResendRequested(
                                                phone: phone,
                                              ),
                                            ),
                                    child: const Text('Renvoyer le code'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: state.isSubmitting
                                      ? null
                                      : () {
                                          _codeController.clear();
                                          context.read<AuthBloc>().add(
                                                const AuthWhatsappPhoneEditRequested(),
                                              );
                                        },
                                  child: const Text('Modifier le numéro'),
                                ),
                              ],
                              if (state.infoMessage != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                _InfoMessage(text: state.infoMessage!),
                              ],
                              if (state.errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                ErrorBanner(message: state.errorMessage!),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () {
                                        if (isCodeStep) {
                                          _verifyOtp(phone);
                                        } else {
                                          _requestOtp(
                                            _phoneController.text.trim(),
                                          );
                                        }
                                      },
                                child: state.isSubmitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        isCodeStep
                                            ? 'Vérifier'
                                            : 'Recevoir le code',
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextButton.icon(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => context.read<AuthBloc>().add(
                                          const AuthProceedToPinLoginRequested(),
                                        ),
                                icon: const Icon(Icons.pin_outlined),
                                label: const Text(
                                  'Utiliser le PIN local à la place',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}
