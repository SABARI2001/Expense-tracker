-- 1️⃣ DATABASE (LOCKED, WITH ADMIN SUPPORT)
create table if not exists subscriptions (
  user_id uuid primary key references auth.users(id),
  role text default 'user', -- user | admin
  is_premium boolean default false,
  valid_until timestamp
);

-- Admin row (Example - UPDATE WITH YOUR UUID)
-- update subscriptions
-- set role = 'admin', is_premium = true
-- where user_id = 'YOUR_AUTH_UID';

-- 2️⃣ ROW-LEVEL SECURITY (NON-NEGOTIABLE)
-- Enable RLS
alter table expenses enable row level security;
alter table subscriptions enable row level security;

-- Expenses Policies
create policy "own expenses"
on expenses
for all
using (auth.uid() = user_id);

-- Subscriptions Policies
create policy "own subscription"
on subscriptions
for select
using (auth.uid() = user_id);
