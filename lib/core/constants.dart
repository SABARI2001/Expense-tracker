class AppConstants {
  static const String supabaseUrl = 'https://cwxlyvdabeuwtkgnklxt.supabase.co';
  static const String supabaseAnonKey = 'sb_anon_yuLjS36JI032i8A1H3rehg_ACE-DqLA';
  
  // OpenAI Configuration
  // For local development: Create lib/core/secrets.dart with your API key
  // For production: API key is set in Supabase Edge Functions via environment variables
  static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  
  // Notification Configuration
  static const String notificationChannelId = 'expense_tracker_notifications';
  static const String notificationChannelName = 'Expense Tracker';
  static const String notificationChannelDescription = 'Notifications for expense tracking and budgets';
}
