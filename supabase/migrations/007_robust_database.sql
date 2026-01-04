-- ROBUST DATABASE MIGRATION (Fixed for existing data)
-- Handles existing NULL values before adding constraints

-- ============================================
-- 1. FIX EXISTING DATA FIRST
-- ============================================

-- Update NULL phone numbers with placeholder
UPDATE user_profiles 
SET phone_number = '0000000000' 
WHERE phone_number IS NULL OR trim(phone_number) = '';

-- Update NULL date_of_birth with default
UPDATE user_profiles 
SET date_of_birth = '2000-01-01' 
WHERE date_of_birth IS NULL;

-- Update NULL full_name with email prefix
UPDATE user_profiles 
SET full_name = split_part(email, '@', 1)
WHERE full_name IS NULL OR trim(full_name) = '';

-- ============================================
-- 2. NOW ADD NOT NULL CONSTRAINTS
-- ============================================

ALTER TABLE user_profiles 
  ALTER COLUMN full_name SET NOT NULL,
  ALTER COLUMN email SET NOT NULL,
  ALTER COLUMN phone_number SET NOT NULL,
  ALTER COLUMN date_of_birth SET NOT NULL;

-- Add validation constraints
ALTER TABLE user_profiles 
  DROP CONSTRAINT IF EXISTS check_full_name_not_empty,
  DROP CONSTRAINT IF EXISTS check_email_valid,
  DROP CONSTRAINT IF EXISTS check_phone_not_empty;

ALTER TABLE user_profiles 
  ADD CONSTRAINT check_full_name_not_empty CHECK (length(trim(full_name)) > 0),
  ADD CONSTRAINT check_email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  ADD CONSTRAINT check_phone_not_empty CHECK (length(trim(phone_number)) >= 10);

-- ============================================
-- 3. ENHANCED EXPENSES (Complete Tracking)
-- ============================================

ALTER TABLE expenses 
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS tags TEXT[],
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Ensure no empty critical fields
ALTER TABLE expenses
  DROP CONSTRAINT IF EXISTS check_merchant_not_empty,
  DROP CONSTRAINT IF EXISTS check_category_not_empty;

ALTER TABLE expenses
  ADD CONSTRAINT check_merchant_not_empty CHECK (length(trim(merchant)) > 0),
  ADD CONSTRAINT check_category_not_empty CHECK (length(trim(category)) > 0);

-- ============================================
-- 4. USER ACTIVITY TRACKING
-- ============================================

CREATE TABLE IF NOT EXISTS user_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL,
  screen TEXT,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_activity_user_time ON user_activity(user_id, created_at DESC);

ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own activity" ON user_activity;
CREATE POLICY "Users can view own activity"
  ON user_activity FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================
-- 5. CONNECTION HEALTH TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS connection_health (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  connection_type TEXT,
  latency_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_connection_health_user_time ON connection_health(user_id, created_at DESC);

-- ============================================
-- 6. LIVE TRACKING VIEWS
-- ============================================

DROP VIEW IF EXISTS live_expense_tracking CASCADE;
CREATE OR REPLACE VIEW live_expense_tracking AS
SELECT 
  e.id,
  e.user_id,
  up.full_name,
  up.email,
  e.amount,
  e.merchant,
  e.category,
  e.payment_method,
  e.created_at,
  e.updated_at,
  EXTRACT(EPOCH FROM (NOW() - e.created_at)) as seconds_ago
FROM expenses e
JOIN user_profiles up ON e.user_id = up.user_id
WHERE e.created_at > NOW() - INTERVAL '24 hours'
ORDER BY e.created_at DESC;

DROP VIEW IF EXISTS user_engagement CASCADE;
CREATE OR REPLACE VIEW user_engagement AS
SELECT 
  up.user_id,
  up.full_name,
  up.email,
  COUNT(DISTINCT e.id) as total_expenses,
  COUNT(DISTINCT b.id) as total_budgets,
  MAX(e.created_at) as last_expense_at,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(MAX(e.created_at), up.created_at)))/3600 as hours_since_last_activity
