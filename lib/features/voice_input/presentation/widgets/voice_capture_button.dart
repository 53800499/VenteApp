import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../help/presentation/pages/help_article_page.dart';
import '../../domain/entities/voice_draft.dart';
import '../../domain/services/voice_failure_explainer.dart';
import '../cubit/voice_input_cubit.dart';

const _voiceHelpArticleId = 'voice_assistant';

void _openVoiceHelp(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const HelpArticlePage(articleId: _voiceHelpArticleId),
    ),
  );
}

/// Indicateur d’écoute très visible : « Parlez maintenant » / « Préparation… ».
class VoiceListenStatusPanel extends StatelessWidget {
  const VoiceListenStatusPanel({
    super.key,
    required this.status,
    this.partialText = '',
    this.question,
    this.details,
  });

  final VoiceInputStatus status;
  final String partialText;
  final String? question;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listening = status == VoiceInputStatus.listening;
    final preparing = status == VoiceInputStatus.preparing;
    final parsing = status == VoiceInputStatus.parsing;
    final hasPartial = listening && partialText.trim().isNotEmpty;

    Color bannerBg;
    Color bannerFg;
    IconData icon;
    String headline;
    String? subtitle;

    if (preparing) {
      bannerBg = scheme.surfaceContainerHighest;
      bannerFg = scheme.onSurfaceVariant;
      icon = Icons.hourglass_top_rounded;
      headline = 'Préparation…';
      subtitle = 'Ne parlez pas encore.';
    } else if (parsing) {
      bannerBg = scheme.primaryContainer;
      bannerFg = scheme.onPrimaryContainer;
      icon = Icons.auto_awesome;
      headline = 'Analyse…';
      subtitle = 'Patientez un instant.';
    } else if (listening) {
      bannerBg = scheme.errorContainer;
      bannerFg = scheme.onErrorContainer;
      icon = Icons.mic;
      headline = 'Parlez maintenant';
      subtitle = hasPartial
          ? null
          : 'Prenez votre temps, puis touchez « J’ai fini ».';
    } else {
      bannerBg = scheme.surfaceContainerHighest;
      bannerFg = scheme.onSurfaceVariant;
      icon = Icons.mic_none;
      headline = 'Micro';
      subtitle = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question != null && question!.trim().isNotEmpty) ...[
          Text(
            question!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (details != null && details!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(14),
            border: listening
                ? Border.all(color: scheme.error.withValues(alpha: 0.55), width: 2)
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: listening ? 48 : 36, color: bannerFg),
              const SizedBox(height: 10),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: bannerFg,
                      letterSpacing: listening ? 0.3 : 0,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: bannerFg.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
              if (hasPartial) ...[
                const SizedBox(height: 12),
                Text(
                  '« ${partialText.trim()} »',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: bannerFg,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Continuez ou touchez « J’ai fini ».',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: bannerFg.withValues(alpha: 0.85),
                      ),
                ),
              ],
              if (preparing || parsing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: bannerFg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bloc d’aide : exemples de phrases + lien vers le guide.
class VoiceFailureHelpBlock extends StatelessWidget {
  const VoiceFailureHelpBlock({
    super.key,
    required this.kind,
    this.compact = false,
  });

  final VoiceIntentKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final examples = voiceExamplePhrasesFor(kind);
    final onVariant = Theme.of(context).colorScheme.onErrorContainer;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Exemples qui fonctionnent',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: compact ? onVariant : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        for (final phrase in examples.take(compact ? 2 : 4))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '« $phrase »',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: compact
                    ? onVariant
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: compact ? onVariant : scheme.primary,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _openVoiceHelp(context),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Guide Assistant vocal'),
          ),
        ),
      ],
    );
  }
}

/// Dialogue d'échec de l'assistant vocal (raison + exemples + guide).
Future<void> showVoiceAssistantFailureDialog(
  BuildContext context, {
  required String message,
  String title = 'Assistant vocal — échec',
  VoiceIntentKind kind = VoiceIntentKind.unknown,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.md),
            VoiceFailureHelpBlock(kind: kind),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _openVoiceHelp(context);
          },
          child: const Text('Ouvrir le guide'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Réponse Q&A V3 (stock, solde FX, dépenses…).
Future<VoiceAnswerAction?> showVoiceAnswerDialog(
  BuildContext context, {
  required String title,
  required String answer,
  bool canOpenScreen = true,
}) {
  return showDialog<VoiceAnswerAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(answer)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, VoiceAnswerAction.done),
            child: const Text('Terminer'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, VoiceAnswerAction.anotherCommand),
            child: const Text('Autre commande'),
          ),
          if (canOpenScreen)
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, VoiceAnswerAction.openScreen),
              child: const Text('Ouvrir l’écran'),
            ),
        ],
      );
    },
  );
}

