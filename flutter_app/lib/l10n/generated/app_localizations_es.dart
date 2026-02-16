// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Aura Meet';

  @override
  String get appTagline => 'Tu copiloto de reuniones con IA';

  @override
  String get homeTitle => 'Aura Meet';

  @override
  String get homeSubtitle => 'Tu compañero de reuniones con IA';

  @override
  String get homeToday => 'Hoy';

  @override
  String get homeInsights => 'Hallazgos';

  @override
  String get homeActions => 'Acciones';

  @override
  String get homeRecentMeetings => 'Reuniones Recientes';

  @override
  String get homeNoMeetings => 'Sin reuniones aún';

  @override
  String get homeNoMeetingsHint =>
      'Toca el botón para iniciar tu primera reunión';

  @override
  String get homeStartMeeting => 'Iniciar Reunión';

  @override
  String get homeMeetingInProgress => 'Reunión en Curso';

  @override
  String get homeAiListening => 'La IA está escuchando y analizando...';

  @override
  String get homeTranscribeRealtime =>
      'Aura transcribirá y analizará en tiempo real';

  @override
  String get homeLive => 'EN VIVO';

  @override
  String get meetingTitle => 'Reunión';

  @override
  String get meetingRecording => 'Grabando';

  @override
  String get meetingPaused => 'Pausada';

  @override
  String get meetingStopped => 'Detenida';

  @override
  String get meetingStart => 'Iniciar';

  @override
  String get meetingPause => 'Pausar';

  @override
  String get meetingResume => 'Reanudar';

  @override
  String get meetingStop => 'Detener';

  @override
  String get meetingTranscript => 'Transcripción';

  @override
  String get meetingInsights => 'Hallazgos';

  @override
  String get meetingSummary => 'Resumen';

  @override
  String get meetingNoTranscript => 'Esperando audio...';

  @override
  String get meetingNoInsights => 'Sin hallazgos aún';

  @override
  String get meetingCopySummary => 'Copiar Resumen';

  @override
  String get meetingSummaryCopied => 'Resumen copiado al portapapeles';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historyEmpty => 'Sin historial de reuniones';

  @override
  String get historyEmptyHint => 'Tus reuniones anteriores aparecerán aquí';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsUiLanguage => 'Idioma de la App';

  @override
  String get settingsTranscriptionLanguage => 'Idioma de Transcripción';

  @override
  String get settingsAutoDetect => 'Auto-detectar';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAudioQuality => 'Calidad de Grabación';

  @override
  String get settingsAudioStandard => 'Estándar';

  @override
  String get settingsAudioHigh => 'Alta';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsEnabled => 'Recordatorios de Reuniones';

  @override
  String get settingsHapticFeedback => 'Retroalimentación Háptica';

  @override
  String get settingsBackendConnection => 'Conexión al Backend';

  @override
  String get settingsProtocol => 'Protocolo';

  @override
  String get settingsHost => 'Host (IP o dominio)';

  @override
  String get settingsHostHint => '192.168.0.12 o api.aurameet.io';

  @override
  String get settingsPort => 'Puerto';

  @override
  String get settingsPortHint => '8000';

  @override
  String get settingsResetDefaults => 'Restaurar Valores';

  @override
  String settingsBackendUpdated(String url) {
    return 'Backend actualizado: $url';
  }

  @override
  String get settingsResetDone => 'Valores restaurados';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get settingsAiModels => 'Modelos de IA';

  @override
  String get settingsScreening => 'Filtrado';

  @override
  String get settingsAnalysis => 'Análisis';

  @override
  String get settingsDeepThink => 'Pensamiento Profundo';

  @override
  String get subscriptionTitle => 'Suscripción';

  @override
  String get subscriptionFree => 'Gratis';

  @override
  String get subscriptionPro => 'Pro';

  @override
  String get subscriptionTeam => 'Equipo';

  @override
  String get subscriptionBusiness => 'Empresa';

  @override
  String get subscriptionActive => 'Suscripción activa';

  @override
  String subscriptionFreePlan(int limit) {
    return 'Plan gratuito — $limit reuniones/semana';
  }

  @override
  String get subscriptionManage => 'Administrar Suscripción';

  @override
  String get subscriptionUpgrade => 'Mejorar';

  @override
  String get paywallTitle => 'Desbloquea Todo el Poder';

  @override
  String get paywallSubtitle => 'Reuniones ilimitadas y funciones de IA';

  @override
  String get paywallMonthly => 'Mensual';

  @override
  String get paywallYearly => 'Anual';

  @override
  String paywallSaveBadge(int percent) {
    return 'Ahorra $percent%';
  }

  @override
  String paywallStartProMonthly(String price) {
    return 'Iniciar Pro — $price/mes';
  }

  @override
  String paywallStartProYearly(String price) {
    return 'Iniciar Pro — $price/año';
  }

  @override
  String get paywallRestore => 'Restaurar Compras';

  @override
  String get paywallRestoreSuccess => 'Compras restauradas';

  @override
  String get paywallRestoreNone => 'No se encontraron compras para restaurar';

  @override
  String get paywallPurchaseSuccess => '¡Bienvenido a Aura Pro! 🎉';

  @override
  String get paywallPurchaseCancelled => 'Compra cancelada';

  @override
  String paywallPurchaseError(String error) {
    return 'Error en la compra: $error';
  }

  @override
  String get paywallFeatureFree => 'Gratis';

  @override
  String get paywallFeaturePro => 'Pro';

  @override
  String get paywallFeatureMeetings => 'Reuniones';

  @override
  String paywallFeatureMeetingsFreeValue(int limit) {
    return '$limit/semana';
  }

  @override
  String get paywallFeatureMeetingsProValue => 'Ilimitadas';

  @override
  String get paywallFeatureTranscription => 'Transcripción';

  @override
  String get paywallFeatureInsights => 'Hallazgos IA';

  @override
  String get paywallFeatureAskAura => 'Pregunta a Aura';

  @override
  String get paywallFeatureExport => 'Exportación Completa';

  @override
  String get paywallFeatureDigest => 'Resumen Semanal';

  @override
  String get paywallLegal =>
      'La suscripción se renueva automáticamente. Cancela cuando quieras.';

  @override
  String freeLimitBannerRemaining(int remaining) {
    return '$remaining reunión(es) restante(s) esta semana';
  }

  @override
  String get freeLimitBannerReached => 'Límite semanal alcanzado';

  @override
  String freeLimitBannerUsage(int used, int limit) {
    return '$used / $limit reuniones';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get proGateLocked => 'Función Pro';

  @override
  String get proGateUnlock => 'Desbloquear';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidad';

  @override
  String get legalTermsOfService => 'Términos de Servicio';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String aboutVersion(String version) {
    return 'v$version — Tu copiloto de reuniones con IA';
  }

  @override
  String get askAuraTitle => 'Pregunta a Aura';

  @override
  String get askAuraSubtitle => 'Chatea con tus reuniones';

  @override
  String get askAuraPlaceholder => 'Pregunta sobre tus reuniones...';

  @override
  String get askAuraEmpty => 'Pregúntame lo que quieras sobre tus reuniones';

  @override
  String get askAuraEmptyHint =>
      'Puedo buscar en todas tus conversaciones pasadas';

  @override
  String get askAuraSuggestion1 => '¿Qué decidimos sobre el pricing?';

  @override
  String get askAuraSuggestion2 => '¿Cuáles son mis action items pendientes?';

  @override
  String get askAuraSuggestion3 => 'Resume las reuniones de la semana pasada';

  @override
  String get digestTitle => 'Resumen Semanal';

  @override
  String get digestSubtitle => 'Tu semana de un vistazo';

  @override
  String get digestMeetings => 'Reuniones';

  @override
  String get digestTimeSpent => 'Tiempo en Reuniones';

  @override
  String get digestTopTopics => 'Temas Principales';

  @override
  String get digestActionItems => 'Action Items';

  @override
  String get digestCompleted => 'Completados';

  @override
  String get digestPending => 'Pendientes';

  @override
  String get digestEmpty => 'Sin reuniones esta semana';

  @override
  String get digestEmptyHint =>
      'Comienza a grabar reuniones para ver tu resumen semanal';

  @override
  String get onboardingWelcome => 'Bienvenido a Aura Meet';

  @override
  String get onboardingWelcomeDesc =>
      'Tu copiloto de reuniones con IA que transcribe, analiza y aprende de cada conversación.';

  @override
  String get onboardingLanguage => 'Elige Tu Idioma';

  @override
  String get onboardingLanguageDesc =>
      'Selecciona el idioma de la app y de la transcripción.';

  @override
  String get onboardingMic => 'Acceso al Micrófono';

  @override
  String get onboardingMicDesc =>
      'Aura necesita acceso al micrófono para transcribir tus reuniones en tiempo real.';

  @override
  String get onboardingMicAllow => 'Permitir Micrófono';

  @override
  String get onboardingReady => '¡Todo Listo!';

  @override
  String get onboardingReadyDesc =>
      'Inicia tu primera reunión y deja que Aura haga el resto.';

  @override
  String get onboardingGetStarted => 'Comenzar';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonError => 'Algo salió mal';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonCopied => 'Copiado al portapapeles';
}
