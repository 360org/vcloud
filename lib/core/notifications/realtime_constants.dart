/// Polling cadences for the real-time channels.
///
/// The backend exposes no websocket today, so each `watch*` stream polls on
/// a [Timer.periodic] driven by these values. They are gathered in one place
/// so a future websocket swap can target them centrally, and tests can inject
/// shorter intervals without touching production defaults.
///
/// Keep the chat-detail cadence fastest (a viewer is actively watching it),
/// the bell slowest (notifications are less time-critical), and the chat list
/// in between (it also drives the bottom-nav unread badge).
class RealtimeIntervals {
  const RealtimeIntervals._();

  /// Conversation list + bottom-nav unread badge.
  static const Duration chatList = Duration(seconds: 30);

  /// Messages for the currently-open chat detail screen.
  static const Duration chatDetail = Duration(seconds: 15);

  /// Open check-in/out state and the Home presence indicator.
  ///
  /// This is a fallback for sessions where no foreground push is delivered.
  static const Duration attendance = Duration(seconds: 15);

  /// Bell notification center (all event types).
  static const Duration notifications = Duration(seconds: 45);
}
