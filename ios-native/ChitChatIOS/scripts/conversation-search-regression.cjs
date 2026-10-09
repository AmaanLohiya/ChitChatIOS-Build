const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const ui = read('ChitChatIOS/Screens/ConversationSearchViewController.swift');
const detail = read('ChitChatIOS/Screens/ChatDetailViewController.swift');
for (const token of ['@MainActor', 'UISearchController', 'UITableViewController', '300_000_000', 'Task.isCancelled', 'revision == version',
  'Enter 2 to 100 characters.', 'Searching...', 'No matches in this range.', 'Pull to retry.', 'Search older', 'previousResult', 'nextResult',
  'URLQueryItem(name: "q"', 'URLQueryItem(name: "cursor"', 'URLQueryItem(name: "limit", value: "20")', '/message-target/',
  'message.chatId == chatID', '!message.isDeletedForEveryone', '!message.isDeletedForMe', 'onOpen(message)', 'ChitChatColors.textPrimary',
  'ChitChatColors.background', 'task?.cancel()', 'removeObserver', '.socketMessageDeleted', '.socketMessageUpdated', 'SessionManager.currentUserDidChange',
  '!openingResult &&', 'openingResult = true']) assert.ok(ui.includes(token), token);
assert.match(ui, /let preview: String/);
assert.doesNotMatch(ui, /fatalError|try!|as!|phoneNumber|latitude|longitude|forwardedFrom|mediaUrl|markRead|loadOlderMessages|print\(/);
const integration = detail.slice(detail.indexOf('private func presentConversationSearch'), detail.indexOf('private func jumpToLoadedPin'));
for (const token of ['ConversationSearchViewController', 'mergeAuthoritativeMessage(message)', 'jumpToLoadedPin(message)', 'tableView.reloadData()',
  '!deletedForMeMessageIDs.contains', 'SessionManager.shared.authenticatedUser']) assert.ok(integration.includes(token), token);
assert.doesNotMatch(integration, /nextMessageCursor|messages.append|loadOlderMessages|markRead|pinnedMessages.change/);
assert.match(detail, /UIAction\(title: "Search"/);
assert.match(detail, /moreButton.showsMenuAsPrimaryAction = true/);
for (const token of ['makeTimelineRows', 'nextMessageCursor', 'loadOlderMessages', 'newMessageCount', 'jumpToLoadedPin']) assert.ok(detail.includes(token), token);
const pbx = read('ChitChatIOS.xcodeproj/project.pbxproj');
assert.equal((pbx.match(/F5D000000000000000000001 \/\* ConversationSearchViewController.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/F5D000000000000000000002 \/\* ConversationSearchViewController.swift \*\//g) || []).length, 3);
console.log('Native search: scoped DTO, debounce/cancellation, UI states, target authorization, pin-jump reuse, unchanged pagination and PBX wiring checks passed. Not a Swift compiler or device test.');
