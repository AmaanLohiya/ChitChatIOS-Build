const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const project = path.resolve(__dirname, '..', 'ChitChatIOS');
const detail = fs.readFileSync(path.join(project, 'Screens/ChatDetailViewController.swift'), 'utf8');
const messageCell = fs.readFileSync(path.join(project, 'Screens/MessageBubbleCell.swift'), 'utf8');

const checks = [
  [detail, /private enum ChatTimelineRow[\s\S]*dateSeparator[\s\S]*message\(Message\)/, 'typed date and message rows exist'],
  [detail, /makeTimelineRows[\s\S]*previousDayKey[\s\S]*dayKey != previousDayKey/, 'one separator is emitted per local day'],
  [detail, /Calendar\.autoupdatingCurrent[\s\S]*isDateInToday[\s\S]*isDateInYesterday/, 'Today and Yesterday use the current calendar'],
  [detail, /setLocalizedDateFormatFromTemplate\("EEEE MMMd"\)[\s\S]*dateStyle = \.medium/, 'recent and older labels are localized'],
  [detail, /formatter\.locale = \.autoupdatingCurrent[\s\S]*formatter\.timeZone = \.autoupdatingCurrent/, 'device locale and timezone are honored'],
  [detail, /timelineRows = Self\.makeTimelineRows\(messages\)/, 'authoritative messages drive the row model'],
  [detail, /ChatDateSeparatorCell[\s\S]*ChitChatColors\.surface[\s\S]*ChitChatColors\.textMuted/, 'separator styling uses adaptive theme colors'],
  [detail, /numberOfRowsInSection[\s\S]*timelineRows\.count/, 'UITableView renders timeline rows'],
  [detail, /message\(at indexPath:[\s\S]*case let \.message/, 'message actions translate separator-aware index paths'],
  [detail, /previousContentHeight[\s\S]*heightDelta[\s\S]*previousOffset\.y \+ heightDelta/, 'pagination preserves the visible content offset'],
  [detail, /scrollToBottomButton\.bottomAnchor\.constraint\(equalTo: tableView\.bottomAnchor/, 'floating control stays above the composer'],
  [detail, /safeAreaLayoutGuide\.trailingAnchor[\s\S]*widthAnchor\.constraint\(lessThanOrEqualToConstant: 180\)/, 'floating control is safe-area bounded'],
  [detail, /newMessageCount \+= 1[\s\S]*updateScrollToBottomControl\(\)/, 'remote messages increment the marker while scrolled up'],
  [detail, /configuration\.title = newMessageCount == 1[\s\S]*new messages/, 'marker supports singular and plural labels'],
  [detail, /scrollToBottom\(animated:[\s\S]*newMessageCount = 0/, 'scrolling to newest clears the marker'],
  [detail, /if isNearBottom, newMessageCount > 0[\s\S]*newMessageCount = 0/, 'manual return to bottom clears the marker'],
  [detail, /event\.message\.senderId == currentUser\.id[\s\S]*scrollToBottom\(animated: true\)/, 'current-user realtime messages continue following'],
  [messageCell, /message\.type == \.image[\s\S]*message\.type == \.video[\s\S]*message\.type == \.document[\s\S]*message\.type == \.voice \|\| message\.type == \.audio/, 'image, video, document, and voice cells remain supported'],
];

checks.forEach(([source, pattern, label]) => assert.match(source, pattern, label));
assert.doesNotMatch(detail, /messages\[indexPath\.row\]/, 'separator rows cannot be treated as messages');

console.log(`native iOS chat timeline regressions passed (${checks.length + 1} checks)`);
