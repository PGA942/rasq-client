const Codec = require('./codec.js');
const crypto = require('crypto');
const S = 400;
function src() { const d = new Uint8ClampedArray(S*S*4); for (let y=0;y<S;y++) for (let x=0;x<S;x++){ const i=(y*S+x)*4; d[i]=Math.round(x*255/399); d[i+1]=Math.round(y*255/399); d[i+2]=Math.round((x+y)*127/399); d[i+3]=255;} return d; }
const theme = { bgMode:'grad', grad:2, bg:[17,34,68], text:[255,255,255], accent:[0,204,255], particle:3, amount:10, speed:5, hint:5 };
const poly = (n, ro, ri) => { const p = []; for (let i = 0; i < n * 2; i++) { const a = -Math.PI / 2 + i * Math.PI / n, r = i % 2 ? ri : ro; p.push([i ? 'L' : 'M', Math.round(16 + Math.cos(a) * r), Math.round(16 + Math.sin(a) * r)]); } p.push(['Z']); return p; };
const ext = { shapes:[poly(5,14,6), [['M',16,29],['Q',1,17,4,9],['Q',7,2,16,9],['Q',25,2,28,9],['Q',31,17,16,29],['Z']]], paths:[[16,0,16,16,16,31],[16,31,7,16,20,0]], angle:6, anim:1, animSpeed:3,
  slots:[{trig:0,shape:0,path:0,rand:15,arand:1,ea:0,eb:1,mix:2,sway:2,spin:3},{trig:1,shape:1,path:1,rand:6,arand:8,ea:2,eb:1,mix:3,sway:4,spin:1}] };
const extUrl = { url: 'plugins.example.social/t/starfall' };
const out = {};
out.layout = { palCal: Codec.LAYOUT.palCal.length, palData: Codec.LAYOUT.palData.length, extCal: Codec.LAYOUT.extCal.length, extData: Codec.LAYOUT.extData.length, extBytes: Codec.LAYOUT.extBytes, extK: Codec.LAYOUT.extK,
  palCalBlocks: Codec.LAYOUT.palCal.map(c=>[c.b[0],c.b[1],c.ref]), palDataFirst: Codec.LAYOUT.palData.slice(0,8), extDataFirst: Codec.LAYOUT.extData.slice(0,8) };
out.symbols = Codec.themeToSymbols(theme); out.text = Codec.symbolsToText(out.symbols);
out.ramp = Codec.rampFor(theme.accent, false); out.rampMono = Codec.rampFor(theme.bg, true);
for (const [name, e] of [['plain', null], ['ext', ext], ['url', extUrl]]) {
  const d = src(); const info = Codec.encode(d, { theme, ext: e, ramp: out.ramp });
  out[name] = { info: { text: info.text, palBlocks: info.palBlocks, extBlocks: info.extBlocks, extUsed: info.extUsed, extCapacity: info.extCapacity }, sha256: crypto.createHash('sha256').update(Buffer.from(d.buffer)).digest('hex'),
    px: [[0,0],[3,3],[12,4],[60,10],[395,395],[200,200],[30,90]].map(([x,y])=>{const i=(y*S+x)*4;return [x,y,d[i],d[i+1],d[i+2]];}) };
  const r = Codec.decode(d, S, S); out[name].decoded = { ok: r.ok, text: r.text, theme: r.theme, palCorrected: r.palCorrected, ext: r.ext && { ok: r.ext.ok, data: r.ext.data, corrected: r.ext.corrected } };
  // corrupt: overwrite 4 palette data blocks with black and 20 ext data blocks with first ramp level
  const c = Uint8ClampedArray.from(d);
  const fill = (bx,by,col)=>{ for (let y=by*8;y<by*8+8;y++) for (let x=bx*8;x<bx*8+8;x++){const i=(y*S+x)*4;c[i]=col[0];c[i+1]=col[1];c[i+2]=col[2];}};
  [0,7,15,22].forEach(k=>fill(...Codec.LAYOUT.palData[k],[236,236,20]));
  if (e) for (let k=0;k<40;k+=2) fill(...Codec.LAYOUT.extData[k], out.ramp[0]);
  const rc = Codec.decode(c, S, S); out[name].corrupted = { ok: rc.ok, text: rc.text, palCorrected: rc.palCorrected, ext: rc.ext && { ok: rc.ext.ok, corrected: rc.ext.corrected } };
}
console.log(JSON.stringify(out));
