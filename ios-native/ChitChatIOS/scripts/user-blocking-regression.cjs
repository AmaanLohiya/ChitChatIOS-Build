const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const ui = read('ChitChatIOS/Screens/UserBlockingViewController.swift');
const detail = read('ChitChatIOS/Screens/ChatDetailViewController.swift');
for (const token of ['@MainActor', 'DirectBlockPolicy', 'blockedByMe', 'canCommunicate', '/api/v1/privacy/blocks',
  'BlockedUsersViewController', 'No blocked users', 'Unblock', 'Shared groups remain unaffected', 'Failed messages will not be resent',
  'method: blocked ? .post : .delete', 'method: .delete', 'URLQueryItem(name: "cursor"', 'Task.isCancelled', 'revision == version',
  'currentUser', 'removeObserver', 'timer?.invalidate()', 'socketPrivacyBlockUpdated', 'SessionManager.currentUserDidChange',
  'ChitChatColors.background', 'ChitChatColors.textPrimary', 'ReplicaAvatarView', 'nextCursor']) assert.ok(ui.includes(token), token);
for (const token of ['blockPolicy?.active = true', 'blockPolicy?.active = false', 'inputBar.isUserInteractionEnabled = communicationAllowed',
  'directVoiceButton?.isEnabled = communicationAllowed', 'directVideoButton?.isEnabled = communicationAllowed',
  'You blocked this user.', 'Messaging unavailable', 'policy.confirm(on: self', 'guard communicationAllowed else',
  'emit && communicationAllowed && isLocalTyping', 'chat.type == .group || blockPolicy?.allowed == true']) assert.ok(detail.includes(token), token);
assert.match(read('ChitChatIOS/Screens/SettingsViewController.swift'), /BlockingPrivacyViewController/);
assert.match(read('ChitChatIOS/Services/SocketService.swift'), /socket.on\("privacy:block-updated"\)/);
assert.doesNotMatch(ui, /fatalError|try!|as!|blocked you|blockedByOther|UserDefaults|print\(/);
const pbx = read('ChitChatIOS.xcodeproj/project.pbxproj');
assert.equal((pbx.match(/F6A000000000000000000001 \/\* UserBlockingViewController.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/F6A000000000000000000002 \/\* UserBlockingViewController.swift \*\//g) || []).length, 3);
console.log('Native user blocking: private state, generic availability, direct gates, group bypass, confirmation, paginated list, account/lifecycle safety, theme and PBX checks passed. Static checks, not signed-device acceptance.');
