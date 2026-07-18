const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const sourceRoot = path.join(projectRoot, 'ChitChatIOS');
const read = (relativePath) => fs.readFileSync(path.join(sourceRoot, relativePath), 'utf8');

const models = read('Models/AuthModels.swift');
const service = read('Services/AuthService.swift');
const sessionManager = read('Application/SessionManager.swift');
const settings = read('Screens/SettingsViewController.swift');
const screen = read('Screens/ActiveSessionsViewController.swift');
const project = fs.readFileSync(path.join(projectRoot, 'ChitChatIOS.xcodeproj', 'project.pbxproj'), 'utf8');

assert.match(models, /struct ActiveSession: Decodable[\s\S]*isCurrent: Bool[\s\S]*lastActiveAt: String/);
assert.match(service, /func listSessions\(\)[\s\S]*\/api\/v1\/auth\/sessions/);
assert.match(service, /func revokeSession\(sessionId: String\)[\s\S]*method: \.delete/);
assert.match(service, /func logoutOtherSessions\(\)[\s\S]*\/api\/v1\/auth\/logout-others/);
assert.match(service, /PushNotificationService\.shared\.installationID/);
assert.match(service, /osVersion: device\.systemVersion/);
assert.match(settings, /Active sessions[\s\S]*openActiveSessions/);
assert.match(settings, /ActiveSessionsViewController\(\)/);
assert.match(screen, /This device/);
assert.match(screen, /authService\.listSessions\(\)/);
assert.match(screen, /authService\.revokeSession\(sessionId: session\.id\)/);
assert.match(screen, /authService\.logoutOtherSessions\(\)/);
assert.match(screen, /UIRefreshControl/);
assert.match(screen, /sessions = loaded\.sorted/);
assert.match(screen, /sessions\.removeAll \{ \$0\.id == session\.id \}/);
assert.match(screen, /sessions\.removeAll \{ !\$0\.isCurrent \}/);
assert.match(sessionManager, /shouldClearSession\(after: error\)[\s\S]*signOut\(\)/);
assert.match(sessionManager, /SESSION_INVALID[\s\S]*INVALID_REFRESH_TOKEN/);
assert.equal((project.match(/ActiveSessionsViewController\.swift \*\/ = \{isa = PBXFileReference/g) ?? []).length, 1);
assert.equal((project.match(/ActiveSessionsViewController\.swift in Sources \*\/ = \{isa = PBXBuildFile/g) ?? []).length, 1);
assert.equal((project.match(/ActiveSessionsViewController\.swift in Sources \*\//g) ?? []).length, 2);
assert.doesNotMatch(screen, /refreshToken|accessToken|tokenHash|ipAddress|location/);
assert.doesNotMatch(screen, /fatalError|try!|as!/);

console.log('Native iOS active-session regression checks passed (23).');
