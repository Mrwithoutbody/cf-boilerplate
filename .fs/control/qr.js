// Rysuje kod QR z URL w terminalu — do zeskanowania telefonem.
// Użycie: node qr.js https://coś.trycloudflare.com
import qrcode from 'qrcode-terminal';

const url = process.argv[2];
if (!url) { console.error('qr.js: brak URL'); process.exit(1); }

qrcode.generate(url, { small: true }, q => {
  process.stdout.write('\n' + q + '\n');
  process.stdout.write('  Zeskanuj telefonem  ·  albo otwórz: ' + url + '\n\n');
});
