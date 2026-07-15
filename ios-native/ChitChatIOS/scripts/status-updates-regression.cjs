const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const readScreen = (name) =>
  fs.readFileSync(path.join(projectRoot, 'ChitChatIOS', 'Screens', name), 'utf8');

const updates = readScreen('UpdatesViewController.swift');
const viewer = readScreen('StatusViewerViewController.swift');
let passed = 0;

function test(name, assertion) {
  assertion();
  passed += 1;
  process.stdout.write(`PASS ${name}\n`);
}

test('visible native plus is an interactive button with a 44-point hit target', () => {
  assert.match(updates, /final class StatusAddButton: UIButton/);
  assert.match(updates, /\(44 - bounds\.width\) \/ 2/);
  assert.match(updates, /badge\.addTarget\(self, action: #selector\(createTapped\), for: \.touchUpInside\)/);
  assert.equal((updates.match(/addPlusBadge\(to: control/g) ?? []).length, 2);
});

test('quick and lower owner controls retain their tap handlers', () => {
  assert.ok((updates.match(/#selector\(ownerTapped\(_:\)\)/g) ?? []).length >= 3);
  assert.match(updates, /makeStripItem[\s\S]*owner\.id == currentUser\.id \? "Your Status"/);
  assert.match(updates, /makeMyStatus[\s\S]*makeLabel\("My Status"/);
});

test('active owner controls open an explicit owner-only viewer', () => {
  assert.match(updates, /sender\.ownerID == currentUser\.id[\s\S]*guard mine != nil[\s\S]*ownerStatusesOnly: true/);
});

test('owner viewer reads mine while contact viewer reads feed', () => {
  assert.match(viewer, /if self\.ownerStatusesOnly \{[\s\S]*statusService\.mine\(\)[\s\S]*\} else \{[\s\S]*statusService\.feed\(\)/);
});

test('owner viewing cannot acknowledge a status view', () => {
  assert.match(viewer, /private func acknowledgeCurrentStatusIfNeeded\(\)[\s\S]*!isOwner[\s\S]*statusService\.markViewed/);
});

test('creation is independent from the header menu and duplicate-safe', () => {
  assert.match(updates, /badge\.addTarget[\s\S]*#selector\(createTapped\)/);
  assert.match(updates, /private func presentCreation\(\) \{\s*guard presentedViewController == nil else \{ return \}/);
});

process.stdout.write(`Native Updates regression checks passed: ${passed}\n`);
