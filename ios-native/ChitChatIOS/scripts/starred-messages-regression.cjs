const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const ui = read('ChitChatIOS/Screens/StarredMessagesViewController.swift');
const detail = read('ChitChatIOS/Screens/ChatDetailViewController.swift');
const chats = read('ChitChatIOS/Screens/ChatsViewController.swift');
const socket = read('ChitChatIOS/Services/SocketService.swift');
for (const token of ['@MainActor', 'MessageStarAction', 'UITableViewController', 'messageId: String', 'chatName: String',
  'senderName: String', 'preview: String', '/api/v1/starred-messages', 'state.starred ? .delete : .post',
  'result.starred ? "Unstar" : "Star"', 'menu?.addAction(button)', 'if action.title != title', 'menu?.dismiss(animated: true)',
  'guard !writing, currentUser, let state', 'message.canPin', 'URLQueryItem(name: "limit", value: "20")',
  'URLQueryItem(name: "cursor"', 'Load more', 'No starred messages yet', 'Loading starred messages...',
  'Could not load starred messages', 'Message is no longer available', 'ChatService().getChat(id: item.chatId)',
  'onOpen(chat, item.messageId)', 'Task.isCancelled', 'revision == version', 'currentUser',
  'SessionManager.currentUserDidChange', 'UIApplication.didEnterBackgroundNotification', '.socketMessageStarUpdated',
  '.socketMessageDeleted', '.socketMessageUpdated', '.socketChatUpdated', '.socketDisconnected', '.socketConnected',
  'task?.cancel()', 'removeObserver', 'items = []', 'ChitChatColors.background', 'ChitChatColors.textPrimary']) {
  assert.ok((token === 'message.canPin' ? detail : ui).includes(token), token);
}
assert.doesNotMatch(ui, /action\?\.title\s*=|fatalError|try!|as!|phoneNumber|latitude|longitude|forwardedFrom|mediaUrl|markRead|UserDefaults|print\(/);
assert.ok(detail.includes('message.canPin, message.clientSendId.flatMap({ pendingSends[$0] }) == nil'), 'Exclude pending messages');
assert.match(detail, /MessageStarAction\(menu: menu/); assert.match(detail, /MessageSearchTarget.load/);
assert.match(detail, /mergeAuthoritativeMessage\(message\)/); assert.match(detail, /jumpToLoadedPin\(message\)/);
assert.match(chats, /StarredMessagesViewController/); assert.match(chats, /searchMessageID: messageID/);
assert.match(socket, /socket.on\("message:star-updated"\)/); assert.match(socket, /\.socketMessageStarUpdated/);
const pbx = read('ChitChatIOS.xcodeproj/project.pbxproj');
assert.equal((pbx.match(/F5F000000000000000000001 \/\* StarredMessagesViewController.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/F5F000000000000000000002 \/\* StarredMessagesViewController.swift \*\//g) || []).length, 3);
console.log('Native starred messages: action privacy/eligibility, safe DTO, cursor list, theme, invalidation, cleanup, shared historical target and PBX checks passed. Static checks, not an Xcode build or device test.');
