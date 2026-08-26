enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

enum DeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum MessageType {
  text,
  // Extensible for future media types
  image,
  video,
  audio,
  document,
}

enum OutboxOperation {
  sendMessage,
  editMessage,
  deleteMessage,
  addReaction,
  removeReaction,
  readReceipt,
  deliveryReceipt,
}

enum OutboxStatus {
  pending,
  processing,
  completed,
  failed,
}
