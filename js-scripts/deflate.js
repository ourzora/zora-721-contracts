import { deflateRawSync } from 'zlib';


const text = Buffer.from(process.argv[2], 'utf-8');
console.log({text})
const sizeDecompressed = text.toString('hex').length / 2;

const compressed = deflateRawSync(text).toString('hex');
const sizeCompressed = compressed.length / 2;
console.log({sizeDecompressed, sizeCompressed});

console.log(compressed);
