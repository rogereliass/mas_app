# Row-Level Security (RLS) Setup Guide for MAS App

## Overview
This guide provides SQL commands to set up Row-Level Security (RLS) policies in Supabase to enforce role-based file visibility at the database level, complementing the client-side filtering in the Flutter app.

## Prerequisites
- Supabase project with the following tables:
  - `profiles` (user profiles)
  - `profiles_roles` (user-role junction table)
  - `roles` (role definitions with rank field)
  - `folders` (library folders)
  - `files` (library files with min_role_rank field)

---

## Step 1: Enable RLS on Tables

First, enable RLS on all relevant tables:

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE files ENABLE ROW LEVEL SECURITY;
```

---

## Step 2: Create Helper Function for User Role Rank

Create a reusable function to get the current user's highest role rank:

```sql
-- Function to get current user's highest role rank
-- (Users can have multiple roles, returns the highest role_rank)
CREATE OR REPLACE FUNCTION get_user_role_rank()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_rank INTEGER;
BEGIN
  -- Get the user's highest role rank from profiles -> profiles_roles -> roles
  SELECT COALESCE(MAX(r.role_rank), 0)
  INTO user_rank
  FROM profiles p
  INNER JOIN profiles_roles pr ON p.id = pr.profile_id
  INNER JOIN roles r ON pr.role_id = r.id
  WHERE p.user_id = auth.uid();
  
  -- Return 0 (public) if no role found or user not authenticated
  RETURN COALESCE(user_rank, 0);
END;
$$;
```

---

## Step 3: RLS Policies for `files` Table

### Policy 1: Public Files (min_role_rank = 0)
Allow everyone (including unauthenticated users) to view public files:

```sql
CREATE POLICY "Public files are viewable by everyone"
ON files
FOR SELECT
USING (min_role_rank = 0);
```

### Policy 2: Authenticated Users with Sufficient Rank
Allow authenticated users to view files where their role rank >= file's min_role_rank:

```sql
CREATE POLICY "Authenticated users can view files based on role rank"
ON files
FOR SELECT
TO authenticated
USING (
  get_user_role_rank() >= min_role_rank
);
```

### Policy 3: Admin Full Access (Optional)
Give system admins (rank 100) full CRUD access:

```sql
CREATE POLICY "System admins have full access to files"
ON files
FOR ALL
TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);
```

---

## Step 4: RLS Policies for `folders` Table

Folders can be simpler - usually visible to all or based on content:

```sql
-- Option 1: All folders visible to everyone
CREATE POLICY "Folders are viewable by everyone"
ON folders
FOR SELECT
USING (true);

-- Option 2: If folders have min_role_rank too
-- CREATE POLICY "Folders viewable based on role rank"
-- ON folders
-- FOR SELECT
-- USING (
--   min_role_rank = 0 OR
--   (auth.uid() IS NOT NULL AND get_user_role_rank() >= min_role_rank)
-- );
```

---

## Step 5: RLS Policies for `profiles` Table

```sql
-- Users can view their own profile
CREATE POLICY "Users can view their own profile"
ON profiles
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON profiles
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
ON profiles
FOR SELECT
TO authenticated
USING (get_user_role_rank() >= 80);
```

---

## Step 6: RLS Policies for `profiles_roles` Table

```sql
-- Users can view their own role assignments
CREATE POLICY "Users can view their own roles"
ON profiles_roles
FOR SELECT
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM profiles WHERE user_id = auth.uid()
  )
);

-- Admins can view all role assignments
CREATE POLICY "Admins can view all role assignments"
ON profiles_roles
FOR SELECT
TO authenticated
USING (get_user_role_rank() >= 80);

-- System admins can manage role assignments
CREATE POLICY "System admins can manage role assignments"
ON profiles_roles
FOR ALL
TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);
```

---

## Step 7: RLS Policies for `roles` Table

```sql
-- Everyone can view available roles (for UI dropdowns, etc.)
CREATE POLICY "Roles are viewable by everyone"
ON roles
FOR SELECT
USING (true);

-- Only system admins can modify roles
CREATE POLICY "System admins can manage roles"
ON roles
FOR ALL
TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);
```

---

## Step 8: Test the Policies

### Test with SQL Editor (as authenticated user):

```sql
-- Test 1: Check your current role rank
SELECT get_user_role_rank();

-- Test 2: View files you should have access to
SELECT id, title, min_role_rank
FROM files
WHERE min_role_rank <= get_user_role_rank()
ORDER BY created_at DESC;

-- Test 3: Verify RLS is working (should only return accessible files)
SELECT id, title, min_role_rank
FROM files
ORDER BY created_at DESC;
```

### Test from Flutter App:

```dart
// The existing code should work seamlessly
final response = await supabase
  .from('files')
  .select()
  .eq('folder_id', folderId);

// RLS will automatically filter results based on user's role rank
```

---

## Step 9: Performance Optimization

Add indexes to improve query performance:

```sql
-- Index on min_role_rank for faster filtering
CREATE INDEX IF NOT EXISTS idx_files_min_role_rank 
ON files(min_role_rank);

-- Index on profiles_roles for faster role lookups
CREATE INDEX IF NOT EXISTS idx_profiles_roles_profile_id 
ON profiles_roles(profile_id);

CREATE INDEX IF NOT EXISTS idx_profiles_roles_role_id 
ON profiles_roles(role_id);

