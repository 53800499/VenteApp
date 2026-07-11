import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/api_config.dart';
import '../../../shared/components/action_feedback.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/production_message_policy.dart';
import '../../../core/storage/api_settings_storage.dart';

/// Configuration avancée du service en ligne (développement uniquement).
class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _useDefault = true;

  @override
  void initState() {
    super.initState();
    final storage = sl<ApiSettingsStorage>();
    final custom = storage.customBaseUrl;
    _useDefault = custom == null || custom.isEmpty;
    _controller.text = custom ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storage = sl<ApiSettingsStorage>();
    final client = sl<ApiClient>();

    if (_useDefault) {
      await storage.clearCustomBaseUrl();
      client.setBaseUrl(ApiConfig.defaultBaseUrl());
    } else {
      final url = ApiConfig.normalizeUrl(_controller.text.trim());
      await storage.saveCustomBaseUrl(url);
      client.setBaseUrl(url);
    }

    if (!mounted) return;
    await ActionFeedback.showSuccess(
      context: context,
      title: 'Connexion mise à jour',
      message: 'La connexion au service en ligne a été mise à jour.',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!ProductionMessagePolicy.showServerConfiguration) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connexion')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'La configuration manuelle du service en ligne n\'est pas '
              'disponible dans cette version.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion cloud (dev)')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Service en ligne',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Par défaut : service cloud ARIKE.\n'
              'Pour le développement, vous pouvez saisir une adresse '
              'personnalisée.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              title: const Text('Utiliser le service cloud par défaut'),
              subtitle: const Text('Recommandé en production'),
              value: _useDefault,
              onChanged: (value) => setState(() => _useDefault = value),
            ),
            if (!_useDefault) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Adresse personnalisée',
                  hintText: 'Adresse IP ou domaine',
                  prefixIcon: Icon(Icons.cloud_outlined),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (_useDefault) return null;
                  if (value == null || value.trim().length < 7) {
                    return 'Entrez une adresse valide.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
