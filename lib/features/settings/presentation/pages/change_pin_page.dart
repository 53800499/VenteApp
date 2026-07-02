import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../auth/presentation/widgets/pin_pad.dart';

enum _ChangePinStep { current, nextPin, confirm }

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;

  _ChangePinStep _step = _ChangePinStep.current;
  String _buffer = '';
  String? _currentPin;
  String? _newPin;
  bool _submitting = false;

  String get _title => switch (_step) {
        _ChangePinStep.current => 'PIN actuel',
        _ChangePinStep.nextPin => 'Nouveau PIN',
        _ChangePinStep.confirm => 'Confirmer le PIN',
      };

  String get _subtitle => switch (_step) {
        _ChangePinStep.current =>
          'Saisissez votre code PIN actuel (RG-PARAM-03).',
        _ChangePinStep.nextPin =>
          'Choisissez un nouveau code de 4 à 6 chiffres.',
        _ChangePinStep.confirm => 'Saisissez à nouveau le nouveau PIN.',
      };

  void _onDigit(String digit) {
    if (_submitting || _buffer.length >= _maxPinLength) return;
    setState(() => _buffer += digit);
    if (_buffer.length == _maxPinLength) {
      _tryAdvance();
    }
  }

  void _onBackspace() {
    if (_submitting || _buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  Future<void> _tryAdvance() async {
    if (_buffer.length < _minPinLength) return;

    switch (_step) {
      case _ChangePinStep.current:
        setState(() {
          _currentPin = _buffer;
          _buffer = '';
          _step = _ChangePinStep.nextPin;
        });
      case _ChangePinStep.nextPin:
        setState(() {
          _newPin = _buffer;
          _buffer = '';
          _step = _ChangePinStep.confirm;
        });
      case _ChangePinStep.confirm:
        if (_buffer != _newPin) {
          await ActionFeedback.showErrorDialog(
            context,
            title: 'PIN différent',
            message: 'La confirmation ne correspond pas au nouveau PIN.',
          );
          if (!mounted) return;
          setState(() {
            _buffer = '';
            _step = _ChangePinStep.nextPin;
            _newPin = null;
          });
          return;
        }
        await _submit();
    }
  }

  Future<void> _submit() async {
    final current = _currentPin;
    final next = _newPin;
    if (current == null || next == null) return;

    setState(() => _submitting = true);
    try {
      await sl<ChangeUserPin>()(
        session: widget.session,
        currentPin: current,
        newPin: next,
      );
      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'PIN modifié',
        message: 'Votre code PIN a été mis à jour.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Modification impossible',
        message: friendlyErrorMessage(e),
      );
      if (mounted) {
        setState(() {
          _step = _ChangePinStep.current;
          _buffer = '';
          _currentPin = null;
          _newPin = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Modification impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
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
                    onPressed: _submitting ? null : _tryAdvance,
                    child: const Text('Continuer'),
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
