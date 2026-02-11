-- Migration: Transaction-safe profile acceptance
-- Purpose: Wraps profile approval operations in a single transaction
-- Date: 2025-02-11
-- REQUIRED: Run this in Supabase SQL Editor
-- Schema verified against schema_copy.txt

-- Drop function if exists (for re-running)
DROP FUNCTION IF EXISTS accept_profile_transaction(uuid, uuid, jsonb, text, text);

-- Create transaction-safe profile acceptance function
CREATE OR REPLACE FUNCTION accept_profile_transaction(
  p_profile_id uuid,
  p_approved_by uuid,
  p_role_records jsonb,  -- Array of {role_id, troop_context} objects
  p_generation text,
  p_comments text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_has_existing_approval boolean;
  v_role_record jsonb;
  v_roles_added int := 0;
  v_roles_removed int := 0;
  v_roles_unchanged int := 0;
  v_existing_role_id uuid;
BEGIN
  -- Start transaction (implicit in function, but explicit for clarity)
  
  -- 1. Check if approval record exists
  SELECT EXISTS(
    SELECT 1 FROM profiles_approvals WHERE profile_id = p_profile_id
  ) INTO v_has_existing_approval;
  
  -- 2. Upsert approval record
  -- Schema: id, profile_id, approved_by, comments, created_at, status
  -- NOTE: profiles_approvals does NOT have updated_at column
  IF v_has_existing_approval THEN
    UPDATE profiles_approvals
    SET 
      approved_by = p_approved_by,
      status = true,
      comments = p_comments
    WHERE profile_id = p_profile_id;
  ELSE
    INSERT INTO profiles_approvals (profile_id, approved_by, status, comments)
    VALUES (p_profile_id, p_approved_by, true, p_comments);
  END IF;
  
  -- 3. Update profile (approved + generation)
  -- Schema: profiles has updated_at, approved, generation columns
  UPDATE profiles
  SET 
    approved = true,
    generation = p_generation,
    updated_at = now()
  WHERE id = p_profile_id;
  
  -- Check if profile was found
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found: %', p_profile_id;
  END IF;
  
  -- 4. Smart role management: Remove roles not in new list
  WITH new_roles AS (
    SELECT (value->>'role_id')::uuid as role_id
    FROM jsonb_array_elements(p_role_records)
  )
  DELETE FROM profile_roles pr
  WHERE pr.profile_id = p_profile_id
    AND pr.role_id NOT IN (SELECT role_id FROM new_roles);
  
  GET DIAGNOSTICS v_roles_removed = ROW_COUNT;
  
  -- 5. Count unchanged roles (already exist)
  WITH new_roles AS (
    SELECT (value->>'role_id')::uuid as role_id
    FROM jsonb_array_elements(p_role_records)
  )
  SELECT COUNT(*)::int INTO v_roles_unchanged
  FROM profile_roles pr
  WHERE pr.profile_id = p_profile_id
    AND pr.role_id IN (SELECT role_id FROM new_roles);
  
  -- 6. Insert new roles
  -- Schema: profile_roles(id, profile_id, role_id, assigned_by, assigned_at, troop_context)
  -- Note: No unique constraint on (profile_id, role_id), so check manually
  FOR v_role_record IN SELECT * FROM jsonb_array_elements(p_role_records)
  LOOP
    -- Check if this combination already exists
    SELECT role_id INTO v_existing_role_id
    FROM profile_roles
    WHERE profile_id = p_profile_id 
      AND role_id = (v_role_record->>'role_id')::uuid
    LIMIT 1;
    
    -- Only insert if not exists
    IF v_existing_role_id IS NULL THEN
      INSERT INTO profile_roles (
        profile_id, 
        role_id, 
        assigned_by, 
        troop_context
        -- assigned_at has DEFAULT now() so we don't specify it
      )
      VALUES (
        p_profile_id,
        (v_role_record->>'role_id')::uuid,
        p_approved_by,
        CASE 
          WHEN v_role_record->>'troop_context' = 'null' THEN NULL
          ELSE (v_role_record->>'troop_context')::uuid
        END
      );
      
      v_roles_added := v_roles_added + 1;
    END IF;
    
    -- Reset for next iteration
    v_existing_role_id := NULL;
  END LOOP;
  
  -- 7. Return success with stats
  RETURN jsonb_build_object(
    'success', true,
    'profile_id', p_profile_id,
    'roles_added', v_roles_added,
    'roles_removed', v_roles_removed,
    'roles_unchanged', v_roles_unchanged
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Rollback happens automatically on exception
    RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Add comment for documentation
COMMENT ON FUNCTION accept_profile_transaction IS 
  'Transaction-safe profile acceptance. Performs approval, profile update, and role assignments atomically. Returns stats on roles added/removed/unchanged. Schema verified 2025-02-11.';

-- Verification: Check function was created
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_name = 'accept_profile_transaction';
