const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const nativeRoot = path.resolve(__dirname, '..');
const root = path.resolve(nativeRoot, '../..');
const read = (file) => fs.readFileSync(path.join(nativeRoot, file), 'utf8');
const picker = read('ChitChatIOS/Screens/GifStickerMessageViewController.swift');
const model = read('ChitChatIOS/Models/Message.swift');
const cell = read('ChitChatIOS/Screens/MessageBubbleCell.swift');
const detail = read('ChitChatIOS/Screens/ChatDetailViewController.swift');
const socket = read('ChitChatIOS/Services/SocketService.swift');

for (const pattern of [/\/api\/v1\/gifs\/trending/, /\/api\/v1\/gifs\/search/, /300_000_000/,
  /Send this GIF\?/, /Send this sticker\?/, /temporarily unavailable/, /GifMessagePreviewController/,
  /CGImageSourceCreateThumbnailAtIndex/, /totalCostLimit/, /cancelLoad\(\)/, /GIF unavailable/,
  /ChitChatColors\.background/, /requestID == token/]) assert.match(picker, pattern);
assert.match(model, /func encode\(to encoder: Encoder\)/);
assert.match(model, /Self\.isAllowedURL\(mediaUrl\)/);
assert.match(model, /try\? values\?\.decode\(String.self, forKey: \.stickerId\)/);
assert.match(cell, /gif\.isValid[\s\S]*mediaImageView.load\(urlString: gif.previewUrl\)/);
assert.match(cell, /message.sticker\?\.isValid == true/);
for (const type of ['gif', 'sticker']) {
  assert.match(detail, new RegExp(`type: \\.${type}[\\s\\S]*clientSendId[\\s\\S]*payload: \\.ready\\(request\\)`));
  assert.match(socket, new RegExp(`payload\\["${type}"\\]`));
}
assert.doesNotMatch(picker, /API_KEY|EXPO_PUBLIC_|api_key=|file:\/\//);
const pbx = read('ChitChatIOS.xcodeproj/project.pbxproj');
assert.equal((pbx.match(/GifStickerMessageViewController.swift in Sources/g) || []).length, 2);
assert.equal((pbx.match(/path = GifStickerMessageViewController.swift;/g) || []).length, 1);
const swiftIDs = [...picker.matchAll(/stickerId: "([a-z-]+)", name:/g)].map((m) => m[1]);
assert.equal(swiftIDs.length, 12);
assert.equal(new Set(swiftIDs).size, 12);

async function androidChecks() {
  const android = path.join(root, 'chat-app');
  if (!fs.existsSync(android)) return;
  const ts = require(path.join(android, 'node_modules/typescript'));
  const ar = (file) => fs.readFileSync(path.join(android, file), 'utf8');
  let response = { providerConfigured: true, items: [], nextOffset: null };
  const requests = [];
  const api = { apiRequest: async (url) => { requests.push(url); return response; } };
  const compile = (file) => {
    const exports = {};
    vm.runInNewContext(ts.transpileModule(ar(file), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    }).outputText, { exports, URL, URLSearchParams, require: (name) => {
      assert.equal(name, './api/client'); return api;
    } });
    return exports;
  };
  const catalog = compile('src/data/stickers.ts');
  assert.equal(catalog.stickerCategories.length, 1);
  assert.equal(catalog.allStickers.length, 12);
  assert.deepEqual(Array.from(catalog.allStickers, (s) => s.stickerId), swiftIDs);
  assert.equal(catalog.isKnownSticker('chitchat-default', '../../asset'), false);
  assert.equal(catalog.isKnownSticker('other', 'heart'), false);
  const gifs = compile('src/services/gifs.ts');
  assert.equal(gifs.isAllowedGifURL('https://media2.giphy.com/a.gif'), true);
  for (const url of [null, {}, '', 'http://media.giphy.com/a.gif', 'https://evil.test/a.gif',
    'file:///a.gif', 'https://media.giphy.com.evil.test/a.gif', 'https://u:p@media.giphy.com/a.gif']) {
    assert.equal(gifs.isAllowedGifURL(url), false);
  }
  response = { providerConfigured: false, items: [], nextOffset: null, unavailableReason: 'missing_api_key' };
  assert.equal((await gifs.fetchTrendingGifs()).providerConfigured, false);
  assert.ok(requests[0].startsWith('/api/v1/gifs/trending?'));
  const signal = { aborted: true };
  await assert.rejects(gifs.searchGifs({ query: 'fixture', signal }), { name: 'AbortError' });
  response = { providerConfigured: true, items: [{ provider: 'giphy', providerId: 'synthetic',
    mediaUrl: 'https://media.giphy.com/a.gif', previewUrl: 'https://media.giphy.com/b.gif', width: 200, height: 100 }], nextOffset: 24 };
  const result = await gifs.searchGifs({ query: 'hello & bye', pos: '24' });
  assert.equal(new URL('https://unit.test' + requests.at(-1)).searchParams.get('q'), 'hello & bye');
  assert.equal(result.items[0].providerId, 'synthetic');
  assert.equal(result.nextPos, '24');
  const screen = ar('src/screens/ChatDetailScreen.tsx');
  const gifUI = ar('src/screens/GifPickerScreen.tsx');
  assert.match(gifUI, /setPreviewGif\(item\)/);
  assert.match(gifUI, /handleConfirmGif/);
  assert.match(gifUI, /280/);
  assert.match(gifUI, /temporarily unavailable/);
  assert.match(ar('src/screens/StickerPickerScreen.tsx'), /Alert.alert\('Send sticker\?'/);
  assert.match(ar('src/screens/StickerPickerScreen.tsx'), /<StickerArt/);
  assert.doesNotMatch(ar('src/screens/StickerPickerScreen.tsx'), /Get More Stickers|Sticker store/);
  for (const name of ['sendGifMessage', 'sendStickerMessage']) {
    const body = screen.slice(screen.indexOf(`const ${name}`));
    assert.match(body, /createClientSendId\(\)[\s\S]*enqueuePendingSend/);
  }
  assert.match(screen, /GifMessageImage/);
  assert.match(screen, /GIF unavailable/);
  assert.match(screen, /Sticker unavailable/);
  assert.match(screen, /sendPendingMessage\(item.clientSendId\)/);
  assert.doesNotMatch(ar('src/services/gifs.ts'), /TENOR_KEY|API_KEY|FALLBACK_GIFS/);
  console.log('Android catalog parity, provider adapter behavior, safe URLs, unavailable state, preview and pending-send checks passed.');
}

androidChecks().then(() => console.log('Native GIF/sticker source, rendering lifecycle and PBX checks passed; device testing remains required.'))
  .catch((error) => { console.error(error); process.exitCode = 1; });
