enum SubscriptionTier {
  free,
  pro,
  admin
}

class Subscription {
  final String userId;
  final SubscriptionTier tier;
  final DateTime expiryDate;

  Subscription({
    required this.userId,
    required this.tier,
    required this.expiryDate,
  });
}
