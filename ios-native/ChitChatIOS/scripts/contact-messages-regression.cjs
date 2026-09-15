const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, 'ChitChatIOS', file), 'utf8');

const preview = read('Screens/ContactMessageViewController.swift');
const detail = read('Screens/ChatDetailViewController.swift');
const model = read('Models/Message.swift');
const cell = read('Screens/MessageBubbleCell.swift');
const socket = read('Services/SocketService.swift');
const plist = read('Info.plist');

const checks = [
  [preview, /CNContactPickerViewController/],
  [preview, /requestAccess\(for: \.contacts\)/],
  [preview, /Share this contact\?/],
  [preview, /phoneNumbers\.prefix\(5\)/],
  [preview, /CNContactViewController\(forNewContact:/],
  [preview, /UIApplication\.openSettingsURLString/],
  [preview, /Only the selected contact's name, organization, and phone numbers will be shared/],
  [preview, /selectedContact\.isValid/],
  [preview, /dismiss\(animated: true\) \{ \[onSend\] in[\s\S]*onSend\?\(selectedContact\)/],
  [model, /struct MessageContactPhone: Codable, Equatable/],
  [model, /struct MessageContact: Codable, Equatable/],
  [model, /let displayName: String/],
  [model, /let phones: \[MessageContactPhone\]/],
  [model, /case displayName[\s\S]*case phoneNumber/],
  [model, /var contact: MessageContact\? = nil/],
  [model, /case \.contact:[\s\S]*Unsupported contact/],
  [model, /let contact: MessageContact\?/],
  [detail, /title: "Contact"[\s\S]*presentContactPreview/],
  [detail, /controller\.onSend[\s\S]*clientSendId[\s\S]*type: \.contact[\s\S]*payload: \.ready\(request\)/],
  [detail, /contact: request\.contact/],
  [detail, /ContactMessageCardView\.presentActions\(for: message\.contact, from: self\)/],
  [cell, /private let contactCard = ContactMessageCardView\(\)/],
  [cell, /message\.type == \.contact[\s\S]*configureContact/],
  [cell, /contentTopConstraint\(for: contactCard/],
  [cell, /resetContentVisibility\(\) \{[\s\S]*contactCard/],
  [socket, /contact\.isValid[\s\S]*payload\["contact"\]/],
  [plist, /NSContactsUsageDescription/],
  [plist, /choose contacts to share/],
];

checks.forEach(([source, pattern]) => assert.match(source, pattern));
assert.doesNotMatch(preview, /emailAddresses|postalAddresses|imageData|thumbnailImageData|identifier/);
assert.doesNotMatch(preview, /requestAlways|allowsBackgroundLocationUpdates|startMonitoringSignificantLocationChanges/);

const pbx = fs.readFileSync(path.join(root, 'ChitChatIOS.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((pbx.match(/ContactMessageViewController.swift in Sources/g) || []).length, 2);
assert.equal((pbx.match(/path = ContactMessageViewController.swift;/g) || []).length, 1);

console.log(`Native contact source regression passed (${checks.length + 4} checks); Contacts runtime acceptance requires a device.`);
