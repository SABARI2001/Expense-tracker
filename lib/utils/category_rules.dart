class CategoryRules {
  /// Categorize expense based on description using rule-based matching
  static String categorize(String description) {
    final desc = description.toLowerCase();

    // Food & Dining
    if (_matchesAny(desc, [
      'restaurant', 'cafe', 'coffee', 'starbucks', 'mcdonald', 'kfc', 'domino',
      'pizza', 'burger', 'food', 'zomato', 'swiggy', 'ubereats', 'dining',
      'breakfast', 'lunch', 'dinner', 'snack', 'bakery', 'bar', 'pub'
    ])) {
      return 'Food & Dining';
    }

    // Groceries
    if (_matchesAny(desc, [
      'grocery', 'supermarket', 'walmart', 'target', 'costco', 'bigbasket',
      'grofers', 'blinkit', 'dunzo', 'fresh', 'vegetables', 'fruits', 'milk',
      'dmart', 'reliance', 'more', 'spencer'
    ])) {
      return 'Groceries';
    }

    // Transportation
    if (_matchesAny(desc, [
      'uber', 'lyft', 'ola', 'rapido', 'taxi', 'cab', 'metro', 'bus', 'train',
      'fuel', 'petrol', 'diesel', 'gas', 'parking', 'toll', 'transport'
    ])) {
      return 'Transportation';
    }

    // Shopping
    if (_matchesAny(desc, [
      'amazon', 'flipkart', 'myntra', 'ajio', 'shopping', 'mall', 'store',
      'retail', 'clothing', 'fashion', 'shoes', 'electronics', 'gadget',
      'nike', 'adidas', 'zara', 'h&m'
    ])) {
      return 'Shopping';
    }

    // Entertainment
    if (_matchesAny(desc, [
      'netflix', 'prime', 'hotstar', 'spotify', 'youtube', 'movie', 'cinema',
      'theatre', 'pvr', 'inox', 'game', 'gaming', 'steam', 'playstation',
      'xbox', 'concert', 'event', 'ticket'
    ])) {
      return 'Entertainment';
    }

    // Healthcare
    if (_matchesAny(desc, [
      'hospital', 'clinic', 'doctor', 'medical', 'pharmacy', 'medicine',
      'health', 'apollo', 'fortis', 'max', 'dental', 'lab', 'diagnostic',
      'pharma', 'drug'
    ])) {
      return 'Healthcare';
    }

    // Utilities
    if (_matchesAny(desc, [
      'electricity', 'water', 'gas', 'internet', 'broadband', 'wifi',
      'mobile', 'phone', 'recharge', 'bill', 'utility', 'airtel', 'jio',
      'vodafone', 'bsnl'
    ])) {
      return 'Utilities';
    }

    // Education
    if (_matchesAny(desc, [
      'school', 'college', 'university', 'course', 'tuition', 'education',
      'book', 'library', 'udemy', 'coursera', 'learning', 'training',
      'academy', 'institute'
    ])) {
      return 'Education';
    }

    // Travel
    if (_matchesAny(desc, [
      'flight', 'hotel', 'airbnb', 'booking', 'makemytrip', 'goibibo',
      'cleartrip', 'travel', 'vacation', 'trip', 'airline', 'indigo',
      'spicejet', 'air india', 'resort'
    ])) {
      return 'Travel';
    }

    // Insurance
    if (_matchesAny(desc, [
      'insurance', 'premium', 'policy', 'lic', 'hdfc life', 'icici prudential',
      'max life', 'sbi life'
    ])) {
      return 'Insurance';
    }

    // Investment
    if (_matchesAny(desc, [
      'mutual fund', 'sip', 'stock', 'share', 'investment', 'zerodha',
      'groww', 'upstox', 'trading', 'demat', 'equity', 'bond'
    ])) {
      return 'Investment';
    }

    // Rent
    if (_matchesAny(desc, [
      'rent', 'lease', 'housing', 'apartment', 'flat', 'maintenance'
    ])) {
      return 'Rent';
    }

    // Personal Care
    if (_matchesAny(desc, [
      'salon', 'spa', 'gym', 'fitness', 'yoga', 'beauty', 'cosmetic',
      'haircut', 'massage', 'wellness'
    ])) {
      return 'Personal Care';
    }

    // Default category
    return 'Uncategorized';
  }

  /// Check if description matches any of the keywords
  static bool _matchesAny(String description, List<String> keywords) {
    return keywords.any((keyword) => description.contains(keyword));
  }

  /// Get confidence score for categorization (0.0 to 1.0)
  static double getConfidence(String description, String category) {
    final desc = description.toLowerCase();
    
    // Count matching keywords for the category
    int matches = 0;
    int totalKeywords = 0;

    // This is a simplified confidence calculation
    // In production, you might want more sophisticated scoring
    if (categorize(description) == category) {
      return 0.85; // High confidence for rule-based match
    }
    
    return 0.0; // No confidence if category doesn't match
  }
}
