import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/api_settings_storage.dart';

/// Permet de configurer l'adresse du backend (téléphone physique, réseau local).
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
    _controller.text = custom ?? _suggestedHost();
  }

  String _suggestedHost() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '192.168.1.100:3010';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Serveur : ${client.baseUrl}'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion serveur')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Adresse du backend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Émulateur Android : 10.0.2.2:3010 (par défaut).\n'
              'Téléphone physique : IP du PC sur le Wi-Fi, ex. 192.168.1.100:3010.\n'
              'Le backend doit écouter sur 0.0.0.0:3010.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              title: const Text('Utiliser l\'adresse par défaut'),
              subtitle: Text(ApiConfig.defaultBaseUrl()),
              value: _useDefault,
              onChanged: (value) => setState(() => _useDefault = value),
            ),
            if (!_useDefault) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Adresse IP ou URL',
                  hintText: '192.168.1.100:3010',
                  prefixIcon: Icon(Icons.dns_outlined),
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
            const SizedBox(height: AppSpacing.md),
            Text(
              'URL actuelle : ${sl<ApiClient>().baseUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
