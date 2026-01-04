# Database Troubleshooting Guide

## Problem: No Data in Tables After Registration

### Root Cause
The trigger `handle_new_user()` may not be firing correctly, or tables weren't created in the right order.

### Solution: Run Migrations in Correct Order

**Go to Supabase Dashboard → SQL Editor**

#### Step 1: Check Current State
```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_profiles', 'user_roles', 'expenses', 'budgets');

-- Check existing users
SELECT id, email FROM auth.users;

-- Check user_profiles
SELECT * FROM user_profiles;

-- Check user_roles
SELECT * FROM user_roles;
```

#### Step 2: Run ALL Migrations in Order

**IMPORTANT: Run these ONE AT A TIME, in this exact order:**

1. **001_production_schema.sql** - Creates expenses, user_roles tables
2. **003_user_profiles.sql** - Creates user_profiles table and trigger
3. **004_security_hardening.sql** - Adds audit logging
4. **005_advanced_features.sql** - Adds budgets, merchant_rules
5. **006_fix_user_trigger.sql** - ⭐ **NEW! Fixes the trigger**

#### Step 3: Verify Trigger Exists
```sql
-- Check if trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- Should return: on_auth_user_created | INSERT | users
```

#### Step 4: Test Registration

**Option A: Create New Test Account**
1. Logout from app
2. Sign up with new email: `test@example.com`
3. Fill all fields
4. Check Supabase:
```sql
SELECT * FROM user_profiles WHERE email = 'test@example.com';
SELECT * FROM user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = 'test@example.com');
```

**Option B: Fix Existing Account**
If you already registered but data is missing:
```sql
-- Get your user ID
SELECT id, email FROM auth.users WHERE email = 'your-email@example.com';

-- Manually insert profile (replace USER_ID with actual ID)
INSERT INTO user_profiles (user_id, email, full_name, phone_number, date_of_birth)
VALUES (
  'USER_ID_HERE',
  'your-email@example.com',
  'Your Name',
  '1234567890',
  '2000-01-01'
)
ON CONFLICT (user_id) DO NOTHING;

-- Manually insert role
INSERT INTO user_roles (user_id, role)
VALUES ('USER_ID_HERE', 'user')
ON CONFLICT (user_id) DO NOTHING;
```

---

## Common Issues

### Issue 1: "Trigger doesn't exist"
**Solution:** Run migration 006_fix_user_trigger.sql

### Issue 2: "Tables don't exist"
**Solution:** Run migrations 001, 003, 004, 005 in order

### Issue 3: "User exists but no profile"
**Solution:** Use Option B above to manually insert

### Issue 4: "Cannot insert into table"
**Cause:** RLS policies blocking insert
**Solution:** The trigger uses SECURITY DEFINER to bypass RLS

---

## Verification Checklist

After running all migrations, verify:

✅ **Tables Exist:**
```sql
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('expenses', 'user_profiles', 'user_roles', 'budgets', 'merchant_rules', 'audit_log');
-- Should return: 6
```

✅ **Trigger Exists:**
```sql
SELECT COUNT(*) FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
-- Should return: 1
```

✅ **RLS Enabled:**
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('expenses', 'user_profiles', 'user_roles', 'budgets');
-- All should show: true
```

✅ **Test Registration:**
1. Create new account
2. Check user_profiles has entry
3. Check user_roles has entry
4. Login and see profile data

---

## Quick Fix Script

Run this if you have existing users with missing data:

```sql
-- Populate missing user_roles
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'user'
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.user_roles);

-- Populate missing user_profiles
INSERT INTO public.user_profiles (user_id, email, full_name)
SELECT 
  id, 
  email,
  COALESCE(raw_user_meta_data->>'full_name', split_part(email, '@', 1))
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.user_profiles);

-- Verify
SELECT 
  u.email,
  up.full_name,
  ur.role
FROM auth.users u
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN user_roles ur ON u.id = ur.user_id;
```

---

## Expected Result

After successful setup, when you register:

1. ✅ Entry in `auth.users` (Supabase Auth)
2. ✅ Entry in `user_profiles` (your profile data)
3. ✅ Entry in `user_roles` (role = 'user')
4. ✅ Can login and see profile in app
5. ✅ Can add expenses
6. ✅ Can create budgets

If ANY of these fail, the trigger isn't working correctly.
