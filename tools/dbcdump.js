// Dumps DBFilesClient\<name>.dbc from the client's archives (the newest patch
// that carries it wins, as in game) as JSON rows of raw 32-bit fields, each
// also offered as a float and, where it points into the string block, a string.
//
//   set ELECTRON_RUN_AS_NODE=1 && electron dbcdump.js <client Data dir> <Name>
const path = require('path');
const fs = require('fs');
// stormlib-node built against Electron's ABI (OctoLauncher's node_modules has one)
const storm = require(process.env.STORMLIB_NODE || 'D:/stuff/OctoLauncher-src/octolauncher/node_modules/stormlib-node');

const [data, name] = process.argv.slice(2);
const rank = f => {
	const m = f.toLowerCase().match(/^patch-([a-z0-9])\.mpq$/);
	if (m) return /[a-z]/.test(m[1]) ? 1000 + m[1].charCodeAt(0) : 500 + Number(m[1]);
	if (f.toLowerCase() === 'patch.mpq') return 100;
	if (f.toLowerCase() === 'dbc.mpq') return 1;
	return -1;
};
const order = fs.readdirSync(data).filter(f => rank(f) > 0).sort((a, b) => rank(b) - rank(a));
const file = 'DBFilesClient' + String.fromCharCode(92) + name + '.dbc';
const carriers = [];
let found;
for (const f of order) {
	const h = storm.SFileOpenArchive(path.join(data, f), 0x100);
	try {
		if (!storm.SFileHasFile(h, file)) continue;
		carriers.push(f);
		if (found) continue;
		const fh = storm.SFileOpenFileEx(h, file, 0);
		const buf = new ArrayBuffer(Number(storm.SFileGetFileSize(fh)));
		storm.SFileReadFile(fh, buf);
		storm.SFileCloseFile(fh);
		found = { from: f, buf: Buffer.from(buf) };
	} finally {
		storm.SFileCloseArchive(h);
	}
}
if (!found) throw new Error('not found: ' + file);
const buf = found.buf;
if (buf.toString('ascii', 0, 4) !== 'WDBC') throw new Error('not a DBC');
const records = buf.readUInt32LE(4), fields = buf.readUInt32LE(8), size = buf.readUInt32LE(12), strsize = buf.readUInt32LE(16);
const strings = 20 + records * size;
const rows = [];
for (let r = 0; r < records; r++) {
	const o = 20 + r * size, row = [];
	for (let i = 0; i < fields; i++) row.push(buf.readInt32LE(o + 4 * i));
	rows.push(row);
}
const str = off => buf.toString('utf8', strings + off, buf.indexOf(0, strings + off));
const flt = v => { const b = Buffer.alloc(4); b.writeInt32LE(v); return b.readFloatLE(0); };
console.log(JSON.stringify({ from: found.from, carriers, records, fields, size, strsize,
	rows, str: Object.fromEntries([...new Set(rows.flat())].filter(v => v > 0 && v < strsize && buf[strings + v - 1] === 0).map(v => [v, str(v)])),
	flt: Object.fromEntries([...new Set(rows.flat())].map(v => [v, flt(v)])) }));
