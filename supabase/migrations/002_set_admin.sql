-- Set admin role for your email
-- Run this AFTER you've created your account

INSERT INTO user_roles (user_id, role)
SELECT id, 'admin'
FROM auth.users
WHERE email = 'sabarinathankarruppusamy2001@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET role = 'admin';

-- Optionally set premium subscription
INSERT INTO subscriptions (user_id, tier, expires_at)
SELECT id, 'premium', '2099-12-31'::timestamptz
FROM auth.users
WHERE email = 'sabarinathankarruppusamy2001@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET tier = 'premium', expires_at = '2099-12-31'::timestamptz;
