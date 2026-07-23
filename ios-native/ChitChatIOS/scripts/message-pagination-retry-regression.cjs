const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const project = path.resolve(__dirname, '..', 'ChitChatIOS');
const model = fs.readFileSync(path.join(project, 'Models/Message.swift'), 'utf8');
const service = fs.readFileSync(path.join(project, 'Services/MessageService.swift'), 'utf8');
const socket = fs.readFileSync(path.join(project, 'Services/SocketService.swift'), 'utf8');
const detail = fs.readFileSync(path.join(project, 'Screens/ChatDetailViewController.swift'), 'utf8');
const cell = fs.readFileSync(path.join(project, 'Screens/MessageBubbleCell.swift'), 'utf8');

const checks = [
  [service, /listMessages\(chatId: String, cursor: String\? = nil, limit: Int = 50\)/, 'cursor-aware message service exists'],
  [service, /URLQueryItem\(name: "cursor", value: cursor\)/, 'cursor is sent only when present'],
  [service, /nextCursor: result\.meta\?\.nextCursor[\s\S]*hasMore:/, 'pagination metadata is decoded'],
  [detail, /private var nextMessageCursor: String\?/, 'next cursor is retained per chat'],
  [detail, /private var hasMoreMessages = false/, 'pagination stop state exists'],
  [detail, /private var olderMessagesTask: Task<Void, Never>\?/, 'overlapping older loads are guarded'],
  [detail, /func scrollViewDidScroll[\s\S]*loadOlderMessages\(\)/, 'top scrolling triggers older-page loading'],
  [detail, /olderMessagesSpinner[\s\S]*Retry older messages/, 'bounded top spinner and retry control exist'],
  [detail, /previousContentHeight[\s\S]*heightDelta[\s\S]*previousOffset\.y \+ heightDelta/, 'prepend preserves table scroll offset'],
  [detail, /mergeAuthoritativeMessage[\s\S]*pendingSends\.removeValue/, 'REST/socket merge replaces matching pending rows'],
  [detail, /pendingSends: \[String: PendingMessageSend\]/, 'pending send state is retained'],
  [model, /enum MessageLocalSendState[\s\S]*case sending[\s\S]*case failed/, 'sending and failed states are modeled'],
  [model, /let clientSendId: String\?/, 'authoritative and local messages carry client IDs'],
  [detail, /UUID\(\)\.uuidString\.lowercased\(\)/, 'stable client ID is created before first attempt'],
  [detail, /pending\.attempts > 1[\s\S]*fileExists/, 'attachment retry detects unavailable local files'],
  [detail, /latest\.payload = \.ready\(request\)/, 'uploaded attachment metadata survives send retry'],
  [socket, /payload\["clientSendId"\] = clientSendId/, 'Socket.IO send carries the stable client ID'],
  [detail, /clientSendId: request\.clientSendId/, 'REST fallback and socket path reuse the same ID'],
  [cell, /MessageLocalSendState\?[\s\S]*Not sent - Retry/, 'failed bubble exposes a native retry action'],
  [cell, /accessibilityLabel = state == \.failed[\s\S]*Message not sent\. Retry/, 'retry action is accessible'],
  [cell, /if url\.isFileURL[\s\S]*UIImage\(contentsOfFile:/, 'pending local image preview is supported'],
  [detail, /pendingSends\.removeAll\(\)/, 'pending state is cleared with the controller lifecycle'],
  [detail, /message\.clientSendId\.flatMap[\s\S]*pendingSends/, 'cell state is resolved without mutating server receipts'],
  [detail, /if leftDate != rightDate[\s\S]*normalizedMessageID/, 'timestamp ordering has an ID tie-breaker'],
];

checks.forEach(([source, pattern, label]) => assert.match(source, pattern, label));

console.log(`native iOS message pagination/retry regressions passed (${checks.length} checks)`);
