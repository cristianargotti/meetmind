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
  String get loginWithGoogle => 'Continuar com Google';

  @override
  String get loginWithApple => 'Continuar com Apple';

  @override
  String get loginSkip => 'Continuar sem conta';

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
  String get homeGreetingMorning => 'Bom dia';

  @override
  String get homeGreetingAfternoon => 'Boa tarde';

  @override
  String get homeGreetingEvening => 'Boa noite';

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
  String get accountTitle => 'Conta';

  @override
  String get accountSignOut => 'Sair';

  @override
  String get accountSignOutConfirm => 'Tem certeza de que deseja sair?';

  @override
  String get accountDeleteAccount => 'Excluir Conta';

  @override
  String get accountDeleteConfirmTitle => 'Excluir Conta?';

  @override
  String get accountDeleteConfirmBody =>
      'Isso excluirá permanentemente sua conta e todos os dados de reuniões. Esta ação não pode ser desfeita.';

  @override
  String get accountDeleteConfirmButton => 'Excluir Tudo';

  @override
  String get accountGuestUser => 'Usuário Convidado';

  @override
  String get accountLinkedAccounts => 'Contas Vinculadas';

  @override
  String get authCreateAccount => 'Criar Conta';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authName => 'Nome';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authForgotPassword => 'Esqueceu a senha?';

  @override
  String get authToggleToRegister => 'Não tem conta? Cadastre-se';

  @override
  String get authToggleToLogin => 'Já tem uma conta? Entre';

  @override
  String get authPasswordMinLength =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get authFillFields => 'Digite e-mail e senha';

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
  String get paywallProductsUnavailable =>
      'Os produtos de assinatura estão temporariamente indisponíveis. Tente novamente em um momento.';

  @override
  String get paywallLegal =>
      'A assinatura renova automaticamente pelo preço indicado, a menos que seja cancelada pelo menos 24 horas antes do final do período atual. O pagamento é cobrado na sua conta Apple ID. Ao assinar, você concorda com nossa Política de Privacidade e Termos de Uso.';

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
  String get legalLastUpdated => 'Última atualização: Fevereiro 2026';

  @override
  String get privacyIntro => 'Sua Privacidade Importa';

  @override
  String get privacyIntroDesc =>
      'Aura Meet foi projetado com a privacidade como prioridade. Veja como lidamos com seus dados:';

  @override
  String get privacyAudioTitle => '🎙️ Processamento de Áudio';

  @override
  String get privacyAudioDesc =>
      '• O reconhecimento de voz é executado NO SEU DISPOSITIVO\n• Nenhum áudio é enviado aos nossos servidores ou armazenado na nuvem\n• Os dados de áudio permanecem no seu dispositivo em todos os momentos';

  @override
  String get privacyDataTitle => '📝 Dados de Reuniões';

  @override
  String get privacyDataDesc =>
      '• As transcrições são enviadas aos nossos servidores apenas para análise com IA\n• Os dados são armazenados com segurança e criptografia em repouso\n• Você pode excluir qualquer reunião e seus dados a qualquer momento';

  @override
  String get privacyAiTitle => '🤖 Processamento IA e Serviços de Terceiros';

  @override
  String get privacyAiDesc =>
      '• As transcrições (apenas texto, nunca áudio) são enviadas a provedores externos de IA para análise\n• Provedores de IA: Amazon Web Services (AWS Bedrock) e OpenAI\n• Objetivo: Gerar resumos, insights e ações de reuniões\n• Os provedores de IA processam dados sob acordos rigorosos de processamento\n• Não usamos seus dados para treinar modelos de IA\n• Você pode consultar as políticas de privacidade dos nossos provedores a qualquer momento';

  @override
  String get privacySubsTitle => '💳 Assinaturas';

  @override
  String get privacySubsDesc =>
      '• Nunca vemos nem armazenamos seus dados de pagamento\n• Apple/Google processa todos os pagamentos';

  @override
  String get privacyRightsTitle => '🔒 Seus Direitos';

  @override
  String get privacyRightsDesc =>
      '• Solicite a exclusão de todos os seus dados a qualquer momento\n• Exporte todos os dados de suas reuniões\n• Não vendemos seus dados a terceiros\n• Não usamos seus dados para publicidade';

  @override
  String get privacyContact =>
      'Para consultas de privacidade: privacy@aurameet.live';

  @override
  String get privacyDeleteAccount => 'Excluir Minha Conta';

  @override
  String get privacyDeleteConfirm =>
      'Isso excluirá permanentemente sua conta e todos os dados associados. Esta ação não pode ser desfeita.';

  @override
  String get privacyDeleteButton => 'Excluir Tudo';

  @override
  String get termsIntro => 'Termos de Serviço';

  @override
  String get termsIntroDesc =>
      'Ao usar o Aura Meet, você concorda com estes termos:';

  @override
  String get termsServiceTitle => '📱 Serviço';

  @override
  String get termsServiceDesc =>
      '• Aura Meet é um assistente de reuniões com IA\n• Fornecemos transcrição, insights e gerenciamento de reuniões\n• A disponibilidade do serviço é oferecida com o melhor esforço\n• Os recursos podem mudar conforme melhoramos o produto';

  @override
  String get termsSubsTitle => '💰 Assinaturas';

  @override
  String get termsSubsDesc =>
      '• Plano gratuito: 3 reuniões/semana com recursos limitados\n• As assinaturas renovam automaticamente, a menos que sejam canceladas\n• Cancele a qualquer momento pela App Store ou Google Play\n• Sem reembolsos por períodos parciais de cobrança';

  @override
  String get termsUseTitle => '✅ Uso Aceitável';

  @override
  String get termsUseDesc =>
      '• Use o Aura Meet para assistência legítima em reuniões\n• Cumpra todas as leis aplicáveis de consentimento de gravação\n• Você é responsável por obter o consentimento dos participantes';

  @override
  String get termsLiabilityTitle => '⚖️ Responsabilidade';

  @override
  String get termsLiabilityDesc =>
      '• Insights gerados por IA podem não ser 100% precisos\n• Não somos responsáveis por decisões tomadas com base em análises de IA\n• O serviço é fornecido \"como está\" sem garantias';

  @override
  String get termsContact => 'Para suporte: support@aurameet.live';

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
  String get onboardingMicAllow => 'Continuar';

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

  @override
  String get paywallWelcome => 'Bem-vindo ao Aura Pro!';

  @override
  String paywallSave(String amount) {
    return 'Economize $amount%';
  }

  @override
  String get paywallRestoring => 'Restaurando...';

  @override
  String get paywallSuccessRestore => '✅ Compras restauradas!';

  @override
  String get paywallNoRestore => 'Nenhuma compra anterior encontrada';

  @override
  String get paywallFeatUnlimited => 'Ilimitadas';

  @override
  String get paywallFeatForever => 'Para sempre';

  @override
  String get paywallFeatAll => 'Todos';

  @override
  String get paywallFeatMeetings => 'Reuniões por semana';

  @override
  String get paywallFeatHistory => 'Histórico de reuniões';

  @override
  String get paywallFeatInsights => 'Insights por reunião';

  @override
  String get paywallFeatChat => 'Pergunte ao Aura (Chat IA)';

  @override
  String get paywallFeatDigest => 'Resumo Semanal';

  @override
  String get paywallFeatExport => 'Exportar e compartilhar';

  @override
  String get paywallFeatBriefing => 'Briefing Pré-Reunião';

  @override
  String get forgotPasswordLink => 'Esqueceu a senha?';

  @override
  String get forgotPasswordTitle => 'Redefinir Senha';

  @override
  String get forgotPasswordDescription =>
      'Digite seu endereço de e-mail e enviaremos um link para redefinir sua senha.';

  @override
  String get forgotPasswordEnterEmail => 'Por favor, digite seu e-mail';

  @override
  String get forgotPasswordSendLink => 'Enviar Link';

  @override
  String get forgotPasswordSent => 'Link enviado!';

  @override
  String get forgotPasswordCheckInbox =>
      'Verifique sua caixa de entrada para um link de redefinição de senha. Pode levar alguns minutos.';

  @override
  String get forgotPasswordBackToLogin => 'Voltar ao Login';

  @override
  String get forgotPasswordError =>
      'Algo deu errado. Por favor, tente novamente.';

  @override
  String get aiConsentTitle => 'Processamento de Dados com IA';

  @override
  String get aiConsentBody =>
      'Aura Meet utiliza serviços de IA de terceiros para analisar as transcrições das suas reuniões e gerar resumos, insights e ações.\n\nO que é compartilhado:\n• Transcrições de reuniões (apenas texto)\n• Nunca suas gravações de áudio\n\nQuem processa os dados:\n• Amazon Web Services (AWS Bedrock)\n• OpenAI\n\nSeus dados de transcrição são processados sob acordos rigorosos de processamento e não são usados para treinar modelos de IA.';

  @override
  String get aiConsentAgree => 'Aceito';

  @override
  String get aiConsentDecline => 'Recusar';

  @override
  String get aiConsentLearnMore =>
      'Mais informações em nossa Política de Privacidade';
}
