const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, 'ChitChatIOS', file), 'utf8');
const ui = read('Screens/PollMessages.swift');
const detail = read('Screens/ChatDetailViewController.swift');
const model = read('Models/Message.swift');
const cell = read('Screens/MessageBubbleCell.swift');
const socket = read('Services/SocketService.swift');
for (const token of ['struct PollDraft: Codable', 'precomposedStringWithCompatibilityMapping', 'utf16.count > 300', 'utf16.count > 100', '(2...10)',
  'Set(p.options.map', 'struct MessagePoll: Codable', 'try? values?.decode', 'var hasResults', 'options.reduce', 'currentUserOptionId',
  'final class PollCreationViewController', 'fields.count < 10', 'self.fields.count > 2', 'addOption(); addOption()', 'Share this poll?', 'Send poll',
  'self.submitted = true', 'poll.validationError == nil', 'safeAreaLayoutGuide', 'keyboardLayoutGuide', 'ChitChatColors.surface', 'ChitChatColors.textPrimary',
  'final class PollMessageCardView', 'method: .post, body: Vote(optionId: optionID)', 'results.currentUserOptionId != optionID', 'button.isEnabled = results != nil',
  'UIProgressView', 'Choose one answer', 'Poll unavailable', 'reload(preservingVoteError: true)', 'version == revision', 'Task.isCancelled',
  '.socketPollUpdated', '.socketMessageDeleted', '.socketChatUpdated', '.socketConnected', '.socketDisconnected', 'didBecomeActiveNotification',
  'didEnterBackgroundNotification', 'SessionManager.currentUserDidChange', 'removeObserver', 'override func didMoveToWindow', 'func reset()', 'stop(); message = nil',
  'viewerID == SessionManager.shared.authenticatedUser?.id', 'message.isDeletedForEveryone', 'message.isDeletedForMe']) assert.ok(ui.includes(token), token);
assert.doesNotMatch(ui, /fatalError|try!|as!|print\(|voterIds|voterNames|sendMessage\(|reloadData\(|nextMessageCursor|VoiceCallService/);
assert.match(model, /case poll/); assert.match(model, /case \.system: return false/); assert.match(model, /case \.poll: return false/);
assert.match(model, /var canPin: Bool/); assert.match(model, /poll\?\.question.*prefix\(100\)/);
assert.match(detail, /title: "Poll"/); assert.match(detail, /controller.onSend =/);
assert.match(detail, /type: \.poll, text: nil, attachments: nil/); assert.match(detail, /poll: MessagePoll\(draft: poll\)/);
assert.match(detail, /enqueuePendingMessage\(pending, payload: \.ready\(request\), usesMediaTask: false\)/);
assert.match(detail, /poll: request.poll/); assert.match(detail, /message.canPin/); assert.match(detail, /message.canForward/);
assert.match(detail, /message.type == .text/);
for (const token of ['loadOlderMessages', 'timelineRows', 'replyToMessageID', 'jumpToLoadedPin', 'presentDeleteForMeAfterRead']) assert.ok(detail.includes(token), token);
assert.match(cell, /message.type == .poll/); assert.match(cell, /pollCard.configure\(message, viewerID: viewerID\)/); assert.match(cell, /pollCard.reset\(\)/);
assert.match(socket, /socket.on\("poll:updated"\)/); assert.match(socket, /name: .socketPollUpdated/); assert.match(socket, /payload\["poll"\] = try JSONSerialization.jsonObject\(with: JSONEncoder\(\).encode\(poll\)\)/);
const pbx = fs.readFileSync(path.join(root, 'ChitChatIOS.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((pbx.match(/F5C000000000000000000001 \/\* PollMessages.swift in Sources \*\//g) || []).length, 2);
assert.equal((pbx.match(/path = PollMessages.swift/g) || []).length, 1);
console.log('Native polls static regressions passed: form/validation/review, tolerant model, focused authenticated results/votes, safe cell reuse, realtime cleanup, theme, reply/delete/pin/non-forwarding integration and PBX. Xcode compilation and real-device acceptance are separate gates.');
