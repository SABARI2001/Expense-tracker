-- Budgets table for category-wise spending limits
CREATE TABLE IF NOT EXISTS budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  category TEXT NOT NULL,
  monthly_limit DECIMAL(10,2) NOT NULL,
  current_spent DECIMAL(10,2) DEFAULT 0,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  alert_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, category, month, year)
);

ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own budgets"
  ON budgets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own budgets"
  ON budgets FOR ALL
  USING (auth.uid() = user_id);

-- Merchant rules for AI learning
CREATE TABLE IF NOT EXISTS merchant_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  merchant_pattern TEXT NOT NULL,
  category TEXT NOT NULL,
  confidence DECIMAL(3,2) DEFAULT 1.0,
  times_used INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE merchant_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own rules"
  ON merchant_rules FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own rules"
  ON merchant_rules FOR ALL
  USING (auth.uid() = user_id);

-- Notification queue
CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, -- 'budget_alert', 'categorization_needed', 'insight_ready'
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON notification_queue FOR SELECT
  USING (auth.uid() = user_id);

-- Update subscriptions table for premium tiers
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{"insights": false, "budgets": false, "export": false}'::jsonb;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS billing_cycle TEXT DEFAULT 'monthly';
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS next_billing_date TIMESTAMPTZ;

-- Function to update budget spent amount
CREATE OR REPLACE FUNCTION update_budget_spent()
RETURNS TRIGGER AS $$
BEGIN
  -- Update current month's budget
  UPDATE budgets
  SET current_spent = (
    SELECT COALESCE(SUM(amount), 0)
    FROM expenses
    WHERE user_id = NEW.user_id
      AND category = NEW.category
      AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
      AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
  )
  WHERE user_id = NEW.user_id
    AND category = NEW.category
    AND month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
    AND year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
  
  -- Check if budget exceeded and alert not sent
  INSERT INTO notification_queue (user_id, type, title, body, data)
  SELECT 
    b.user_id,
    'budget_alert',
    'Budget Alert: ' || b.category,
    'You have exceeded your ' || b.category || ' budget of $' || b.monthly_limit,
    jsonb_build_object('category', b.category, 'limit', b.monthly_limit, 'spent', b.current_spent)
  FROM budgets b
  WHERE b.user_id = NEW.user_id
    AND b.category = NEW.category
    AND b.month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
    AND b.year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
    AND b.current_spent > b.monthly_limit
    AND b.alert_sent = FALSE;
  
  -- Mark alert as sent
  UPDATE budgets
  SET alert_sent = TRUE
  WHERE user_id = NEW.user_id
    AND category = NEW.category
    AND month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
    AND year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
    AND current_spent > monthly_limit
    AND alert_sent = FALSE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update budgets on expense insert/update
CREATE TRIGGER update_budget_on_expense
  AFTER INSERT OR UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_budget_spent();

-- Indexes for performance
CREATE INDEX idx_budgets_user_month ON budgets(user_id, month, year);
CREATE INDEX idx_merchant_rules_user ON merchant_rules(user_id);
CREATE INDEX idx_notification_queue_user_sent ON notification_queue(user_id, sent);
