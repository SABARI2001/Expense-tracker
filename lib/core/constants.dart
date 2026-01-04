class AppConstants {
  static const String supabaseUrl = 'https://cwxlyvdabeuwtkgnklxt.supabase.co';
  static const String supabaseAnonKey = 'sb_anon_yuLjS36JI032i8A1H3rehg_ACE-DqLA';
  
  // OpenAI Configuration
  // NOTE: For security, the API key should be stored in environment variables or secure storage
  // For Edge Functions, set via: supabase secrets set OPENAI_API_KEY=your_key
  // For local development, you can temporarily add it here (but DO NOT commit to git)
  static const String openAiApiKey = ''; // Leave empty - set via environment or secure storage
  
  // Notification Configuration
  static const String notificationChannelId = 'expense_tracker_notifications';
  static const String notificationChannelName = 'Expense Tracker';
  static const String notificationChannelDescription = 'Notifications for expense tracking and budgets';
}
