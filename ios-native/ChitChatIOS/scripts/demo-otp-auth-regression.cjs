const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', 'ChitChatIOS');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const login = read('Screens/LoginViewController.swift');
const otp = read('Screens/OTPViewController.swift');
const models = read('Models/AuthModels.swift');
const session = read('Application/SessionManager.swift');

assert.match(models, /enum OtpDeliveryMode: String, Codable/);
assert.match(models, /case demo[\s\S]*case sms/);
assert.match(models, /let resendAvailableAt: String/);
assert.match(models, /let deliveryMode: OtpDeliveryMode/);

assert.match(login, /ChitChat will prepare a verification code for your phone number\./);
assert.doesNotMatch(login, /will send an SMS|Development OTP/);
assert.match(login, /deliveryMode: result\.deliveryMode/);
assert.match(login, /demoOtp: result\.deliveryMode == \.demo \? result\.otp : nil/);
assert.match(login, /result\.deliveryMode != \.demo \|\| result\.otp\?\.count == 6/);

assert.match(otp, /demoTitle\.text = "Demo OTP"/);
assert.match(otp, /No SMS was sent\. Use this code to continue\./);
assert.match(otp, /UIPasteboard\.general\.string = demoOtp/);
assert.match(otp, /textContentType = \.oneTimeCode/, 'future SMS AutoFill must remain');
assert.match(otp, /resendAvailableAt\.timeIntervalSinceNow/, 'countdown must use server deadline');
assert.match(otp, /guard !isVerifying, !isResending, secondsRemaining == 0/);
assert.match(otp, /self\.isResending = false/);
assert.doesNotMatch(otp, /Development OTP|print\(/);

assert.match(session, /keychain\.set\(accessToken, for: Key\.accessToken\)/);
assert.match(session, /state = user\.isProfileComplete \? \.signedIn\(user\) : \.profileSetup\(user\)/);

process.stdout.write('Native iOS demo OTP authentication regression checks passed: 19.\n');
