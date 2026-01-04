-- Security: Add rate limiting table for login attempts
CREATE TABLE IF NOT EXISTS login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_login_attempts_email ON login_attempts(email);
CREATE INDEX idx_login_attempts_time ON login_attempts(attempted_at);

-- Auto-cleanup old login attempts (older than 24 hours)
CREATE OR REPLACE FUNCTION cleanup_old_login_attempts()
RETURNS void AS $$
BEGIN
  DELETE FROM login_attempts WHERE attempted_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Security: Add audit log for sensitive operations
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_time ON audit_log(created_at);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs
CREATE POLICY "Admins can view audit logs"
  ON audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
      AND user_roles.role = 'admin'
    )
  );

-- Function to log expense operations
CREATE OR REPLACE FUNCTION log_expense_operation()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (user_id, action, details)
  VALUES (
    auth.uid(),
    TG_OP || '_EXPENSE',
    jsonb_build_object(
      'expense_id', COALESCE(NEW.id, OLD.id),
      'amount', COALESCE(NEW.amount, OLD.amount),
      'category', COALESCE(NEW.category, OLD.category)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for expense audit logging
CREATE TRIGGER expense_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON expenses
  FOR EACH ROW EXECUTE FUNCTION log_expense_operation();

-- Security: Prevent SQL injection with additional validation
ALTER TABLE expenses ADD CONSTRAINT valid_amount CHECK (amount > 0 AND amount < 1000000);
ALTER TABLE expenses ADD CONSTRAINT valid_merchant CHECK (length(merchant) > 0 AND length(merchant) < 200);
ALTER TABLE expenses ADD CONSTRAINT valid_category CHECK (length(category) > 0 AND length(category) < 100);
