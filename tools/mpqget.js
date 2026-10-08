// Extracts files from the client's archives (newest patch that carries each
// wins) into an output dir, or with --check just reports which archive has it.
//   electron mpqget.js <Data dir> <out dir|--check> <listfile of names>
const path = require('path');
const fs = require('fs');
// stormlib-node built against Electron's ABI (OctoLauncher's node_modules has one)
const storm = require(process.env.STORMLIB_NODE || 'D:/stuff/OctoLauncher-src/octolauncher/node_modules/stormlib-node');
const [data, out, list] = process.argv.slice(2);
const rank = f => {
	const m = f.toLowerCase().match(/^patch-([a-z0-9])\.mpq$/);
	if (m) return /[a-z]/.test(m[1]) ? 1000 + m[1].charCodeAt(0) : 500 + Number(m[1]);
	if (f.toLowerCase() === 'patch.mpq') return 100;
	return f.toLowerCase().endsWith('.mpq') ? 1 : -1;
};
const order = fs.readdirSync(data).filter(f => rank(f) > 0).sort((a, b) => rank(b) - rank(a));
const handles = order.map(f => [f, storm.SFileOpenArchive(path.join(data, f), 0x100)]);
const result = {};
for (const name of fs.readFileSync(list, 'utf8').split(/\r?\n/).filter(Boolean)) {
	result[name] = null;
	for (const [f, h] of handles) {
		if (!storm.SFileHasFile(h, name)) continue;
		result[name] = f;
		if (out !== '--check') {
			const fh = storm.SFileOpenFileEx(h, name, 0);
			const buf = new ArrayBuffer(Number(storm.SFileGetFileSize(fh)));
			storm.SFileReadFile(fh, buf);
			storm.SFileCloseFile(fh);
			const dest = path.join(out, ...name.split(String.fromCharCode(92)));
			fs.mkdirSync(path.dirname(dest), { recursive: true });
			fs.writeFileSync(dest, Buffer.from(buf));
		}
		break;
	}
}
for (const [, h] of handles) storm.SFileCloseArchive(h);
console.log(JSON.stringify(result));
