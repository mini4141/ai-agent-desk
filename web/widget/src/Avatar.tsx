// SVG talking avatar. Mouth shape follows Polly viseme codes (cloud) or a random vowel (local fallback).
const MOUTH: Record<string, { open: number; wide: number }> = {
  sil: { open: 0.02, wide: 0.5 }, p: { open: 0, wide: 0.45 }, t: { open: 0.25, wide: 0.6 }, S: { open: 0.3, wide: 0.4 },
  T: { open: 0.2, wide: 0.5 }, f: { open: 0.15, wide: 0.6 }, k: { open: 0.3, wide: 0.5 }, i: { open: 0.2, wide: 0.95 },
  r: { open: 0.3, wide: 0.4 }, s: { open: 0.15, wide: 0.8 }, u: { open: 0.3, wide: 0.25 }, "@": { open: 0.4, wide: 0.5 },
  a: { open: 1, wide: 0.7 }, e: { open: 0.6, wide: 0.8 }, E: { open: 0.7, wide: 0.8 }, o: { open: 0.7, wide: 0.35 }, O: { open: 0.8, wide: 0.5 },
};

export function Avatar({ viseme, speaking }: { viseme: string | null; speaking: boolean }) {
  const m = MOUTH[viseme ?? "sil"] ?? MOUTH.sil;
  const rx = 14 + 22 * m.wide;
  const ry = 2 + 20 * m.open;
  return (
    <svg viewBox="0 0 200 200" className="avatar" role="img" aria-label="avatar" data-testid="avatar" data-viseme={viseme ?? "sil"} data-speaking={speaking}>
      <circle cx="100" cy="100" r="86" fill="#ffe0bd" stroke="#e0b88a" strokeWidth="3" />
      <path d="M22 88 C 30 20, 170 20, 178 88 C 150 50, 50 50, 22 88 Z" fill="#3b2a20" />
      <g className="eyes">
        <ellipse cx="68" cy="95" rx="9" ry="11" fill="#fff" /><circle cx="68" cy="97" r="5" fill="#2b2b2b" />
        <ellipse cx="132" cy="95" rx="9" ry="11" fill="#fff" /><circle cx="132" cy="97" r="5" fill="#2b2b2b" />
      </g>
      <path d="M96 108 Q100 124 104 108" stroke="#d99b6c" strokeWidth="3" fill="none" />
      <ellipse cx="100" cy="142" rx={rx} ry={ry} fill="#7a2430" stroke="#5a1822" strokeWidth="2" />
    </svg>
  );
}
