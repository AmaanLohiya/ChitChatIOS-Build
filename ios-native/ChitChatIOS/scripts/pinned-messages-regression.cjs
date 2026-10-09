const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, 'ChitChatIOS', p), 'utf8');
const ui = read('Screens/PinnedMessagesViewController.swift');
const detail = read('Screens/ChatDetailViewController.swift');
const socket = read('Services/SocketService.swift');
for (const pattern of [/struct ChatPin: Decodable/, /let preview: String/, /let canManage: Bool/, /ChatPins.empty/,
  /APIClient.shared.request\(path/, /method: .post, body: PinRequest\(messageId: messageID\)/, /method: .delete/,
  /guard state.canManage, !busy, isCurrentUser/, /authenticatedUser\?\.id == userID/,
  /PinnedMessagesViewController\(coordinator: self\)/, /PinnedMessagePreviewController\(message: message/,
  /MessageBubbleCell/, /cell.configure\(message: message/, /openLoaded\?\(message\)/, /openMedia\?\(message\)/,
  /preview\?\.invalidate\(\)/, /revision \+= 1/, /version == revision/, /state = .empty; render\(\)/,
  /\.socketMessageDeleted/, /\.socketChatPinsUpdated/, /\.socketChatUpdated/, /\.socketConnected/,
  /didBecomeActiveNotification/, /didEnterBackgroundNotification/, /removeObserver/,
  /ChitChatColors.surface/, /ChitChatColors.textPrimary/, /height\?\.constant = latest == nil \? 0 : 56/]) assert.match(ui, pattern);
assert.doesNotMatch(ui, /fatalError|try!|as!|nextMessageCursor|listMessages\(|forwardedFrom|latitude|longitude|phoneNumber|print\(/);
assert.match(detail, /pinnedMessages.state.canManage, !pinnedMessages.busy, message.canPin/);
assert.match(detail, /message.clientSendId.flatMap\(\{ pendingSends\[\$0\] \}\) == nil/);
assert.match(detail, /title: remove \? "Unpin" : "Pin"/);
assert.match(detail, /tableView.topAnchor.constraint\(equalTo: pinnedMessages.banner.bottomAnchor\)/);
const jump = detail.slice(detail.indexOf('private func jumpToLoadedPin'), detail.indexOf('private func presentReactionActions'));
assert.match(jump, /timelineRows.firstIndex/); assert.match(jump, /scrollToRow/); assert.match(jump, /highlightedPinID = nil/);
assert.doesNotMatch(jump, /loadOlderMessages|nextMessageCursor|messages.append|messages.insert/);
assert.match(socket, /socket.on\("chat:pins-updated"\)/);
assert.match(socket, /notificationCenter.post\(name: .socketChatPinsUpdated, object: chatID\)/);
const pbx = fs.readFileSync(path.join(root, 'ChitChatIOS.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((pbx.match(/F5B000000000000000000001 \/\* PinnedMessagesViewController.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/path = PinnedMessagesViewController.swift/g) || []).length, 1);
require('./message-forwarding-regression.cjs');
console.log('Native pins static checks passed: authenticated metadata/actions, shared renderer, loaded highlight/historical fallback, realtime cleanup, theme and PBX. Xcode/device validation remains required.');
