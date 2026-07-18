const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', 'ChitChatIOS');
const projectRoot = path.resolve(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const deviceService = read('Services/DeviceContactsService.swift');
const contacts = read('Screens/ContactsViewController.swift');
const contactService = read('Services/ContactService.swift');
const contactCell = read('Screens/ContactCell.swift');
const session = read('Application/SessionManager.swift');
const plist = read('Info.plist');
const project = fs.readFileSync(
  path.join(projectRoot, 'ChitChatIOS.xcodeproj', 'project.pbxproj'),
  'utf8',
);

assert.match(deviceService, /import Contacts/);
assert.match(deviceService, /CNContactStore/);
assert.match(deviceService, /DispatchQueue\([\s\S]*com\.chitchat\.ios\.device-contacts/);
assert.match(deviceService, /queue\.async/);
assert.match(deviceService, /CNContactPhoneNumbersKey/);
assert.match(deviceService, /CNContactGivenNameKey/);
assert.doesNotMatch(deviceService, /CNContactEmailAddressesKey|CNContactPostalAddressesKey|CNContactImageDataKey/);
assert.match(deviceService, /importBatchSize = 500/);
assert.match(deviceService, /stride\(from: 0, to: entries\.count, by: Self\.importBatchSize\)/);
assert.match(deviceService, /maximumPhonesPerContact = 10/);
assert.match(deviceService, /seenPhones\.insert\(normalized\)\.inserted/);
assert.match(deviceService, /SHA256\.hash/);
assert.match(deviceService, /defaultPhone[\s\S]*hasPrefix\("\+91"\)/);
assert.match(deviceService, /lastSuccessfulFingerprint/);
assert.match(deviceService, /clearFingerprint/);

assert.match(contactService, /\/api\/v1\/contacts\/import-device/);
assert.match(contacts, /deviceContactsService\.requestAuthorization\(\)/);
assert.match(contacts, /UIApplication\.openSettingsURLString/);
assert.match(contacts, /UIApplication\.didBecomeActiveNotification/);
assert.match(contacts, /\$0\.source == \.app \|\| \$0\.contactUserId != nil/);
assert.match(contacts, /deviceContactsService\.importBatches\(for: snapshot\.entries\)/);
assert.match(contacts, /contactService\.importDeviceContacts\(entries: entries\)/);
assert.match(contacts, /ChatDetailViewController\(chat: chat, currentUser: self\.currentUser\)/);
assert.match(contacts, /AddContactViewController\(contactService: contactService\)/);
assert.doesNotMatch(contacts, /UIActivityViewController|Join me on ChitChat/);
assert.match(contactCell, /On ChitChat -/);
assert.match(contactCell, /Saved contact -/);
assert.match(session, /DeviceContactsService\(\)\.clearFingerprint\(for: userID\)/);
assert.match(plist, /NSContactsUsageDescription/);
assert.match(plist, /find people who already use ChitChat/);
assert.equal((project.match(/DeviceContactsService\.swift \*\/ = \{isa = PBXFileReference/g) ?? []).length, 1);
assert.equal((project.match(/DeviceContactsService\.swift in Sources \*\/ = \{isa = PBXBuildFile/g) ?? []).length, 1);
assert.equal((project.match(/DeviceContactsService\.swift in Sources \*\//g) ?? []).length, 2);

process.stdout.write('Native iOS device-contact regression checks passed: 27.\n');
