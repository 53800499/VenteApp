import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_entities.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../features/onboarding/presentation/pages/splash_page.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/pin_pad.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;
  String _pin = '';
  int? _selectedUserId;
  int? _lastLockShopId;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _syncSelectedUser(LockScreenData lockScreen) {
    if (_lastLockShopId != lockScreen.shopId) {
      _lastLockShopId = lockScreen.shopId;
      _selectedUserId = null;
    }
    final validIds = lockScreen.users.map((user) => user.id).toSet();
    if (_selectedUserId == null || !validIds.contains(_selectedUserId)) {
      _selectedUserId = lockScreen.users.firstOrNull?.id;
    }
  }

  Future<void> _confirmExitToEntry(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer d\'utilisateur'),
        content: const Text(
          'Pour des raisons de sécurité, aucun utilisateur ne peut accéder '
          'au panel d\'un autre compte avec un simple code PIN.\n\n'
          'Pour changer d\'utilisateur, vous devez vous authentifier par WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Connexion WhatsApp'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthLockScreenExitRequested());
  }

  void _onDigit(String digit) {
    final state = context.read<AuthBloc>().state;
    if (state is AuthLocked && state.isSubmitting) return;
    if (_pin.length >= _maxPinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _maxPinLength) _submitPin();
  }

  void _onBackspace() {
    final state = context.read<AuthBloc>().state;
    if (state is AuthLocked && state.isSubmitting) return;
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submitPin() {
    if (_pin.length < _minPinLength) return;
    final state = context.read<AuthBloc>().state;
    if (state is! AuthLocked) return;

    final lockScreen = state.lockScreen;
    _syncSelectedUser(lockScreen);
    final userId =
        lockScreen.users
            .where((user) => user.id == _selectedUserId)
            .firstOrNull
            ?.id ??
        lockScreen.users.firstOrNull?.id;

    context.read<AuthBloc>().add(
      AuthLoginRequested(pin: _pin, shopId: lockScreen.shopId, userId: userId),
    );
    setState(() => _pin = '');
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final digitMap = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad9: '9',
    };

    if (digitMap.containsKey(key)) {
      _onDigit(digitMap[key]!);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submitPin();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      final state = context.read<AuthBloc>().state;
      if (state is AuthLocked && state.canGoBack && !state.isSubmitting) {
        context.read<AuthBloc>().add(const AuthLockScreenBackRequested());
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLocked && state.errorMessage != null) {
          setState(() => _pin = '');
        }
        if (state is AuthAuthenticated && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        if (state is! AuthLocked) {
          return const SplashPage();
        }

        final lockScreen = state.lockScreen;
        _syncSelectedUser(lockScreen);
        final selectedUser = lockScreen.users
            .where((user) => user.id == _selectedUserId)
            .firstOrNull;

        return Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = Breakpoints.isDesktopWidth(
                      constraints.maxWidth,
                    );

                    if (isDesktop) {
                      return _buildDesktopLayout(
                        context,
                        state,
                        lockScreen,
                        selectedUser,
                        constraints,
                      );
                    }

                    return ResponsivePage(
                      maxWidth: Breakpoints.authMaxWidth,
                      padding: EdgeInsets.zero,
                      child: _buildMobileLayout(
                        context,
                        state,
                        lockScreen,
                        selectedUser,
                        constraints,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AuthLocked state,
    LockScreenData lockScreen,
    LockScreenUser? selectedUser,
    BoxConstraints constraints,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- VOLET GAUCHE : IDENTITÉ, BOUTIQUE, SÉCURITÉ ---
        // Occupe l'intégralité de la section gauche, pleine hauteur, bord à bord
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.lockGradientTop,
                  AppColors.lockGradientBottom,
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.canGoBack)
                        TextButton.icon(
                          onPressed: state.isSubmitting
                              ? null
                              : () => context.read<AuthBloc>().add(
                                  const AuthLockScreenBackRequested(),
                                ),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Retour à l\'accueil'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'POSTE DE CAISSE SÉCURISÉ',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      ShopAvatar(label: lockScreen.shopName, radius: 44),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        lockScreen.shopName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Session locale active & protégée',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (selectedUser != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person_outline,
                                  size: 22,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedUser.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedUser.role.label,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      if (!state.canGoBack)
                        OutlinedButton.icon(
                          onPressed: state.isSubmitting
                              ? null
                              : () => _confirmExitToEntry(context),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Changer d\'utilisateur'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      // Badge Hors-ligne & Sécurité locale
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fonctionne sans connexion Internet · Données chiffrées localement',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // --- VOLET DROIT : PAVÉ PIN & SAISIE ---
        // Occupe l'intégralité de la section droite, avec le pavé numérique centré
        Expanded(
          flex: 6,
          child: Container(
            color: colorScheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Entrez votre code PIN',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saisissez vos 4 à 6 chiffres secrets',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        ErrorBanner(message: state.errorMessage!),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PinPad(
                        filledCount: _pin.length,
                        maxLength: _maxPinLength,
                        compact: false,
                        enabled: !state.isSubmitting,
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_pin.length >= _minPinLength &&
                          _pin.length < _maxPinLength) ...[
                        FilledButton.icon(
                          onPressed: state.isSubmitting ? null : _submitPin,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Valider (Entrée)'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(220, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (state.isSubmitting)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: CircularProgressIndicator(),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selectedUser?.biometricEnabled == true) ...[
                            TextButton.icon(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () {
                                      context.read<AuthBloc>().add(
                                        AuthBiometricLoginRequested(
                                          shopId: lockScreen.shopId,
                                          userId: _selectedUserId,
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.fingerprint, size: 18),
                              label: const Text('Biométrie'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          TextButton(
                            onPressed: state.isSubmitting
                                ? null
                                : () {
                                    final user =
                                        selectedUser ??
                                        lockScreen.users.firstOrNull;
                                    Navigator.of(context).pushNamed(
                                      AppRouter.forgotPin,
                                      arguments: <String, int?>{
                                        'shopId': lockScreen.shopId,
                                        'userId': user?.id,
                                      },
                                    );
                                  },
                            child: const Text('PIN oublié ?'),
                          ),
                        ],
                      ),
                      if (state.requiresEmergencyRecovery) ...[
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AppRouter.emergencyUnlock),
                          child: const Text('Déblocage d\'urgence'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_outlined,
                              size: 16,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Clavier & pavé numérique actifs (0-9, Entrée)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AuthLocked state,
    LockScreenData lockScreen,
    LockScreenUser? selectedUser,
    BoxConstraints constraints,
  ) {
    final compact = constraints.maxHeight < 720;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        compact ? AppSpacing.sm : AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          if (state.canGoBack)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.read<AuthBloc>().add(
                        const AuthLockScreenBackRequested(),
                      ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour à l\'accueil'),
              ),
            ),
          ShopAvatar(label: lockScreen.shopName, radius: compact ? 36 : 44),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            lockScreen.shopName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Entrez votre code PIN',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (selectedUser != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _UserChip(name: selectedUser.name, role: selectedUser.role.label),
          ],
          if (state.errorMessage != null) ...[
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            ErrorBanner(message: state.errorMessage!),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            if (state.canGoBack)
              TextButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.read<AuthBloc>().add(
                        const AuthLockScreenBackRequested(),
                      ),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Retour à l\'accueil'),
              )
            else
              OutlinedButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => _confirmExitToEntry(context),
                icon: const Icon(Icons.logout),
                label: const Text('Retour à l\'accueil'),
              ),
            Text(
              state.canGoBack
                  ? 'Choisissez un autre mode de connexion '
                        '(WhatsApp, PIN…).'
                  : 'Quittez le verrouillage et reconnectez-vous '
                        'par WhatsApp, PIN ou une autre boutique.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          PinPad(
            filledCount: _pin.length,
            maxLength: _maxPinLength,
            compact: compact,
            enabled: !state.isSubmitting,
            onDigit: _onDigit,
            onBackspace: _onBackspace,
          ),
          if (_pin.length >= _minPinLength && _pin.length < _maxPinLength) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: state.isSubmitting ? null : _submitPin,
              child: const Text('Valider'),
            ),
          ],
          if (state.isSubmitting)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: CircularProgressIndicator(),
            ),
          if (selectedUser?.biometricEnabled == true) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: state.isSubmitting
                  ? null
                  : () {
                      context.read<AuthBloc>().add(
                        AuthBiometricLoginRequested(
                          shopId: lockScreen.shopId,
                          userId: _selectedUserId,
                        ),
                      );
                    },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Empreinte digitale'),
            ),
          ],
          if (state.requiresEmergencyRecovery) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.emergencyUnlock),
              child: const Text('Déblocage d\'urgence'),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : () {
                    final user = selectedUser ?? lockScreen.users.firstOrNull;
                    Navigator.of(context).pushNamed(
                      AppRouter.forgotPin,
                      arguments: <String, int?>{
                        'shopId': lockScreen.shopId,
                        'userId': user?.id,
                      },
                    );
                  },
            child: const Text('PIN oublié ?'),
          ),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$name · $role',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
