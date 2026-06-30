-- Add role column to profiles table for role-based permissions
-- Roles: 'customer' (default), 'staff', 'admin'

ALTER TABLE profiles ADD COLUMN role TEXT DEFAULT 'customer';

-- Add index for faster role lookups
CREATE INDEX idx_profiles_role ON profiles(role);

-- Add comment for documentation
COMMENT ON COLUMN profiles.role IS 'User role: customer, staff, admin';

-- Update RLS policies to use role for ticket management
-- Staff and admins can update any ticket, customers can only view their own

-- Drop existing update policy if it exists
DROP POLICY IF EXISTS "Users can update own tickets" ON tickets;

-- Create new policy based on role
CREATE POLICY "Staff and admins can update any ticket"
ON tickets FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('staff', 'admin')
  )
);

-- Customers can only update their own tickets (status changes)
CREATE POLICY "Customers can update own tickets"
ON tickets FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'customer'
  )
);