/// Clarification si confiance faible ou intents proches.
Future<VoiceIntentKind?> showVoiceClarifyDialog(
  BuildContext context, {
  required String transcript,
  required List<VoiceIntentKind> options,
  int? confidencePercent,
}) {
  assert(options.isNotEmpty);
  return showDialog<VoiceIntentKind>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('ARIKE Assistant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                confidencePercent != null
                    ? 'Je ne suis pas sûr ($confidencePercent %). '
                        'Vous vouliez :'
                    : 'Je n’ai pas bien compris. Vous vouliez :',
              ),
              const SizedBox(height: 8),
              Text(
                '« $transcript »',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
              for (final kind in options) ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, kind),
                  child: Text(kind.labelFr),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      );
    },
  );
}

/// Question ARIKE d’un workflow + écoute d’une réponse (Annuler → null).
Future<String?> showVoiceWorkflowPromptDialog({
  required BuildContext context,
  required VoiceInputCubit cubit,
  required String question,
  String? details,
}) async {
  var dialogOpen = true;
  final done = Completer<String?>();

  Future<void> closeDialog(BuildContext dialogContext) async {
    if (!dialogOpen) return;
    dialogOpen = false;
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: cubit,
        child: _VoiceWorkflowPromptDialog(
          question: question,
          details: details,
          onReady: () async {
            final text = await cubit.captureTranscriptOnly();
            await closeDialog(dialogContext);
            if (!done.isCompleted) done.complete(text);
          },
          onCancel: () async {
            await cubit.cancelListening();
            await closeDialog(dialogContext);
            if (!done.isCompleted) done.complete(null);
          },
        ),
      );
    },
  );

  return done.future;
}

class _VoiceWorkflowPromptDialog extends StatefulWidget {
  const _VoiceWorkflowPromptDialog({
    required this.question,
    required this.onReady,
    required this.onCancel,
    this.details,
  });

  final String question;
  final String? details;
  final Future<void> Function() onReady;
  final Future<void> Function() onCancel;

  @override
  State<_VoiceWorkflowPromptDialog> createState() =>
      _VoiceWorkflowPromptDialogState();
}

class _VoiceWorkflowPromptDialogState extends State<_VoiceWorkflowPromptDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assistant ARIKE'),
      content: BlocBuilder<VoiceInputCubit, VoiceInputState>(
        builder: (context, state) {
          return VoiceListenStatusPanel(
            status: state.status,
            partialText: state.partialText,
            question: widget.question,
            details: widget.details,
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onCancel(),
          child: const Text('Annuler'),
        ),
        BlocBuilder<VoiceInputCubit, VoiceInputState>(
          buildWhen: (p, c) => p.status != c.status,
          builder: (context, state) {
            if (state.status != VoiceInputStatus.listening) {
              return const SizedBox.shrink();
            }
            return FilledButton(
              onPressed: () =>
                  context.read<VoiceInputCubit>().finishListening(),
              child: const Text('J\'ai fini'),
            );
          },
        ),
      ],
    );
  }
}

