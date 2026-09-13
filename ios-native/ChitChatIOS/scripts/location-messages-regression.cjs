const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, 'ChitChatIOS', file), 'utf8');
const preview = read('Screens/LocationMessageViewController.swift');
const detail = read('Screens/ChatDetailViewController.swift');
const model = read('Models/Message.swift');
const cell = read('Screens/MessageBubbleCell.swift');
const socket = read('Services/SocketService.swift');
const plist = read('Info.plist');
const checks = [
  [preview, /CLLocationManager\(\)/],
  [preview, /requestWhenInUseAuthorization\(\)/],
  [preview, /manager\.requestLocation\(\)/],
  [preview, /manager\.stopUpdatingLocation\(\)/],
  [preview, /didUpdateLocations[\s\S]*stop\(\)[\s\S]*candidate = value/],
  [preview, /withTimeInterval: 20/],
  [preview, /case \.denied, \.restricted/],
  [preview, /UIApplication\.openSettingsURLString/],
  [preview, /didEnterBackgroundNotification/],
  [preview, /viewWillDisappear[\s\S]*candidate = nil[\s\S]*manager\.delegate = nil/],
  [preview, /Share this location\?/],
  [preview, /private func send\(\)[\s\S]*candidate[\s\S]*dismiss\(animated: true\) \{ callback\?\(value\) \}/],
  [preview, /MKMapItem\(placemark: MKPlacemark/],
  [preview, /openInMaps/],
  [preview, /ChitChatColors\.textPrimary[\s\S]*ChitChatColors\.textMuted/],
  [model, /lat\.isFinite && lng\.isFinite && \(-90\.\.\.90\)\.contains\(lat\)/],
  [model, /try\? values\?\.decode\(Double\.self/],
  [model, /Shared location[\s\S]*String\(format:/],
  [model, /let location: MessageLocation\?/],
  [detail, /title: "Location"[\s\S]*presentLocationPreview/],
  [detail, /controller\.onSend[\s\S]*clientSendId[\s\S]*type: \.location[\s\S]*payload: \.ready\(request\)/],
  [detail, /location: request\.location/],
  [detail, /LocationMessageCardView\.openMaps\(message\.location\)/],
  [cell, /message\.type == \.location[\s\S]*configureLocation/],
  [cell, /contentTopConstraint\(for: locationCard/],
  [cell, /resetContentVisibility\(\) \{[\s\S]*locationCard/],
  [socket, /location\.isValid[\s\S]*payload\["location"\]/],
  [plist, /NSLocationWhenInUseUsageDescription/],
];
checks.forEach(([source, pattern]) => assert.match(source, pattern));
assert.doesNotMatch(preview, /requestAlways|startUpdatingLocation|allowsBackgroundLocationUpdates|print\(|NSLog|CLGeocoder/);
assert.doesNotMatch(plist, /NSLocationAlways|<string>location<\/string>/);
const pbx = fs.readFileSync(path.join(root, 'ChitChatIOS.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((pbx.match(/LocationMessageViewController.swift in Sources/g) || []).length, 2);
assert.equal((pbx.match(/path = LocationMessageViewController.swift;/g) || []).length, 1);
console.log(`Native location source regression passed (${checks.length + 4} checks); UIKit/GPS runtime acceptance requires a device.`);
