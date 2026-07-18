const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', 'ChitChatIOS');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const chat = read('Models/Chat.swift');
const chatCell = read('Screens/ChatCell.swift');
const chats = read('Screens/ChatsViewController.swift');
const detail = read('Screens/ChatDetailViewController.swift');
const tabs = read('Screens/MainTabBarController.swift');
const socket = read('Services/SocketService.swift');
const messageService = read('Services/MessageService.swift');

assert.match(chat, /let unreadCount: Int/);
assert.match(chat, /func updatingUnreadCount\(_ unreadCount: Int\) -> Chat/);
assert.match(messageService, /struct MarkReadResponse: Decodable[\s\S]*unreadCount: Int/);
assert.match(chatCell, /let unreadCount = max\(0, chat\.unreadCount\)/);
assert.match(chatCell, /unreadBubble\.isHidden = unreadCount == 0/);
assert.match(chatCell, /unreadCount > 99 \? "99\+" : String\(unreadCount\)/);
assert.match(chatCell, /unread messages/);
assert.match(chats, /chats\.reduce\(0\)[\s\S]*updateChatsUnreadBadge\(total: total\)/);
assert.match(chats, /forName: \.socketConnected[\s\S]*loadChats\(showLoadingState: false\)/);
assert.match(chats, /UIApplication\.didBecomeActiveNotification/);
assert.match(tabs, /func updateChatsUnreadBadge\(total: Int\)/);
assert.match(tabs, /normalizedTotal > 99 \? "99\+"/);
assert.match(tabs, /normalizedTotal == 0[\s\S]*\? nil/);
assert.doesNotMatch(tabs, /badgeValue\s*=\s*"3"/);
assert.match(detail, /acknowledgeRead\(messageID: target\.id\)/);
assert.match(detail, /updatingUnreadCount\(result\.unreadCount\)/);
assert.match(socket, /func markRead[\s\S]*MarkReadResponse[\s\S]*responseData\["unreadCount"\]/);
assert.match(socket, /socket\.on\("chat:updated"\)[\s\S]*socketChatUpdated/);
assert.match(messageService, /func markRead[\s\S]*MarkReadResponse/);

console.log('Native iOS unread count regression checks passed (19).');
