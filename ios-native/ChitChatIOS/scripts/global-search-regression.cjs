const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const ui = read('ChitChatIOS/Screens/GlobalSearchViewController.swift');
const detail = read('ChitChatIOS/Screens/ChatDetailViewController.swift');
const local = read('ChitChatIOS/Screens/ConversationSearchViewController.swift');
const chats = read('ChitChatIOS/Screens/ChatsViewController.swift');
for (const token of ['@MainActor', 'UISearchController', 'UISearchBarDelegate', 'UITableViewController',
  '["All", "Chats", "People", "Messages"]', '300_000_000', 'Task.isCancelled', 'revision == version', 'currentUser',
  'URLQueryItem(name: "cursor"', 'URLQueryItem(name: "limit", value: "20")', '/api/v1/search', '/people/', '/open',
  'Search more', 'See all', 'Searching...', 'No matches in this range.', 'Pull to retry.', 'ChatService().getChat',
  'onOpen(chat, result.category == "messages" ? result.messageId : nil)', 'ChitChatColors.background', 'ChitChatColors.textPrimary',
  'search.searchBar.text = nil', 'task?.cancel()', 'removeObserver', 'SessionManager.currentUserDidChange', 'UIApplication.didEnterBackgroundNotification',
  'if !opening', 'opening = true', 'avatar.configure', 'imageTask?.cancel()', 'representedID == result.id']) assert.ok(ui.includes(token), token);
assert.doesNotMatch(ui, /fatalError|try!|as!|phoneNumber|latitude|longitude|forwardedFrom|mediaUrl|markRead|UserDefaults|print\(/);
assert.match(chats, /GlobalSearchViewController/); assert.match(chats, /searchMessageID: messageID/);
assert.match(chats, /private func searchChanged\(\)\s*\{\s*applySearch\(\)/);
for (const token of ['MessageSearchTarget.load(chatID: chat.id', 'guard hasLoaded, isViewVisible', 'pendingSearchMessageID = nil',
  'searchTargetTask?.cancel()', 'integrateSearchMessage(message)', 'mergeAuthoritativeMessage(message)', 'jumpToLoadedPin(message)']) assert.ok(detail.includes(token), token);
const integration = detail.slice(detail.indexOf('private func presentConversationSearch'), detail.indexOf('private func jumpToLoadedPin'));
assert.doesNotMatch(integration, /nextMessageCursor|messages.append|loadOlderMessages|markRead/);
assert.match(local, /enum MessageSearchTarget/); assert.match(local, /message.chatId == chatID/);
assert.match(local, /!message.isDeletedForEveryone, !message.isDeletedForMe/);
const pbx = read('ChitChatIOS.xcodeproj/project.pbxproj');
assert.equal((pbx.match(/F5E000000000000000000001 \/\* GlobalSearchViewController.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/F5E000000000000000000002 \/\* GlobalSearchViewController.swift \*\//g) || []).length, 3);
console.log('Native global search: DTO/privacy, categories, UI states, debounce, authorization, shared target/jump, unchanged history cursors, cleanup, theme and PBX passed. Static checks, not a Swift compiler or device test.');
