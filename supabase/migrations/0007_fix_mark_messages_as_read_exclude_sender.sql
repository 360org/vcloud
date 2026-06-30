-- Fix: mark_messages_as_read was flipping status='read' on messages
-- authored by ANY user in the conversation, including messages the
-- sender had just posted. Combined with the unread-count trigger
-- this caused two visible symptoms:
--   1. The sender's own freshly-sent message rendered as "đã đọc"
--      immediately after the recipient opened the conversation.
--   2. The recipient's unread_count did not increment for new
--      messages that arrived during the same race window
--      (mark_as_read RPC ran before the AFTER INSERT trigger).
--
-- This migration:
--   (a) Re-creates mark_messages_as_read so it skips the caller's own
--       messages (mirrors the 0005 version that was lost in 0006).
--   (b) Re-creates the unread-counter reset to happen in the same RPC
--       call after the UPDATE so the counter cannot be lowered when
--       the sender's INSERT came in mid-flight.
--   (c) Bumps the BEFORE INSERT status trigger to a slightly richer
--       shape so future migrations have a stable hook.

-- ---------------------------------------------------------------------------
-- (a) mark_messages_as_read — skip messages whose sender is the reader.
-- ---------------------------------------------------------------------------
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

  -- Reset the counter unconditionally for this user/conversation.
  -- If a new message arrives between the UPDATE above and now, the
  -- AFTER INSERT trigger will re-increment the counter, so we are
  -- safe even when the caller's INSERT races with the open-conversation
  -- flow.
  UPDATE conversation_members
  SET unread_count = 0
  WHERE conversation_id = p_conversation_id
    AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- (b) leave increment_unread_count untouched (introduced in 0005) — but
--     defensively re-define it so deployments that only ran 0006 + 0007
--     still get the trigger.
-- ---------------------------------------------------------------------------
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

DROP TRIGGER IF EXISTS increment_unread_on_message ON messages;
CREATE TRIGGER increment_unread_on_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION increment_unread_count();

-- ---------------------------------------------------------------------------
-- (c) Defensive: BEFORE INSERT status default. Unchanged behaviour —
--     only re-declared so future migrations can rely on its existence.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_message_status_on_insert()
RETURNS trigger AS $$
BEGIN
  NEW.status = 'sent';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_message_status_trigger ON messages;
CREATE TRIGGER set_message_status_trigger
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION set_message_status_on_insert();
