// Welcome text written into the terminal on connect. Plain letters coloured with a 24-bit ANSI gradient (the logo's
// cyan to indigo): no block or box-drawing characters, so it looks the same in every font and on narrow terminals.
const FROM = [8, 169, 239];
const TO = [58, 63, 224];
const lerp = (a, b, t) => Math.round(a + (b - a) * t);

function gradient(text) {
  const n = Math.max(1, text.length - 1);
  return [...text].map((ch, i) => {
    const t = i / n;
    return `\x1b[1;38;2;${lerp(FROM[0], TO[0], t)};${lerp(FROM[1], TO[1], t)};${lerp(FROM[2], TO[2], t)}m${ch}`;
  }).join('') + '\x1b[0m';
}

// welcome('Navigating the filesystem') -> three short lines for the top of the terminal.
function welcome(labTitle) {
  const title = String(labTitle || '').replace(/[\x00-\x1f\x7f]/g, '');
  return [
    '',
    `  ${gradient('HIRESNIX LABS')}`,
    `  \x1b[1;97m${title}\x1b[0m`,
    '  \x1b[2mType your commands below. Happy learning!\x1b[0m',
    '',
  ].join('\r\n');
}

module.exports = { welcome, gradient };
