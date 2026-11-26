// G.711 mu-law, the 8 kHz codec of the telephone network.
const BIAS = 0x84;
const CLIP = 32635;

export function encodeSample(sample: number): number {
  const sign = sample < 0 ? 0x80 : 0;
  let s = Math.min(Math.abs(sample), CLIP) + BIAS;
  let exponent = 7;
  for (let mask = 0x4000; exponent > 0 && (s & mask) === 0; mask >>= 1) exponent--;
  const mantissa = (s >> (exponent + 3)) & 0x0f;
  return ~(sign | (exponent << 4) | mantissa) & 0xff;
}

export function decodeSample(byte: number): number {
  const u = ~byte & 0xff;
  const sample = (((u & 0x0f) << 3) + BIAS) << ((u >> 4) & 0x07);
  return (u & 0x80) === 0 ? sample - BIAS : BIAS - sample;
}
