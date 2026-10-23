/// Preserve the native deep link; use the current hosted origin for web auth.
String authRedirect({required bool isWeb, required Uri base}) => isWeb
    ? '${base.origin}/'
    : 'io.supabase.flutterquickstart://login-callback/';
