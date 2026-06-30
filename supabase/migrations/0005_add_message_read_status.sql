-- Add read_at and status columns to messages table
-- These fields exist in the Dart model but were missing from the schema

-- Add read_at column (timestamp when message was read by recipient)
ALTER TABLE messages ADD COLUMN read_at timestamptz;

-- Add status column (sent, delivered, read)
ALTER TABLE messages ADD COLUMN status text NOT NULL DEFAULT 'sent';

-- Add index for status queries
CREATE INDEX idx_messages_status ON messages(status);

-- Add index for read_at queries
CREATE INDEX idx_messages_read_at ON messages(read_at);

-- Create function to mark messages as read when conversation is opened
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS void AS $$
BEGIN
  -- Update all unread messages in the conversation (sent by other users)
  UPDATE messages
  SET read_at = now(),
      status = 'read'
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND read_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update message status to 'delivered' when inserted
CREATE OR REPLACE FUNCTION set_message_status_on_insert()
RETURNS trigger AS $$
BEGIN
  -- Set initial status to 'sent'
  NEW.status = 'sent';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new messages
DROP TRIGGER IF EXISTS set_message_status_trigger ON messages;
CREATE TRIGGER set_message_status_trigger
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION set_message_status_on_insert();