-- Index on profiles.user_id for auth lookups
CREATE INDEX IF NOT EXISTS idx_profiles_user_id 
ON profiles(user_id);

-- Index on roles.role_rank
CREATE INDEX IF NOT EXISTS idx_roles_role_rank 
ON roles(role_rank);
```

---

## Step 10: Verify Everything is Working

Run this comprehensive check:

```sql
-- Check RLS is enabled
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('files', 'folders', 'profiles', 'profiles_roles', 'roles');

-- Check policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Test the helper function
SELECT get_user_role_rank() as my_rank;
```

---

## Common Issues & Solutions

### Issue 1: Function returns NULL
**Cause:** User has no role assigned in `profiles_roles` table
**Solution:** Assign a default role or ensure COALESCE returns 0

### Issue 2: No files visible even for public content
**Cause:** RLS enabled but no SELECT policy for public access
**Solution:** Verify the "Public files are viewable by everyone" policy exists

### Issue 3: Performance slow with many users
**Cause:** Missing indexes on join tables
**Solution:** Add indexes as shown in Step 9

### Issue 4: Admin can't see all files
**Cause:** Admin role rank not properly set
**Solution:** Verify admin role has rank = 100 in `roles` table

---

## Role Rank Reference

| Rank | Role Level | Typical Use Case |
|------|------------|------------------|
| 0 | Public/Unauthenticated | Public content available to all |
| 1-49 | Basic Members | General authenticated users |
| 50-79 | Privileged Members | Leaders, senior members |
| 80-99 | Administrators | Content managers, moderators |
| 100 | System Admin | Full system access |

---

## Security Best Practices

1. **Always use RLS with authenticated users** - Never trust client-side filtering alone
2. **Test policies thoroughly** - Use SQL Editor to verify policy behavior
3. **Use SECURITY DEFINER carefully** - Only for trusted helper functions
4. **Monitor query performance** - Add indexes for large tables
5. **Audit policy changes** - Keep track of who can access what
6. **Set default roles** - Ensure new users get appropriate default access

---

## Quick Deploy Script

Run this complete script in your Supabase SQL Editor:

```sql
-- 1. Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE files ENABLE ROW LEVEL SECURITY;

-- 2. Create helper function (returns highest role_rank for users with multiple roles)
CREATE OR REPLACE FUNCTION get_user_role_rank()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_rank INTEGER;
BEGIN
  SELECT COALESCE(MAX(r.role_rank), 0)
  INTO user_rank
  FROM profiles p
  INNER JOIN profiles_roles pr ON p.id = pr.profile_id
  INNER JOIN roles r ON pr.role_id = r.id
  WHERE p.user_id = auth.uid();
  
  RETURN COALESCE(user_rank, 0);
END;
$$;

-- 2a. Verify function was created successfully
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_user_role_rank'
  ) THEN
    RAISE EXCEPTION 'Function get_user_role_rank() was not created successfully';
  END IF;
  RAISE NOTICE 'Function get_user_role_rank() created successfully';
END;
$$;

-- 3. Files policies
CREATE POLICY "Public files are viewable by everyone"
ON files FOR SELECT
USING (min_role_rank = 0);

CREATE POLICY "Authenticated users can view files based on role rank"
ON files FOR SELECT TO authenticated
USING (get_user_role_rank() >= min_role_rank);

CREATE POLICY "System admins have full access to files"
ON files FOR ALL TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);

-- 4. Folders policies
CREATE POLICY "Folders are viewable by everyone"
ON folders FOR SELECT
USING (true);

-- 5. Profiles policies
CREATE POLICY "Users can view their own profile"
ON profiles FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can update their own profile"
ON profiles FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view all profiles"
ON profiles FOR SELECT TO authenticated
USING (get_user_role_rank() >= 80);

-- 6. Profiles_roles policies
CREATE POLICY "Users can view their own roles"
ON profiles_roles FOR SELECT TO authenticated
USING (
  profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
);

CREATE POLICY "Admins can view all role assignments"
ON profiles_roles FOR SELECT TO authenticated
USING (get_user_role_rank() >= 80);

CREATE POLICY "System admins can manage role assignments"
ON profiles_roles FOR ALL TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);

-- 7. Roles policies
CREATE POLICY "Roles are viewable by everyone"
ON roles FOR SELECT
USING (true);

CREATE POLICY "System admins can manage roles"
ON roles FOR ALL TO authenticated
USING (get_user_role_rank() = 100)
WITH CHECK (get_user_role_rank() = 100);

-- 8. Create indexes
CREATE INDEX IF NOT EXISTS idx_files_min_role_rank ON files(min_role_rank);
CREATE INDEX IF NOT EXISTS idx_profiles_roles_profile_id ON profiles_roles(profile_id);
CREATE INDEX IF NOT EXISTS idx_profiles_roles_role_id ON profiles_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_roles_role_rank ON roles(role_rank);

-- 9. Verify
SELECT 'RLS Setup Complete!' as status;
```

---

## Next Steps

1. ✅ Run the Quick Deploy Script in Supabase SQL Editor
2. ✅ Test with different user roles (rank 0, 50, 80, 100)
3. ✅ Verify client-side filtering still works (defense in depth)
4. ✅ Monitor query performance in Supabase dashboard
5. ✅ Document role assignments for your team

**Your app now has both client-side AND server-side role-based access control! 🔒**
