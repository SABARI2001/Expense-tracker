import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Request notification permission
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Notification permission denied');
      return;
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    print('Notification service initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to specific screen based on payload
  }

  /// Send a general notification
  Future<void> sendNotification(String title, String body, {String? payload}) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Send budget alert notification
  Future<void> sendBudgetAlert(String category, double spent, double limit) async {
    final percentage = (spent / limit * 100).toStringAsFixed(0);
    await sendNotification(
      '⚠️ Budget Alert: $category',
      'You\'ve spent ₹$spent of ₹$limit ($percentage%)',
      payload: 'budget_alert:$category',
    );
  }

  /// Send expense detected notification
  Future<void> sendExpenseDetected(String merchant, double amount) async {
    await sendNotification(
      '💳 Expense Detected',
      'Transaction of ₹$amount at $merchant',
      payload: 'expense_detected:$merchant',
    );
  }

  /// Send daily summary notification
  Future<void> sendDailySummary(double totalSpent, int transactionCount) async {
    await sendNotification(
      '📊 Daily Summary',
      'Today: $transactionCount transactions, ₹$totalSpent spent',
      payload: 'daily_summary',
    );
  }

  /// Test notification
  static Future<void> testAlert() async {
    final service = NotificationService();
    await service.initialize();
    await service.sendNotification(
      'Test Alert',
      'Testing budget alert notification system',
    );
    print("Testing budget alert...");
  }
}
