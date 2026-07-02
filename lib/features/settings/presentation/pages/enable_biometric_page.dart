import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../auth/presentation/widgets/pin_pad.dart';

class EnableBiometricPage extends StatefulWidget {
  const EnableBiometricPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<EnableBiometricPage> createState() => _EnableBiometricPageState();
}

class _EnableBiometricPageState extends State<EnableBiometricPage> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;

  String _buffer = '';
  bool _submitting = false;

  void _onDigit(String digit) {
    if (_submitting || _buffer.length >= _maxPinLength) return;
    setState(() => _buffer += digit);
    if (_buffer.length == _maxPinLength) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_submitting || _buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  Future<void> _submit() async {
    if (_buffer.length < _minPinLength) return;

    setState(() => _submitting = true);
    try {
      final ok = await sl<EnableBiometric>()(
        userId: widget.session.user.id,
        sessionToken: widget.session.token,
        pin: _buffer,
      );
      if (!ok) {
        throw const ValidationFailure(
          'Impossible d\'activer la biométrie.',
        );
      }
      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Biométrie activée',
        message: 'Vous pourrez déverrouiller avec votre empreinte.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Activation impossible',
        message: friendlyErrorMessage(e),
      );
      if (mounted) setState(() => _buffer = '');
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Activation impossible',
        message: friendlyErrorMessage(e),
      );
      if (mounted) setState(() => _buffer = '');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activer la biométrie')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                'Confirmez avec votre PIN',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Saisissez votre code PIN pour activer le déverrouillage '
                'par empreinte.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_submitting)
                const CircularProgressIndicator()
              else ...[
                PinPad(
                  filledCount: _buffer.length,
                  maxLength: _maxPinLength,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),
                if (_buffer.length >= _minPinLength &&
                    _buffer.length < _maxPinLength) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Activer'),
                  ),
                ],
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
