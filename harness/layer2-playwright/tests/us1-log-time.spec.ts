import { test, expect, request } from '@playwright/test';
import { L, byLabel, waitForWeek, mutationsAllowed, openApp, pickCombo, requireAuth, setNumber, testMarker, signInAs, PEOPLE, weekTotal } from '../helpers/app';

/**
 * Layer 2 · US1 "Log my time in the app" (spec.md, User Story 1).
 * Runs as the employee: types PEOPLE.employee on the sign-in panel. Each test maps to an acceptance scenario.
 * Entries created here carry a "PW-TEST" note so they are easy to find and delete.
 */
test.describe('US1 · Log my time', () => {
  requireAuth();

  // Remove the entries these tests create (notes start with "PW-TEST") so the demo week stays clean
  test.afterAll(async () => {
    const org = process.env.TK_ORG_URL, token = process.env.TK_DATAVERSE_TOKEN;
    if (!org || !token) return;
    const api = await request.newContext({ baseURL: `${org}/api/data/v9.2/`, extraHTTPHeaders: { Authorization: `Bearer ${token}`, Accept: 'application/json' } });
    const rows = (await (await api.get(`tk_timeentries?$select=tk_timeentryid&$filter=startswith(tk_notes,'PW-TEST')`)).json()).value ?? [];
    for (const r of rows) await api.delete(`tk_timeentries(${r.tk_timeentryid})`);
  });

  test('US1-AC1 logging a valid entry adds a Draft row and updates the week total', async ({ page }) => {
    const app = await openApp(page);
    await signInAs(app, PEOPLE.employee);
    await waitForWeek(app);
    await expect(byLabel(app, L.signedInUser)).toContainText(process.env.TK_EMPLOYEE_NAME ?? 'Priya Patel');
    // FR-018: friendly greeting with the first name, and visible progress toward weekly capacity
    const firstName = (process.env.TK_EMPLOYEE_NAME ?? 'Priya Patel').split(' ')[0];
    await expect(byLabel(app, L.greeting)).toHaveText(new RegExp(`^Good (morning|afternoon|evening), ${firstName}`));
    await expect(byLabel(app, L.weekProgress)).toBeVisible();

    const before = await weekTotal(app);
    await pickCombo(app, L.project, 'Contoso Migration');
    // Work date defaults to today (inside the current week); not changed here to keep the test stable.
    await setNumber(app, L.hours, 1.5);
    await byLabel(app, L.notes).fill(testMarker());
    await byLabel(app, L.saveEntry).click();

    await expect(byLabel(app, L.entryError)).toBeHidden();
    await expect.poll(() => weekTotal(app)).toBeCloseTo(before + 1.5, 2);
    await expect(byLabel(app, L.thisWeek)).toContainText('Contoso Migration');
    await expect(byLabel(app, L.thisWeek)).toContainText('Draft');
  });

  test('US1-AC2 hours outside 0.25–12 are rejected', async ({ page }) => {
    const app = await openApp(page);
    await signInAs(app, PEOPLE.employee);
    await waitForWeek(app);
    await pickCombo(app, L.project, 'Fabrikam Portal');

    for (const bad of [13, 0]) {
      const before = await weekTotal(app);
      await setNumber(app, L.hours, bad);
      await byLabel(app, L.saveEntry).click();
      await expect(byLabel(app, L.entryError)).toBeVisible();
      expect(await weekTotal(app)).toBeCloseTo(before, 2);   // nothing saved
    }
  });

  test('US1-AC3 a day cannot exceed 24 hours', async ({ page }) => {
    test.skip(!mutationsAllowed(), 'Creates up to 24 h of entries today; set TK_ALLOW_MUTATIONS=1 to run');
    const app = await openApp(page);
    await signInAs(app, PEOPLE.employee);
    await waitForWeek(app);
    await pickCombo(app, L.project, 'Internal Training');
    for (let i = 0; i < 2; i++) {
      await setNumber(app, L.hours, 12);
      await byLabel(app, L.notes).fill(testMarker());
      await byLabel(app, L.saveEntry).click();
    }
    await setNumber(app, L.hours, 0.25);
    await byLabel(app, L.saveEntry).click();
    await expect(byLabel(app, L.entryError)).toContainText(/24/);
  });

  test('US1-AC4 submitting the week turns Draft entries into Submitted', async ({ page }) => {
    test.skip(!mutationsAllowed(), 'Submits the whole demo week; set TK_ALLOW_MUTATIONS=1 to run');
    const app = await openApp(page);
    await signInAs(app, PEOPLE.employee);
    await waitForWeek(app);
    await byLabel(app, L.submitWeek).click();
    await expect(byLabel(app, L.thisWeek)).not.toContainText('Draft');
    await expect(byLabel(app, L.thisWeek)).toContainText('Submitted');
  });
});
