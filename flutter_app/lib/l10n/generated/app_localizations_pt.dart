// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Aura Meet';

  @override
  String get appTagline => 'Seu copiloto de reuniões com IA';

  @override
  String get homeTitle => 'Aura Meet';

  @override
  String get homeSubtitle => 'Seu companheiro de reuniões com IA';

  @override
  String get homeToday => 'Hoje';

  @override
  String get homeInsights => 'Insights';

  @override
  String get homeActions => 'Ações';

  @override
  String get homeRecentMeetings => 'Reuniões Recentes';

  @override
  String get homeNoMeetings => 'Sem reuniões ainda';

  @override
  String get homeNoMeetingsHint =>
      'Toque no botão para iniciar sua primeira reunião';

  @override
  String get homeStartMeeting => 'Iniciar Reunião';

  @override
  String get homeMeetingInProgress => 'Reunião em Andamento';

  @override
  String get homeAiListening => 'A IA está ouvindo e analisando...';

  @override
  String get homeTranscribeRealtime =>
      'Aura vai transcrever e analisar em tempo real';

  @override
  String get homeLive => 'AO VIVO';

  @override
  String get meetingTitle => 'Reunião';

  @override
  String get meetingRecording => 'Gravando';

  @override
  String get meetingPaused => 'Pausada';

  @override
  String get meetingStopped => 'Parada';

  @override
  String get meetingStart => 'Iniciar';

  @override
  String get meetingPause => 'Pausar';

  @override
  String get meetingResume => 'Retomar';

  @override
  String get meetingStop => 'Parar';

  @override
  String get meetingTranscript => 'Transcrição';

  @override
  String get meetingInsights => 'Insights';

  @override
  String get meetingSummary => 'Resumo';

  @override
  String get meetingNoTranscript => 'Aguardando áudio...';

  @override
  String get meetingNoInsights => 'Sem insights ainda';

  @override
  String get meetingCopySummary => 'Copiar Resumo';

  @override
  String get meetingSummaryCopied =>
      'Resumo copiado para a área de transferência';

  @override
  String get historyTitle => 'Histórico';

  @override
  String get historyEmpty => 'Sem histórico de reuniões';

  @override
  String get historyEmptyHint => 'Suas reuniões anteriores aparecerão aqui';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsUiLanguage => 'Idioma do App';

  @override
  String get settingsTranscriptionLanguage => 'Idioma da Transcrição';

  @override
  String get settingsAutoDetect => 'Auto-detectar';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsAudio => 'Áudio';

  @override
  String get settingsAudioQuality => 'Qualidade de Gravação';

  @override
  String get settingsAudioStandard => 'Padrão';

  @override
  String get settingsAudioHigh => 'Alta';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsNotificationsEnabled => 'Lembretes de Reuniões';

  @override
  String get settingsHapticFeedback => 'Resposta Tátil';

  @override
  String get settingsBackendConnection => 'Conexão com Backend';

  @override
  String get settingsProtocol => 'Protocolo';

  @override
  String get settingsHost => 'Host (IP ou domínio)';

  @override
  String get settingsHostHint => '192.168.0.12 ou api.aurameet.io';

  @override
  String get settingsPort => 'Porta';

  @override
  String get settingsPortHint => '8000';

  @override
  String get settingsResetDefaults => 'Restaurar Padrões';

  @override
  String settingsBackendUpdated(String url) {
    return 'Backend atualizado: $url';
  }

  @override
  String get settingsResetDone => 'Valores restaurados';

  @override
  String get settingsSave => 'Salvar';

  @override
  String get settingsAiModels => 'Modelos de IA';

  @override
  String get settingsScreening => 'Triagem';

  @override
  String get settingsAnalysis => 'Análise';

  @override
  String get settingsDeepThink => 'Pensamento Profundo';

  @override
  String get subscriptionTitle => 'Assinatura';

  @override
  String get subscriptionFree => 'Grátis';

  @override
  String get subscriptionPro => 'Pro';

  @override
  String get subscriptionTeam => 'Equipe';

  @override
  String get subscriptionBusiness => 'Empresa';

  @override
  String get subscriptionActive => 'Assinatura ativa';

  @override
  String subscriptionFreePlan(int limit) {
    return 'Plano gratuito — $limit reuniões/semana';
  }

  @override
  String get subscriptionManage => 'Gerenciar Assinatura';

  @override
  String get subscriptionUpgrade => 'Fazer Upgrade';

  @override
  String get paywallTitle => 'Desbloqueie Todo o Poder';

  @override
  String get paywallSubtitle => 'Reuniões ilimitadas e recursos de IA';

  @override
  String get paywallMonthly => 'Mensal';

  @override
  String get paywallYearly => 'Anual';

  @override
  String paywallSaveBadge(int percent) {
    return 'Economize $percent%';
  }

  @override
  String paywallStartProMonthly(String price) {
    return 'Começar Pro — $price/mês';
  }

  @override
  String paywallStartProYearly(String price) {
    return 'Começar Pro — $price/ano';
  }

  @override
  String get paywallRestore => 'Restaurar Compras';

  @override
  String get paywallRestoreSuccess => 'Compras restauradas';

  @override
  String get paywallRestoreNone => 'Nenhuma compra encontrada para restaurar';

  @override
  String get paywallPurchaseSuccess => 'Bem-vindo ao Aura Pro! 🎉';

  @override
  String get paywallPurchaseCancelled => 'Compra cancelada';

  @override
  String paywallPurchaseError(String error) {
    return 'Erro na compra: $error';
  }

  @override
  String get paywallFeatureFree => 'Grátis';

  @override
  String get paywallFeaturePro => 'Pro';

  @override
  String get paywallFeatureMeetings => 'Reuniões';

  @override
  String paywallFeatureMeetingsFreeValue(int limit) {
    return '$limit/semana';
  }

  @override
  String get paywallFeatureMeetingsProValue => 'Ilimitadas';

  @override
  String get paywallFeatureTranscription => 'Transcrição';

  @override
  String get paywallFeatureInsights => 'Insights IA';

  @override
  String get paywallFeatureAskAura => 'Pergunte ao Aura';

  @override
  String get paywallFeatureExport => 'Exportação Completa';

  @override
  String get paywallFeatureDigest => 'Resumo Semanal';

  @override
  String get paywallLegal =>
      'A assinatura renova automaticamente. Cancele quando quiser.';

  @override
  String freeLimitBannerRemaining(int remaining) {
    return '$remaining reunião(ões) restante(s) esta semana';
  }

  @override
  String get freeLimitBannerReached => 'Limite semanal atingido';

  @override
  String freeLimitBannerUsage(int used, int limit) {
    return '$used / $limit reuniões';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get proGateLocked => 'Recurso Pro';

  @override
  String get proGateUnlock => 'Desbloquear';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidade';

  @override
  String get legalTermsOfService => 'Termos de Serviço';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String aboutVersion(String version) {
    return 'v$version — Seu copiloto de reuniões com IA';
  }

  @override
  String get askAuraTitle => 'Pergunte ao Aura';

  @override
  String get askAuraSubtitle => 'Converse com suas reuniões';

  @override
  String get askAuraPlaceholder => 'Pergunte sobre suas reuniões...';

  @override
  String get askAuraEmpty => 'Pergunte qualquer coisa sobre suas reuniões';

  @override
  String get askAuraEmptyHint =>
      'Posso pesquisar em todas as suas conversas anteriores';

  @override
  String get askAuraSuggestion1 => 'O que decidimos sobre o pricing?';

  @override
  String get askAuraSuggestion2 => 'Quais são meus action items pendentes?';

  @override
  String get askAuraSuggestion3 => 'Resuma as reuniões da semana passada';

  @override
  String get digestTitle => 'Resumo Semanal';

  @override
  String get digestSubtitle => 'Sua semana em um relance';

  @override
  String get digestMeetings => 'Reuniões';

  @override
  String get digestTimeSpent => 'Tempo em Reuniões';

  @override
  String get digestTopTopics => 'Principais Tópicos';

  @override
  String get digestActionItems => 'Action Items';

  @override
  String get digestCompleted => 'Concluídos';

  @override
  String get digestPending => 'Pendentes';

  @override
  String get digestEmpty => 'Sem reuniões esta semana';

  @override
  String get digestEmptyHint =>
      'Comece a gravar reuniões para ver seu resumo semanal';

  @override
  String get onboardingWelcome => 'Bem-vindo ao Aura Meet';

  @override
  String get onboardingWelcomeDesc =>
      'Seu copiloto de reuniões com IA que transcreve, analisa e aprende de cada conversa.';

  @override
  String get onboardingLanguage => 'Escolha Seu Idioma';

  @override
  String get onboardingLanguageDesc =>
      'Selecione o idioma do app e da transcrição.';

  @override
  String get onboardingMic => 'Acesso ao Microfone';

  @override
  String get onboardingMicDesc =>
      'Aura precisa de acesso ao microfone para transcrever suas reuniões em tempo real.';

  @override
  String get onboardingMicAllow => 'Permitir Microfone';

  @override
  String get onboardingReady => 'Tudo Pronto!';

  @override
  String get onboardingReadyDesc =>
      'Comece sua primeira reunião e deixe o Aura fazer o resto.';

  @override
  String get onboardingGetStarted => 'Começar';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Concluído';

  @override
  String get commonError => 'Algo deu errado';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonCopied => 'Copiado para a área de transferência';
}
