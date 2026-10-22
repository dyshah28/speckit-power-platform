import { test, expect } from '@playwright/test';
import { L, byLabel, openApp, requireAuth, signInAs, PEOPLE } from '../helpers/app';

/**
 * Layer 2 · US1-AC5 unregistered users see no data (Constitution V).
 * Types an email that is NOT in the Employees table (PEOPLE.unregistered).
 */
test.describe('US1-AC5 · unregistered user', () => {
  requireAuth();

  test('US1-AC5 an unregistered email sees the not-registered message and no data', async ({ page }) => {
    const app = await openApp(page);
    await signInAs(app, PEOPLE.unregistered);
    await expect(byLabel(app, L.notRegistered)).toBeVisible();
    await expect(byLabel(app, L.thisWeek)).toBeHidden();
    await expect(byLabel(app, L.goApprovals)).toBeHidden();
  });
});
