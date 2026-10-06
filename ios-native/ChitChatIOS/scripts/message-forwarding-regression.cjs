const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, 'ChitChatIOS', p), 'utf8');
const ui = read('Screens/ForwardMessageViewController.swift');
for (const pattern of [/UISearchResultsUpdating/, /localizedCaseInsensitiveContains/, /ChatService\(\).listChats\(\)/, /isActiveMember\(userID\)/,
  /selected.count < 10/, /private let clientForwardId = UUID\(\).uuidString/, /targetChatIds: selected.sorted\(\), clientForwardId: clientForwardId/,
  /guard !busy, !started/, /selection locked for retry/, /Retry will not duplicate successful sends/, /Some destinations may already have received it/,
  /Task.isCancelled/, /ReplicaAvatarView/, /ChitChatColors/, /sent == selected/, /authenticatedUser\?\.id == userID/]) assert.match(ui, pattern);
assert.doesNotMatch(ui, /fatalError|try!|as!|sourceSender|originalChat|forwardedFrom/);
const model = read('Models/Message.swift');
assert.match(model, /\(try\? container.decode\(Bool.self\)\) == true/);
assert.match(model, /forwarded\?\.value == true && !isDeletedForEveryone/);
assert.match(model, /!isDeletedForEveryone, !isDeletedForMe/);
assert.match(model, /case .system: return false/);
for (const type of ['image', 'document', 'voice', 'audio', 'video', 'text', 'location', 'contact', 'gif', 'sticker']) assert.ok(model.includes(`.${type}`));
const detail = read('Screens/ChatDetailViewController.swift');
assert.match(detail, /if message.canForward/); assert.match(detail, /current.canForward/);
assert.match(detail, /ForwardMessageViewController\(message: current/);
for (const existing of ['beginReply', 'confirmDelete', 'beginEditing', 'loadOlderMessages']) assert.ok(detail.includes(existing));
const cell = read('Screens/MessageBubbleCell.swift');
assert.match(cell, /forwardedLabel.text = "Forwarded"/);
assert.match(cell, /forwardedLabel.isHidden = !message.isForwarded/);
assert.match(cell, /forwardedLabel.text = message.isForwarded \? "Forwarded" : nil/);
assert.match(cell, /forwardedLabel.isHidden = true\s*forwardedLabel.text = nil/);
assert.match(cell, /bubbleTopConstraint\?\.constant = message.isForwarded \? 20 : 0/);
assert.match(cell, /forwardedLabel.textColor = ChitChatColors.textMuted/);
assert.match(cell, /private func resetForConfiguration\(\) \{\s*forwardedLabel.isHidden = true/);
const api = read('Services/MessageService.swift');
assert.match(api, /ForwardRequest\(targetChatIds: targetChatIds, clientForwardId: clientForwardId\)/);
const pbx = fs.readFileSync(path.join(root, 'ChitChatIOS.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((pbx.match(/F5A000000000000000000001 \/\* ForwardMessageViewController.swift in Sources \*\//g) || []).length, 2);
console.log('Native forwarding static checks passed: eligibility, tolerant boolean, real chats, multiselect/search, stable retry, partial result, shared renderer/reuse, theme and PBX. Not a substitute for Xcode/device tests.');
