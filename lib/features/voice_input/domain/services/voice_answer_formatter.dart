import '../../../../core/utils/currency_formatter.dart';
import '../entities/voice_draft.dart';

/// Phrases FR stables pour les réponses Q&A V3 / copilote Phase 3.
String formatVoiceAnswer(VoiceDraft draft) {
  return switch (draft) {
    VoiceStockQueryDraft d => _formatStock(d),
    VoiceStockAdviceDraft d => _formatStockAdvice(d),
    VoiceFxBalanceQueryDraft d => _formatFxBalance(d),
    VoiceFxMarginDraft d => _formatFxMargin(d),
    VoiceExpenseReportDraft d => _formatExpenseReport(d),
    VoiceCashExplainDraft d => _formatCashExplain(d),
    VoiceDebtCriticalDraft d => _formatDebtCritical(d),
    VoiceUnknownDraft d => d.hint,
    _ => 'Je n’ai pas de réponse pour cette demande.',
  };
}

String _formatStock(VoiceStockQueryDraft d) {
  if (d.productId == null || d.quantityInStock == null) {
    final q = d.rawProductQuery?.trim();
    if (q != null && q.isNotEmpty) {
      return 'Produit « $q » introuvable dans le stock.';
    }
    return 'Je n’ai pas reconnu le produit. Précisez le nom (ex. ciment).';
  }
  final name = d.productName ?? 'ce produit';
  final qty = d.quantityInStock!;
  if (qty <= 0) {
    return 'Il ne reste plus de $name en stock.';
  }
  return 'Il reste $qty de $name en stock.';
}

String _formatStockAdvice(VoiceStockAdviceDraft d) {
  if (d.count == 0) {
    return 'Aucun produit sous le seuil d’alerte.';
  }
  final buf = StringBuffer(
    '${d.count} produit${d.count > 1 ? 's' : ''} à surveiller :',
  );
  buf.writeln();
  buf.writeln();
  for (final line in d.lines) {
    buf.writeln(
      '• ${line.name} — reste ${line.quantityInStock} '
      '(seuil ${line.alertThreshold}) → commander ~${line.suggestedQty}',
    );
  }
  return buf.toString().trim();
}

String _formatFxBalance(VoiceFxBalanceQueryDraft d) {
  final code = d.currencyCode;
  if (code == null) {
    return 'Précisez la devise (nairas, dollars, euros…).';
  }
  if (!d.hasOpenSession) {
    return 'Aucune session de change ouverte. Ouvrez le bureau de change pour voir le solde $code.';
  }
  final amount = d.balanceAmount ?? 0;
  return 'Solde $code : ${formatAmount(amount, code)}.';
}

String _formatFxMargin(VoiceFxMarginDraft d) {
  if (!d.hasOpenSession) {
    return 'Aucune session de change ouverte. Ouvrez le bureau de change '
        'pour voir la marge du jour.';
  }
  if (d.operationCount == 0) {
    return 'Session de change ouverte : aucune opération encore. '
        'Marge actuelle : ${formatFcfa(d.totalMarginFcfa)}.';
  }
  return 'Marge change de la session : ${formatFcfa(d.totalMarginFcfa)} '
      'sur ${d.operationCount} opération${d.operationCount > 1 ? 's' : ''}.';
}

String _currencyLabel(String code) {
  return switch (code.toUpperCase()) {
    'NGN' => 'nairas',
    'USD' => 'dollars',
    'EUR' => 'euros',
    'GHS' => 'cedis',
    _ => code,
  };
}

String _formatExpenseReport(VoiceExpenseReportDraft d) {
  if (d.count == 0) {
    return 'Aucune dépense enregistrée ${d.periodLabel}.';
  }
  final buf = StringBuffer(
    '${d.count} dépense${d.count > 1 ? 's' : ''} ${d.periodLabel} '
    'pour un total de ${formatFcfa(d.totalAmount)}.',
  );
  if (d.lines.isNotEmpty) {
    buf.writeln();
    buf.writeln();
    final show = d.lines.take(3).toList();
    for (final line in show) {
      buf.writeln('• ${line.title} — ${formatFcfa(line.amount)}');
    }
    if (d.lines.length > 3) {
      buf.writeln('… et ${d.lines.length - 3} autre(s).');
    }
  }
  return buf.toString().trim();
}

