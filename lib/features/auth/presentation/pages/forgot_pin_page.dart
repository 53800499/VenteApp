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
import '../../domain/entities/auth_entities.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/pin_pad.dart';

/// Récupération PIN : WhatsApp OTP puis définition d'un nouveau code.
class ForgotPinPage extends StatefulWidget {
  const ForgotPinPage({
    super.key,
    required this.shopId,
    this.userId,
    this.serverShopId,
    this.serverUserId,
  });

  final int shopId;
  final int? userId;
  final int? serverShopId;
  final int? serverUserId;

  @override
  State<ForgotPinPage> createState() => _ForgotPinPageState();
}

class _ForgotPinPageState extends State<ForgotPinPage> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  _ForgotPinStep _step = _ForgotPinStep.phone;
  bool _submitting = false;
  String? _error;
  String? _maskedPhone;
  String? _devCode;
  String? _verificationToken;
  int? _resolvedServerShopId;
  int? _resolvedServerUserId;

  String _pin = '';
  String _confirmPin = '';
  bool _confirmingPin = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = normalizeBeninPhone(_phoneController.text.trim());
    if (phone.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await sl<RequestWhatsappOtp>()(phone: phone);
      if (!mounted) return;
      setState(() {
        _step = _ForgotPinStep.code;
        _maskedPhone = result.maskedPhone;
        _devCode = result.devCode;
        _submitting = false;
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = humanizeAuthErrorMessage(failure.message);
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _submitting = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final phone = normalizeBeninPhone(_phoneController.text.trim());
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await sl<VerifyWhatsappOtp>()(phone: phone, code: code);
      AuthMembership? membership;
      final targetServerShop = widget.serverShopId ?? widget.shopId;
      for (final candidate in result.memberships) {
        if (candidate.shopId == targetServerShop &&
            (widget.serverUserId == null ||
                candidate.userId == widget.serverUserId)) {
          membership = candidate;
          break;
        }
      }
      membership ??=
          result.memberships.length == 1 ? result.memberships.first : null;
      if (membership == null) {
        throw const UnauthorizedFailure(
          'Ce numéro n\'a pas accès à cette boutique.',
        );
      }

      if (!mounted) return;
      setState(() {
        _verificationToken = result.verificationToken;
        _resolvedServerShopId = membership!.shopId;
        _resolvedServerUserId = membership.userId;
        _step = _ForgotPinStep.newPin;
        _submitting = false;
        _pin = '';
        _confirmPin = '';
        _confirmingPin = false;
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = humanizeAuthErrorMessage(failure.message);
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _submitting = false;
      });
    }
  }

  Future<void> _submitNewPin() async {
    if (_pin.length < _minPinLength || _pin != _confirmPin) return;
    final token = _verificationToken;
    final serverShopId = _resolvedServerShopId;
    final serverUserId = _resolvedServerUserId;
    if (token == null || serverShopId == null || serverUserId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = await sl<ResetPinWithWhatsappOtp>()(
        verificationToken: token,
        serverShopId: serverShopId,
        serverUserId: serverUserId,
        newPin: _pin,
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthSessionRestored(session));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = humanizeAuthErrorMessage(failure.message);
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _submitting = false;
      });
    }
  }

  void _onPinDigit(String digit) {
    if (_confirmingPin) {
      if (_confirmPin.length >= _maxPinLength) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length == _maxPinLength) _submitNewPin();
      return;
    }
    if (_pin.length >= _maxPinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _maxPinLength) {
      setState(() => _confirmingPin = true);
    }
  }

  void _onPinBackspace() {
    if (_confirmingPin) {
      if (_confirmPin.isEmpty) {
        setState(() {
          _confirmingPin = false;
          if (_pin.isNotEmpty) {
            _pin = _pin.substring(0, _pin.length - 1);
          }
        });
        return;
      }
      setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      return;
    }
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN oublié'),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ResponsivePage(
            maxWidth: 480,
            child: switch (_step) {
              _ForgotPinStep.phone => _buildPhoneStep(context),
              _ForgotPinStep.code => _buildCodeStep(context),
              _ForgotPinStep.newPin => _buildNewPinStep(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          icon: Icons.chat_outlined,
          title: 'Vérification WhatsApp',
          subtitle:
              'Recevez un code sur le numéro enregistré pour définir un nouveau PIN.',
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Numéro WhatsApp',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(message: _error!),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _submitting ? null : _requestOtp,
          child: _submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Envoyer le code'),
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          icon: Icons.sms_outlined,
          title: 'Code reçu',
          subtitle: 'Saisissez le code envoyé sur WhatsApp.',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Envoyé au ${_maskedPhone ?? _phoneController.text.trim()}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (kDebugMode && _devCode != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Code dev : $_devCode', style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Code OTP',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
          keyboardType: TextInputType.number,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(message: _error!),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _submitting ? null : _verifyOtp,
          child: _submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continuer'),
        ),
      ],
    );
  }

  Widget _buildNewPinStep(BuildContext context) {
    final filled = _confirmingPin ? _confirmPin.length : _pin.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          icon: Icons.lock_reset_outlined,
          title: _confirmingPin ? 'Confirmez le PIN' : 'Nouveau PIN',
          subtitle: _confirmingPin
              ? 'Saisissez à nouveau votre nouveau code.'
              : 'Choisissez un code à 4 à 6 chiffres.',
        ),
        const SizedBox(height: AppSpacing.lg),
        PinPad(
          filledCount: filled,
          maxLength: _maxPinLength,
          compact: true,
          enabled: !_submitting,
          onDigit: _onPinDigit,
          onBackspace: _onPinBackspace,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(message: _error!),
        ],
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

enum _ForgotPinStep { phone, code, newPin }
