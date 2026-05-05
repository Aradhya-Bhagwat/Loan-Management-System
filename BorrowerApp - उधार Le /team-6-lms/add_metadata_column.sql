-- Add metadata column to user_notifications table for navigation context
-- Run this in Supabase SQL Editor

ALTER TABLE user_notifications 
ADD COLUMN IF NOT EXISTS metadata text DEFAULT NULL;

-- Add a comment for documentation
COMMENT ON COLUMN user_notifications.metadata IS 'JSON string containing navigation context (e.g. application_id for chat notifications)';