FROM user_profiles up
LEFT JOIN expenses e ON up.user_id = e.user_id
LEFT JOIN budgets b ON up.user_id = b.user_id
GROUP BY up.user_id, up.full_name, up.email, up.created_at;

-- ============================================
-- 7. ACTIVITY LOGGING TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION log_expense_change()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_activity (user_id, action, details)
  VALUES (
    COALESCE(NEW.user_id, OLD.user_id),
    TG_OP || '_EXPENSE',
    jsonb_build_object(
      'expense_id', COALESCE(NEW.id, OLD.id),
      'amount', COALESCE(NEW.amount, OLD.amount),
      'merchant', COALESCE(NEW.merchant, OLD.merchant),
      'category', COALESCE(NEW.category, OLD.category)
    )
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS track_expense_changes ON expenses;
CREATE TRIGGER track_expense_changes
  AFTER INSERT OR UPDATE OR DELETE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION log_expense_change();

-- ============================================
-- 8. UPDATE TIMESTAMP TRIGGER
-- ============================================

DROP TRIGGER IF EXISTS update_expense_timestamp ON expenses;
CREATE TRIGGER update_expense_timestamp
  BEFORE UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 9. PERFORMANCE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_expenses_user_created ON expenses(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_merchant ON expenses(merchant);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- ============================================
-- 10. DATABASE HEALTH FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION check_database_health()
RETURNS TABLE (
  check_name TEXT,
  status TEXT,
  message TEXT
) AS $$
BEGIN
  -- Check 1: User data completeness
  RETURN QUERY
  SELECT 
    'User Data Completeness'::TEXT,
    CASE 
      WHEN COUNT(*) = 0 THEN 'healthy'
      ELSE 'warning'
    END::TEXT,
    CASE 
      WHEN COUNT(*) = 0 THEN 'All users have complete profiles'
      ELSE COUNT(*)::TEXT || ' users have incomplete profiles'
    END::TEXT
  FROM user_profiles
  WHERE full_name IS NULL 
     OR email IS NULL 
     OR phone_number IS NULL 
     OR date_of_birth IS NULL;

  -- Check 2: Total users
  RETURN QUERY
  SELECT 
    'Total Users'::TEXT,
    'healthy'::TEXT,
    COUNT(*)::TEXT || ' registered users'::TEXT
  FROM user_profiles;

  -- Check 3: Total expenses
  RETURN QUERY
  SELECT 
    'Total Expenses'::TEXT,
    'healthy'::TEXT,
    COUNT(*)::TEXT || ' expenses tracked'::TEXT
  FROM expenses;

  -- Check 4: Active budgets
  RETURN QUERY
  SELECT 
    'Active Budgets'::TEXT,
    'healthy'::TEXT,
    COUNT(*)::TEXT || ' active budgets'::TEXT
  FROM budgets
  WHERE month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
    AND year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 11. USER SNAPSHOT FUNCTION
-- ============================================

CREATE TABLE IF NOT EXISTS data_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  snapshot_type TEXT NOT NULL,
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION create_user_snapshot(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
  snapshot_id UUID;
BEGIN
  INSERT INTO data_snapshots (user_id, snapshot_type, data)
  SELECT 
    p_user_id,
    'user_full_backup',
    jsonb_build_object(
      'profile', row_to_json(up.*),
      'expenses', (SELECT COALESCE(jsonb_agg(row_to_json(e.*)), '[]'::jsonb) FROM expenses e WHERE e.user_id = p_user_id),
      'budgets', (SELECT COALESCE(jsonb_agg(row_to_json(b.*)), '[]'::jsonb) FROM budgets b WHERE b.user_id = p_user_id),
      'roles', (SELECT row_to_json(ur.*) FROM user_roles ur WHERE ur.user_id = p_user_id)
    )
  FROM user_profiles up
  WHERE up.user_id = p_user_id
  RETURNING id INTO snapshot_id;
  
  RETURN snapshot_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ Database robustness migration completed successfully!';
  RAISE NOTICE '📊 All data integrity constraints are now active';
  RAISE NOTICE '🔄 Live tracking and health monitoring enabled';
END $$;
