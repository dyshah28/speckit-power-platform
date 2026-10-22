import { expect, test, type FrameLocator, type Page } from '@playwright/test';
import { existsSync } from 'node:fs';

/**
 * Helpers for driving the Timekeeper canvas app in the Power Apps web player.
 * Controls are located ONLY by the AccessibleLabel values in
 * specs/001-timekeeper-core/contracts/canvas-ui-contract.md.
 *
 * Microsoft's open-source toolkit (github.com/microsoft/power-platform-playwright-samples,
 * CanvasAppPage) can replace these helpers; the contract labels stay the same.
 */

export const L = {
  email: 'Email',
  continue: 'Continue',
  signOut: 'Sign out',
  signedInUser: 'Signed in user',
  greeting: 'Greeting',
  weekProgress: 'Week progress',
  notRegistered: 'Not registered message',
  goApprovals: 'Go to Approvals',
  goLogTime: 'Go to Log Time',
  weekTotal: 'Week total hours',
  thisWeek: 'This week entries',
  project: 'Project',
  workDate: 'Work date',
  hours: 'Hours',
  notes: 'Notes',
  saveEntry: 'Save entry',
  entryError: 'Entry error',
  submitWeek: 'Submit week',
  pending: 'Pending approvals',
  approve: 'Approve entry',
  reject: 'Reject entry',
  rejectionComment: 'Rejection comment',
  confirmRejection: 'Confirm rejection',
  rejectionError: 'Rejection error',
} as const;

/** Demo identities (Constitution V): the app is opened with one recorded Microsoft sign-in, then the person's email is typed. */
export const PEOPLE = {
  employee: process.env.TK_EMPLOYEE_EMAIL ?? 'priya@example.com',
  manager: process.env.TK_MANAGER_EMAIL ?? 'jordan@example.com',
  unregistered: process.env.TK_UNREGISTERED_EMAIL ?? 'nobody@example.com',
} as const;

/** Call at the top of a describe block: skips the whole block (before any browser starts) if the sign-in isn't recorded. */
export function requireAuth() {
  test.skip(!existsSync('auth/maker.json'), 'No recorded Microsoft sign-in. Run "npm run auth" once first.');
}

export async function openApp(page: Page): Promise<FrameLocator> {
  const url = process.env.TK_APP_URL;
  if (!url) throw new Error('TK_APP_URL is not set (see .env.example)');
  // The player caches the app package in localStorage; a recorded sign-in carries an old copy, so every publish would be invisible to tests.
  await page.addInitScript(() => { for (const k of Object.keys(localStorage)) if (/^(PAAppLoadCache|PAPreloadKey)/.test(k)) localStorage.removeItem(k); });
  await page.goto(url);
  // The canvas app renders inside this iframe in the web player.
  const app = page.frameLocator('iframe[name="fullscreen-app-host"]');
  return app;
}

export const byLabel = (app: FrameLocator, label: string) => app.getByLabel(label, { exact: true }).first();

/** Waits for the sign-in panel, types the email and continues. Ready when the banner or the not-registered panel shows. */
export async function signInAs(app: FrameLocator, email: string) {
  await expect(byLabel(app, L.email)).toBeVisible({ timeout: 90_000 });
  await byLabel(app, L.email).fill(email);
  await byLabel(app, L.continue).click();
  // The banner shows for everyone once signed in (the not-registered panel is in the DOM for registered users too)
  await expect(byLabel(app, L.signedInUser)).toBeVisible({ timeout: 30_000 });
}

/** Pick a value in a modern dropdown: open it and choose the matching option. */
export async function pickCombo(app: FrameLocator, label: string, value: string) {
  await byLabel(app, label).click();
  await app.getByRole('option', { name: new RegExp(value, 'i') }).first().click();
}

/** Canvas screens fill in piece by piece after a query (empty states flash first). Ready = read() returns the same value twice, 3 s apart. */
export async function settled<T>(read: () => Promise<T>) {
  let prev: unknown = Symbol();
  await expect.poll(async () => { const cur = JSON.stringify(await read()); const same = cur === prev; prev = cur; return same; },
    { timeout: 45_000, intervals: [3_000] }).toBe(true);
}

export const waitForWeek = (app: FrameLocator) => settled(() => weekTotal(app));

export async function setNumber(app: FrameLocator, label: string, value: number) {
  const input = byLabel(app, label);
  await input.fill(String(value));
  await input.press('Tab');
}

export async function weekTotal(app: FrameLocator): Promise<number> {
  // Text is "17.5 h  of 40 h": the first number is the week total
  const m = (await byLabel(app, L.weekTotal).innerText()).match(/\d+(\.\d+)?/);
  return Number(m?.[0] ?? 0);
}

export const testMarker = () => `PW-TEST ${new Date().toISOString().slice(0, 16)}`;
export const mutationsAllowed = () => process.env.TK_ALLOW_MUTATIONS === '1';
