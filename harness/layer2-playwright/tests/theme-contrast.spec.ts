import { test, expect } from '@playwright/test';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Layer 2 · UI theme contract (contracts/ui-theme.md). No browser or sign-in needed.
 * 1. Every text/background pair meets WCAG AA (4.5:1); focus and UI accents meet 3:1.
 * 2. Pastel surfaces stay light and soft (not too bright or saturated).
 * 3. Screen files use theme tokens, not raw hex colours (hex is allowed only in App.pa.yaml / App.Formulas).
 */
const theme = JSON.parse(readFileSync('theme.tokens.json', 'utf8'));
const c: Record<string, string> = theme.colors;

const rgb = (hex: string) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
const lum = (hex: string) =>
  rgb(hex).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)).reduce((a, v, i) => a + v * [0.2126, 0.7152, 0.0722][i], 0);
const contrast = (a: string, b: string) => {
  const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};
// Lightness and chroma (colour intensity, 0 = grey .. 1 = fully vivid). Chroma matches perceived "brightness of colour"
// better than HSL saturation, which reports very light pastels as highly saturated.
const tone = (hex: string) => {
  const [r, g, b] = rgb(hex); const max = Math.max(r, g, b), min = Math.min(r, g, b);
  return { l: (max + min) / 2, chroma: max - min };
};

test.describe('Theme contract · Soft Pastel Light', () => {
  for (const [fg, bg] of theme.textPairs as [string, string][]) {
    test(`text ${fg} on ${bg} meets AA 4.5:1`, () => {
      expect(contrast(c[fg], c[bg])).toBeGreaterThanOrEqual(4.5);
    });
  }
  for (const [fg, bg] of theme.uiPairs as [string, string][]) {
    test(`UI ${fg} on ${bg} meets 3:1`, () => {
      expect(contrast(c[fg], c[bg])).toBeGreaterThanOrEqual(3);
    });
  }
  test('pastel surfaces are light and soft (lightness ≥ 85%, chroma ≤ 0.15)', () => {
    for (const name of theme.pastelSurfaces as string[]) {
      const { l, chroma } = tone(c[name]);
      expect.soft(l, `${name} too dark`).toBeGreaterThanOrEqual(0.85);
      expect.soft(chroma, `${name} too vivid`).toBeLessThanOrEqual(0.15);
    }
  });
  test('primary is muted, not neon (chroma ≤ 0.45)', () => {
    expect(tone(c.Primary).chroma).toBeLessThanOrEqual(0.45);
  });
  test('screen files use theme tokens, not raw hex colours', () => {
    const dir = join('..', '..', 'canvasapp');
    test.skip(!existsSync(dir), 'canvasapp/ not present');
    const screens = readdirSync(dir).filter((f) => f.endsWith('.pa.yaml') && !/^(App|_EditorState)\.pa\.yaml$/.test(f));
    for (const f of screens) {
      const src = readFileSync(join(dir, f), 'utf8');
      const hits = src.match(/ColorValue\(\s*"#[0-9A-Fa-f]{6}"|RGBA\(/g) ?? [];
      expect.soft(hits, `${f} hard-codes colours; use theme tokens from App.Formulas`).toEqual([]);
    }
  });
});