/// Confirmation d’un lot (ex. « tout » sur plusieurs dettes).
Future<VoicePreviewAction?> showVoiceBatchPreviewSheet({
  required BuildContext context,
  required String title,
  required String summary,
  required String transcript,
}) {
  return showModalBottomSheet<VoicePreviewAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '« $transcript »',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(summary),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, VoicePreviewAction.save),
                child: const Text('Enregistrer tout'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(ctx, VoicePreviewAction.cancel),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Propose d’enchaîner une autre commande dans la session V3.
Future<bool> showVoiceContinueDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Assistant ARIKE'),
        content: const Text('Autre commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui'),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Bottom sheet de prévisualisation avant enregistrement / modification.
Future<VoicePreviewAction?> showVoicePreviewSheet({
  required BuildContext context,
  required VoiceDraft draft,
}) {
  return showModalBottomSheet<VoicePreviewAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final isWriteForm = draft.kind == VoiceIntentKind.procurementOrder ||
          draft.kind == VoiceIntentKind.sale ||
          draft.kind == VoiceIntentKind.createProduct ||
          draft.kind == VoiceIntentKind.createCategory;
      final isQuery = draft.kind.isQuery;
      final saveLabel = isWriteForm || isQuery ? null : 'Enregistrer';
      final editLabel = isWriteForm
          ? 'Ouvrir le formulaire'
          : (isQuery ? null : 'Modifier le formulaire');
      final blocked =
          (!draft.canSave || draft is VoiceUnknownDraft) && !isQuery;
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prévisualisation — ${draft.kind.labelFr}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '« ${draft.transcript} »',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._rowsFor(draft),
              if (blocked) ...[
                const SizedBox(height: AppSpacing.sm),
                Material(
                  color: Theme.of(ctx).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pourquoi ça n’a pas abouti',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(ctx).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          explainVoiceDraftFailureShort(draft),
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        VoiceFailureHelpBlock(
                          kind: draft.kind,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (draft is VoiceDebtPaymentDraft && draft.multipleDebts)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Plusieurs dettes ouvertes : la plus importante est proposée.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (saveLabel != null)
                FilledButton(
                  onPressed: draft.canSave
                      ? () => Navigator.pop(ctx, VoicePreviewAction.save)
                      : null,
                  child: Text(saveLabel),
                ),
              if (saveLabel != null) const SizedBox(height: AppSpacing.xs),
              if (editLabel != null)
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, VoicePreviewAction.editForm),
                  child: Text(editLabel),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, VoicePreviewAction.cancel),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

List<Widget> _rowsFor(VoiceDraft draft) {
  if (draft is VoiceSaleDraft) {
    final rows = <Widget>[
      _row('Client', draft.customerName ?? '— (optionnel)'),
    ];
    if (draft.lines.isEmpty) {
      rows.add(_row('Produit', '—'));
    } else {
      for (var i = 0; i < draft.lines.length; i++) {
        final line = draft.lines[i];
        final label = draft.lines.length > 1 ? 'Ligne ${i + 1}' : 'Produit';
        final unit = line.resolvedUnitPrice;
        final qty = line.quantity;
        final name = line.productName ?? '—';
        final detail = [
          if (qty != null) '$qty ×',
          name,
          if (unit != null) '(${formatFcfa(unit)})',
        ].join(' ');
        rows.add(_row(label, detail));
        if (line.stockAvailable != null && draft.lines.length == 1) {
          rows.add(_row('Stock dispo', '${line.stockAvailable}'));
        }
      }
      final total = draft.cartTotal;
      if (total != null) {
        rows.add(_row('Total panier', formatFcfa(total)));
      }
    }
    return rows;
  }
  if (draft is VoiceExpenseDraft) {
    return [
      _row('Titre', draft.title ?? '—'),
      _row(
        'Montant',
        draft.amount != null ? formatFcfa(draft.amount!) : '—',
      ),
      _row('Catégorie', draft.categoryName ?? '— (optionnel)'),
    ];
  }
  if (draft is VoiceCreateProductDraft) {
    return [
      _row('Nom', draft.name ?? '—'),
      _row(
        'Prix vente',
        draft.priceSell != null ? formatFcfa(draft.priceSell!) : '—',
      ),
      if (draft.priceBuy != null)
        _row('Prix achat', formatFcfa(draft.priceBuy!)),
      _row('Catégorie', draft.categoryName ?? draft.rawCategoryQuery ?? '—'),
      if (draft.sku != null) _row('Référence', draft.sku!),
      if (draft.quantity != null) _row('Stock initial', '${draft.quantity}'),
    ];
  }
  if (draft is VoiceCreateCategoryDraft) {
    return [
      _row('Nom', draft.name ?? '—'),
      _row('Description', draft.description ?? '— (optionnel)'),
    ];
  }
  if (draft is VoiceDebtPaymentDraft) {
    return [
      _row('Client', draft.customerName ?? '—'),
      _row(
        'Montant',
        draft.amount != null ? formatFcfa(draft.amount!) : '—',
      ),
      if (draft.amountRemaining != null)
        _row('Reste dû', formatFcfa(draft.amountRemaining!)),
    ];
  }
  if (draft is VoiceFxDraft) {
    return [
      _row(
        'Type',
        draft.operationTypeCode == 'buy' ? 'Achat devise' : 'Vente devise',
      ),
      _row('Devise', draft.foreignCurrency ?? '—'),
      _row(
        'Entrée',
        draft.fromAmount != null && draft.fromCurrency != null
            ? '${formatFcfa(draft.fromAmount!)} (${draft.fromCurrency})'
                .replaceAll(' FCFA', draft.fromCurrency == 'XOF' ? ' FCFA' : '')
            : '—',
      ),
      _row(
        'Sortie',
        draft.toAmount != null
            ? '${draft.toAmount} ${draft.toCurrency ?? ''}'
            : '—',
      ),
      if (draft.rateLabel != null) _row('Taux', draft.rateLabel!),
    ];
  }
  if (draft is VoiceProcurementDraft) {
    return [
      _row('Fournisseur', draft.supplierName ?? '— (optionnel)'),
      _row('Produit', draft.productName ?? '—'),
      _row('Quantité', draft.quantity?.toString() ?? '—'),
    ];
  }
  if (draft is VoiceReceivePurchaseDraft) {
    return [
      _row('Commande', draft.poNumber ?? '—'),
      _row('Fournisseur', draft.supplierName ?? '—'),
      _row('Produit', draft.productName ?? '—'),
      _row('Qté reçue', draft.quantityReceived?.toString() ?? '—'),
      if (draft.remainingBefore != null)
        _row('Reste avant', '${draft.remainingBefore}'),
      _row(
        'Prix unitaire',
        draft.unitCost != null ? formatFcfa(draft.unitCost!) : '—',
      ),
    ];
  }
  return const [];
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// Bouton micro AppBar + écoute / erreurs.
class VoiceCaptureButton extends StatelessWidget {
  const VoiceCaptureButton({
    super.key,
    required this.expectedKind,
    required this.onCapture,
  });

  final VoiceIntentKind expectedKind;
  final Future<void> Function() onCapture;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceInputCubit, VoiceInputState>(
      builder: (context, state) {
        if (!state.enabled) return const SizedBox.shrink();

        final listening = state.status == VoiceInputStatus.listening;
        final busy = listening || state.status == VoiceInputStatus.parsing;

        return IconButton(
          tooltip: listening
              ? 'Écoute en cours…'
              : 'Saisie vocale',
          onPressed: busy
              ? () => context.read<VoiceInputCubit>().cancelListening()
              : () => onCapture(),
          icon: Icon(
            listening ? Icons.mic : Icons.mic_none,
            color: listening ? Theme.of(context).colorScheme.error : null,
          ),
        );
      },
    );
  }
}

/// Bannière texte partiel pendant l'écoute.
class VoiceListeningBanner extends StatelessWidget {
  const VoiceListeningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceInputCubit, VoiceInputState>(
      buildWhen: (p, c) =>
          p.status != c.status || p.partialText != c.partialText,
      builder: (context, state) {
        if (state.status != VoiceInputStatus.listening &&
            state.status != VoiceInputStatus.parsing &&
            state.status != VoiceInputStatus.preparing) {
          return const SizedBox.shrink();
        }
        final listening = state.status == VoiceInputStatus.listening;
        final preparing = state.status == VoiceInputStatus.preparing;
        final scheme = Theme.of(context).colorScheme;
        final bg = listening
            ? scheme.errorContainer
            : preparing
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer;
        final fg = listening
            ? scheme.onErrorContainer
            : preparing
                ? scheme.onSurfaceVariant
                : scheme.onPrimaryContainer;
        final title = switch (state.status) {
          VoiceInputStatus.preparing => 'Préparation… Ne parlez pas encore',
          VoiceInputStatus.parsing => 'Analyse…',
          _ => state.partialText.isEmpty
              ? 'Parlez maintenant'
              : 'Écoute : ${state.partialText}',
        };
        return Material(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(
                  listening ? Icons.mic : Icons.hourglass_top,
                  color: fg,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: listening ? 16 : 14,
                    ),
                  ),
                ),
                if (!listening)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