String _formatCashExplain(VoiceCashExplainDraft d) {
  if (!d.hasOpenSession) {
    return 'Aucune session de caisse ouverte. Ouvrez une caisse pour voir '
        'le solde et comprendre les mouvements.';
  }
  final buf = StringBuffer(
    'Solde théorique espèces : ${formatFcfa(d.expectedCash)}.',
  );
  buf.writeln();
  buf.writeln();
  buf.writeln('Détail :');
  buf.writeln('• Fond d’ouverture : ${formatFcfa(d.openingCash)}');
  buf.writeln(
    '• Ventes cash (${d.saleCount}) : ${formatFcfa(d.salesCash)}',
  );
  buf.writeln('• Dépôts : ${formatFcfa(d.depositsCash)}');
  buf.writeln('• Dépenses : ${formatFcfa(d.expensesCash)}');
  buf.writeln('• Retraits : ${formatFcfa(d.withdrawalsCash)}');
  if (d.driverLines.isNotEmpty) {
    buf.writeln();
    buf.writeln('Principales raisons :');
    for (final line in d.driverLines) {
      buf.writeln('• $line');
    }
  }
  return buf.toString().trim();
}

String _formatDebtCritical(VoiceDebtCriticalDraft d) {
  if (d.count == 0) {
    return 'Aucune dette critique pour le moment '
        '(clients avec solde dû et activité ancienne de 30 jours ou plus).';
  }
  final buf = StringBuffer(
    '${d.count} client${d.count > 1 ? 's' : ''} en dette critique '
    'pour un total de ${formatFcfa(d.totalBalanceDue)} :',
  );
  buf.writeln();
  buf.writeln();
  for (final line in d.lines) {
    final days = line.daysSinceActivity;
    final age = days == null ? '' : ' — depuis $days j';
    buf.writeln(
      '• ${line.customerName} — ${formatFcfa(line.balanceDue)}$age',
    );
  }
  return buf.toString().trim();
}

/// Libellé devise pour messages (tests / UI).
String voiceCurrencyLabelFr(String code) => _currencyLabel(code);

/// Construit les « drivers » d’explication caisse (ordre d’impact).
List<String> buildCashExplainDrivers({
  required int openingCash,
  required int salesCash,
  required int expensesCash,
  required int withdrawalsCash,
  required int depositsCash,
  required int saleCount,
}) {
  final scored = <({int weight, String text})>[];

  if (expensesCash > 0) {
    scored.add((
      weight: expensesCash,
      text: 'Dépenses cash de ${formatFcfa(expensesCash)}',
    ));
  }
  if (withdrawalsCash > 0) {
    scored.add((
      weight: withdrawalsCash,
      text: 'Retraits de ${formatFcfa(withdrawalsCash)}',
    ));
  }
  if (salesCash == 0 || saleCount == 0) {
    scored.add((
      weight: 50_000,
      text: 'Peu ou pas de ventes cash depuis l’ouverture',
    ));
  } else if (salesCash < expensesCash + withdrawalsCash) {
    scored.add((
      weight: expensesCash + withdrawalsCash - salesCash,
      text:
          'Ventes cash (${formatFcfa(salesCash)}) inférieures aux sorties',
    ));
  }
  if (openingCash <= 0) {
    scored.add((
      weight: 40_000,
      text: 'Fond d’ouverture nul ou très faible',
    ));
  } else if (openingCash < 20_000) {
    scored.add((
      weight: 20_000 - openingCash,
      text: 'Fond d’ouverture modeste (${formatFcfa(openingCash)})',
    ));
  }
  if (depositsCash > 0) {
    scored.add((
      weight: -depositsCash,
      text: 'Dépôts reçus : ${formatFcfa(depositsCash)} (soutiennent la caisse)',
    ));
  }

  scored.sort((a, b) => b.weight.compareTo(a.weight));
  return scored.take(4).map((e) => e.text).toList();
}
