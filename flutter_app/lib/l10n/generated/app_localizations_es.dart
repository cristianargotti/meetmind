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
  String get loginWithGoogle => 'Continuar con Google';

  @override
  String get loginWithApple => 'Continuar con Apple';

  @override
  String get loginSkip => 'Continuar sin cuenta';

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
  String get accountTitle => 'Cuenta';

  @override
  String get accountSignOut => 'Cerrar Sesión';

  @override
  String get accountSignOutConfirm =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get accountDeleteAccount => 'Eliminar Cuenta';

  @override
  String get accountDeleteConfirmTitle => '¿Eliminar Cuenta?';

  @override
  String get accountDeleteConfirmBody =>
      'Esto eliminará permanentemente tu cuenta y todos tus datos de reuniones. Esta acción no se puede deshacer.';

  @override
  String get accountDeleteConfirmButton => 'Eliminar Todo';

  @override
  String get accountGuestUser => 'Usuario Invitado';

  @override
  String get accountLinkedAccounts => 'Cuentas Vinculadas';

  @override
  String get authCreateAccount => 'Crear Cuenta';

  @override
  String get authSignIn => 'Iniciar Sesión';

  @override
  String get authName => 'Nombre';

  @override
  String get authEmail => 'Correo Electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authToggleToRegister => '¿No tienes cuenta? Regístrate';

  @override
  String get authToggleToLogin => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authPasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get authFillFields => 'Ingresa correo y contraseña';

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
  String get paywallTitle => 'Desbloquea Aura Pro';

  @override
  String get paywallSubtitle => 'Tu copiloto de reuniones con IA, desatado';

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
  String get paywallLegal => 'Cancela cuando quieras. Facturación recurrente.';

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
  String get legalLastUpdated => 'Última actualización: Febrero 2026';

  @override
  String get privacyIntro => 'Tu Privacidad Importa';

  @override
  String get privacyIntroDesc =>
      'Aura Meet está diseñado con la privacidad como prioridad. Así manejamos tus datos:';

  @override
  String get privacyAudioTitle => '🎙️ Procesamiento de Audio';

  @override
  String get privacyAudioDesc =>
      '• El reconocimiento de voz se ejecuta EN TU DISPOSITIVO\n• Ningún audio se envía a nuestros servidores ni se almacena en la nube\n• Los datos de audio permanecen en tu dispositivo en todo momento';

  @override
  String get privacyDataTitle => '📝 Datos de Reuniones';

  @override
  String get privacyDataDesc =>
      '• Las transcripciones se envían a nuestros servidores solo para análisis con IA\n• Los datos se almacenan de forma segura con cifrado en reposo\n• Puedes eliminar cualquier reunión y sus datos en cualquier momento';

  @override
  String get privacySubsTitle => '💳 Suscripciones';

  @override
  String get privacySubsDesc =>
      '• Nunca vemos ni almacenamos tus datos de pago\n• Apple/Google maneja todo el procesamiento de pagos';

  @override
  String get privacyRightsTitle => '🔒 Tus Derechos';

  @override
  String get privacyRightsDesc =>
      '• Solicita la eliminación de todos tus datos en cualquier momento\n• Exporta todos los datos de tus reuniones\n• No vendemos tus datos a terceros\n• No usamos tus datos para publicidad';

  @override
  String get privacyContact =>
      'Para consultas de privacidad: privacy@aurameet.live';

  @override
  String get privacyDeleteAccount => 'Eliminar Mi Cuenta';

  @override
  String get privacyDeleteConfirm =>
      'Esto eliminará permanentemente tu cuenta y todos los datos asociados. Esta acción no se puede deshacer.';

  @override
  String get privacyDeleteButton => 'Eliminar Todo';

  @override
  String get termsIntro => 'Términos de Servicio';

  @override
  String get termsIntroDesc => 'Al usar Aura Meet, aceptas estos términos:';

  @override
  String get termsServiceTitle => '📱 Servicio';

  @override
  String get termsServiceDesc =>
      '• Aura Meet es un asistente de reuniones con IA\n• Proporcionamos transcripción, hallazgos y gestión de reuniones\n• La disponibilidad del servicio se ofrece con el mejor esfuerzo\n• Las funciones pueden cambiar a medida que mejoramos el producto';

  @override
  String get termsSubsTitle => '💰 Suscripciones';

  @override
  String get termsSubsDesc =>
      '• Plan gratuito: 3 reuniones/semana con funciones limitadas\n• Las suscripciones se renuevan automáticamente a menos que se cancelen\n• Cancela en cualquier momento a través de App Store o Google Play\n• Sin reembolsos por períodos parciales de facturación';

  @override
  String get termsUseTitle => '✅ Uso Aceptable';

  @override
  String get termsUseDesc =>
      '• Usa Aura Meet para asistencia legítima en reuniones\n• Cumple con todas las leyes aplicables de consentimiento de grabación\n• Eres responsable de obtener el consentimiento de los participantes';

  @override
  String get termsLiabilityTitle => '⚖️ Responsabilidad';

  @override
  String get termsLiabilityDesc =>
      '• Los hallazgos generados por IA pueden no ser 100% precisos\n• No somos responsables de decisiones tomadas basadas en análisis de IA\n• El servicio se proporciona \"tal cual\" sin garantías';

  @override
  String get termsContact => 'Para soporte: support@aurameet.live';

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

  @override
  String get paywallWelcome => '¡Bienvenido a Aura Pro!';

  @override
  String paywallSave(String amount) {
    return 'Ahorra $amount%';
  }

  @override
  String get paywallRestoring => 'Restaurando...';

  @override
  String get paywallSuccessRestore => '✅ Compras restauradas!';

  @override
  String get paywallNoRestore => 'No se encontraron compras previas';

  @override
  String get paywallFeatUnlimited => 'Ilimitadas';

  @override
  String get paywallFeatForever => 'Por siempre';

  @override
  String get paywallFeatAll => 'Todos';

  @override
  String get paywallFeatMeetings => 'Reuniones por semana';

  @override
  String get paywallFeatHistory => 'Historial de reuniones';

  @override
  String get paywallFeatInsights => 'Hallazgos por reunión';

  @override
  String get paywallFeatChat => 'Pregunta a Aura (Chat AI)';

  @override
  String get paywallFeatDigest => 'Resumen Semanal';

  @override
  String get paywallFeatExport => 'Exportar y compartir';

  @override
  String get paywallFeatBriefing => 'Briefing Pre-Reunión';
}
