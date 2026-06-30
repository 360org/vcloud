-- Only create triggers and functions (columns already exist)

-- Create function to increment unread count when a new message is inserted
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS trigger AS $$
BEGIN
  UPDATE conversation_members
  SET unread_count = unread_count + 1
  WHERE conversation_id = NEW.conversation_id
    AND user_id != NEW.sender_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-increment unread count on new message
DROP TRIGGER IF EXISTS increment_unread_on_message ON messages;
CREATE TRIGGER increment_unread_on_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION increment_unread_count();

-- Create function to mark messages as read and reset unread count
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS void AS $$
BEGIN
  UPDATE messages
  SET read_at = now(),
      status = 'read'
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND read_at IS NULL;

  UPDATE conversation_members
  SET unread_count = 0
  WHERE conversation_id = p_conversation_id
    AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
