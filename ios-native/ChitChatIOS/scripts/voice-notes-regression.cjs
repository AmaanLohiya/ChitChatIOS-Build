const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const sourceRoot = path.join(root, 'ChitChatIOS');
const read = (relativePath) => fs.readFileSync(path.join(sourceRoot, relativePath), 'utf8');

const audio = read('Screens/VoiceNoteAudioController.swift');
const composer = read('Screens/VoiceNoteComposerView.swift');
const chat = read('Screens/ChatDetailViewController.swift');
const bubble = read('Screens/MessageBubbleCell.swift');
const input = read('Screens/MessageInputBar.swift');
const upload = read('Services/UploadService.swift');
const callAudio = read('Services/CallAudioSession.swift');
const plist = read('Info.plist');
const project = fs.readFileSync(
  path.join(root, 'ChitChatIOS.xcodeproj', 'project.pbxproj'),
  'utf8',
);

assert.match(audio, /AVAudioRecorder/, 'iOS must record with AVAudioRecorder');
assert.match(audio, /AVPlayer/, 'iOS must play remote and local voice notes');
assert.match(audio, /requestRecordPermission/, 'iOS must request microphone permission');
assert.match(audio, /kAudioFormatMPEG4AAC/, 'iOS must encode AAC');
assert.match(audio, /appendingPathExtension\("m4a"\)/, 'iOS must create M4A recordings');
assert.match(audio, /AVSampleRateKey:\s*44_100/, 'iOS voice notes must use a 44.1 kHz profile');
assert.match(audio, /AVNumberOfChannelsKey:\s*1/, 'iOS voice notes must use mono audio');
assert.match(audio, /AVEncoderBitRateKey:\s*96_000/, 'iOS voice notes must use the clear 96 kbps AAC profile');
assert.match(audio, /AVEncoderAudioQualityKey:\s*AVAudioQuality\.high/, 'iOS voice notes must retain high encoder quality');
assert.match(audio, /previousCategory[\s\S]*restoreAudioSession\(\)/, 'Voice-note recording must restore the prior audio session');
assert.match(audio, /mode:\s*\.spokenAudio/, 'Voice-note recording must use its own spoken-audio session profile');
assert.match(callAudio, /\.voiceChat/, 'Voice/video call audio must retain its separate communication profile');
assert.match(audio, /minimumDuration[\s\S]*0\.5/, 'iOS must enforce the minimum duration');
assert.match(audio, /maximumDuration[\s\S]*10 \* 60/, 'iOS must enforce the maximum duration');
assert.match(audio, /removeTemporaryFile/, 'iOS must clean temporary voice-note files');
assert.match(audio, /removeObservers\(\)/, 'Playback observers must be cleaned up');

assert.match(composer, /showRecording/, 'iOS must show recording state');
assert.match(composer, /showPreview/, 'iOS must show preview state');
assert.match(composer, /onCancel/, 'iOS must support discard');
assert.match(composer, /onSend/, 'iOS must support send after preview');
assert.match(composer, /UISlider/, 'iOS preview must support seeking');

assert.match(input, /var onVoice/, 'The composer microphone action must be connected');
assert.match(chat, /usage:\s*\.voice/, 'iOS voice notes must use the persisted upload path');
assert.match(chat, /messageType:\s*\.voice/, 'iOS voice notes must persist as voice messages');
assert.match(chat, /clientSendId/, 'iOS retry must retain Phase 3A clientSendId');
assert.match(chat, /voiceRecordingUnavailable/, 'Missing retry files must fail honestly');
assert.match(chat, /isChitChatCallInterfaceActive/, 'Recording must be blocked while calls are active');
assert.match(chat, /releasePendingSend/, 'Authoritative reconciliation must release temporary files');
assert.match(bubble, /configureVoice/, 'iOS must render a real voice-note bubble');
assert.match(bubble, /voiceSlider/, 'iOS voice bubbles must support seeking');
assert.match(bubble, /voiceStopHandler/, 'Cell reuse must stop active playback');
assert.match(upload, /case "m4a":\s*return "audio\/mp4"/, 'M4A MIME inference must be interoperable');
assert.match(plist, /voice notes[\s\S]*voice and video calls/, 'Microphone rationale must be complete');

for (const fileName of ['VoiceNoteAudioController.swift', 'VoiceNoteComposerView.swift']) {
  const escaped = fileName.replace('.', '\\.');
  assert.match(project, new RegExp(`${escaped} in Sources`), `${fileName} must be in PBX Sources`);
  assert.equal(
    (project.match(new RegExp(`path = ${escaped}`, 'g')) || []).length,
    1,
    `${fileName} must have one PBX file reference`,
  );
}

console.log('native iOS voice-note regression checks passed (37 checks)');
