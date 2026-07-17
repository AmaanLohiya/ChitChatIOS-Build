const assert = require('node:assert/strict');
const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..', '..', '..');
const nativeRoot = path.resolve(__dirname, '..', 'ChitChatIOS');
const baseline = '7e8906dd6eec9126a674dd209388a2ad87ec6ed7';
const read = (relativePath) => fs.readFileSync(path.join(nativeRoot, relativePath), 'utf8');
const readRepo = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
const normalize = (value) => value.replace(/\r\n/g, '\n');
const baselineFile = (relativePath) =>
  cp.execFileSync('git', ['show', `${baseline}:${relativePath}`], {
    cwd: repoRoot,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
const hasGitObject = (ref) => {
  try {
    cp.execFileSync('git', ['cat-file', '-e', ref], { cwd: repoRoot, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
};

const service = read('Services/VoiceCallService.swift');
const socket = read('Services/SocketService.swift');
const chatDetail = read('Screens/ChatDetailViewController.swift');
const videoVC = read('Screens/VideoCallViewController.swift');
const voiceCall = read('Models/VoiceCall.swift');
const plist = read('Info.plist');
const pbx = fs.readFileSync(path.join(nativeRoot, '..', 'ChitChatIOS.xcodeproj', 'project.pbxproj'), 'utf8');

let passed = 0;
function test(name, assertion) {
  assertion();
  passed += 1;
  process.stdout.write(`PASS ${name}\n`);
}

test('outgoing video call no longer shows coming later', () => {
  assert.doesNotMatch(chatDetail, /Video calls are coming later|showVideoComingSoon/);
  assert.match(chatDetail, /startOutgoingVideoCall\(/);
});

test('group video calls remain blocked before startup', () => {
  assert.match(chatDetail, /guard chat\.type == \.direct/);
  assert.match(chatDetail, /Video calls are available only in direct chats/);
});

test('duplicate active-call guard remains shared by voice and video', () => {
  assert.match(service, /guard peerConnection == nil, currentCall == nil, !isStartingCall/);
  assert.match(service, /case \.alreadyInCall/);
});

test('SocketService sends the requested call type', () => {
  assert.match(socket, /type: VoiceCallType/);
  assert.match(socket, /"type": type\.rawValue/);
  assert.doesNotMatch(socket, /"type": VoiceCallType\.voice\.rawValue/);
});

test('incoming video offers are not rejected as unsupported', () => {
  assert.doesNotMatch(service, /unsupported_video|unsupportedVideo|Video calls are coming later/);
  assert.match(service, /activeCallType = call\.type/);
});

test('voice-only calls do not initialize a camera', () => {
  assert.match(service, /if type == \.video \{[\s\S]*makeLocalVideoTrack/);
  assert.match(service, /func startOutgoingVoiceCall[\s\S]*type: \.voice/);
});

test('video calls request camera permission separately from microphone', () => {
  assert.match(service, /AVCaptureDevice\.authorizationStatus\(for: \.video\)/);
  assert.match(service, /VoiceCallServiceError\.cameraPermissionDenied/);
});

test('WebRTC camera capturer and local video track are created', () => {
  assert.match(service, /RTCCameraVideoCapturer\(delegate: videoSource\)/);
  assert.match(service, /factory\.videoTrack\(with: videoSource/);
});

test('camera selection is dynamic and uses supported formats', () => {
  assert.match(service, /RTCCameraVideoCapturer\.captureDevices\(\)/);
  assert.match(service, /RTCCameraVideoCapturer\.supportedFormats\(for: device\)/);
  assert.match(service, /min\(maxFPS, 30\)/);
});

test('local and remote renderers attach to video tracks', () => {
  assert.match(service, /func attachVideoRenderers\(local: RTCVideoRenderer, remote: RTCVideoRenderer\)/);
  assert.match(service, /localVideoTrack\?\.add\(local\)/);
  assert.match(service, /remoteVideoTrack\?\.add\(remote\)/);
});

test('remote video receiver callback is implemented', () => {
  assert.match(service, /didAdd rtpReceiver: RTCRtpReceiver/);
  assert.match(service, /rtpReceiver\.track as\? RTCVideoTrack/);
});

test('camera enable-disable and front-rear switching exist', () => {
  assert.match(service, /func toggleCamera\(\)/);
  assert.match(service, /localVideoTrack\?\.isEnabled = isCameraEnabled/);
  assert.match(service, /func switchCamera\(\)/);
});

test('microphone mute remains supported', () => {
  assert.match(service, /func toggleMute\(\)/);
  assert.match(service, /localAudioTrack\?\.isEnabled = !isMuted/);
});

test('video cleanup stops camera and detaches renderers', () => {
  assert.match(service, /cameraCapturer\?\.stopCapture\(\)/);
  assert.match(service, /localVideoTrack\?\.remove\(localVideoRenderer\)/);
  assert.match(service, /remoteVideoTrack\?\.remove\(remoteVideoRenderer\)/);
  assert.match(service, /localVideoTrack = nil/);
  assert.match(service, /remoteVideoTrack = nil/);
});

test('second-call state resets to voice defaults after cleanup', () => {
  assert.match(service, /activeCallType = \.voice/);
  assert.match(service, /isCameraEnabled = true/);
  assert.match(service, /isSwitchingCamera = false/);
});

test('call presentation state carries video-specific flags', () => {
  assert.match(voiceCall, /let callType: VoiceCallType/);
  assert.match(voiceCall, /let isCameraEnabled: Bool/);
  assert.match(service, /callType: activeCallType/);
});

test('dedicated video UI has remote, local, and Android-equivalent controls', () => {
  assert.match(videoVC, /RTCMTLVideoView/);
  assert.match(videoVC, /localPreviewContainer/);
  assert.match(videoVC, /toggleCamera/);
  assert.match(videoVC, /switchCamera/);
  assert.match(videoVC, /showAudioRoutes/);
});

test('video permissions describe current behavior', () => {
  assert.match(plist, /video calls/);
  assert.match(plist, /voice and video calls/);
});

test('Xcode project references the new video controller exactly once', () => {
  assert.equal((pbx.match(/VideoCallViewController\.swift in Sources/g) ?? []).length, 2);
  assert.equal((pbx.match(/VideoCallViewController\.swift \*\/ = \{isa = PBXFileReference/g) ?? []).length, 1);
});

test('protected Android, Demo OTP, and Updates sources remain unchanged', () => {
  const protectedPaths = [
    'chat-app/src/screens/StoriesScreen.tsx',
    'ios-native/ChitChatIOS/ChitChatIOS/Screens/OTPViewController.swift',
    'ios-native/ChitChatIOS/ChitChatIOS/Screens/UpdatesViewController.swift'
  ];
  if (hasGitObject(`${baseline}^{commit}`)) {
    for (const file of protectedPaths) {
      assert.equal(normalize(readRepo(file)), normalize(baselineFile(file)), `${file} changed unexpectedly`);
    }
  } else {
    assert.equal(fs.existsSync(path.join(repoRoot, 'chat-app')), false, 'public mirror must not contain chat-app');
    assert.equal(fs.existsSync(path.join(repoRoot, 'server')), false, 'public mirror must not contain server');
  }
});

process.stdout.write(`Native iOS video-call regression checks passed: ${passed}.\n`);
