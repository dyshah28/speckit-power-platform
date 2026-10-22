import { test, expect } from '@playwright/test';
import { L, byLabel, settled, mutationsAllowed, openApp, requireAuth, signInAs, PEOPLE } from '../helpers/app';

/**
 * Layer 2 · US2 "Approve my team's time" (spec.md, User Story 2).
 * Runs as the manager: types PEOPLE.manager on the sign-in panel.
 */
const reports = (process.env.TK_REPORT_NAMES ?? 'Priya Patel,Alex Kim').split(',').map((s) => s.trim());
const manager = process.env.TK_MANAGER_NAME ?? 'Jordan Lee';

test.describe('US2 · Approvals', () => {
  requireAuth();

  test('US2-AC1 manager sees only direct reports\' submitted entries', async ({ page }) => {
    const app = await openApp(page);
    await signInAs(app, PEOPLE.manager);
    await byLabel(app, L.goApprovals).click();
    const pending = byLabel(app, L.pending);
    const rows = pending.getByRole('listitem');
    // No pending entries hides the list (empty state): zero rows is a pass, there is nobody else's data to show
    await settled(async () => (await pending.isVisible()) ? await rows.count() : 0);

    const count = await rows.count();
    test.info().annotations.push({ type: 'pending-rows', description: String(count) });
    for (let i = 0; i < count; i++) {
      const text = await rows.nth(i).innerText();
      expect(reports.some((name) => text.includes(name)), `Row ${i} belongs to a non-report: ${text}`).toBeTruthy();
      expect(text).not.toContain(manager);   // never your own entries
    }
  });

  test('US2-AC3 rejecting without a comment is blocked', async ({ page }) => {
    const app = await openApp(page);
    await signInAs(app, PEOPLE.manager);
    await byLabel(app, L.goApprovals).click();
    const rows = byLabel(app, L.pending).getByRole('listitem');
    await settled(() => rows.count());
    test.skip((await rows.count()) === 0, 'No submitted entries to act on; submit a week as Priya first');

    await rows.first().getByLabel(L.reject, { exact: true }).click();
    await byLabel(app, L.rejectionComment).fill('');
    await byLabel(app, L.confirmRejection).click();
    await expect(byLabel(app, L.rejectionError)).toBeVisible();
  });

  test('US2-AC2 approving removes the entry from the pending list', async ({ page }) => {
    test.skip(!mutationsAllowed(), 'Approves a real demo entry; set TK_ALLOW_MUTATIONS=1 to run');
    const app = await openApp(page);
    await signInAs(app, PEOPLE.manager);
    await byLabel(app, L.goApprovals).click();
    const rows = byLabel(app, L.pending).getByRole('listitem');
    await settled(() => rows.count());
    const before = await rows.count();
    test.skip(before === 0, 'No submitted entries to approve');
    await rows.first().getByLabel(L.approve, { exact: true }).click();
    await expect(rows).toHaveCount(before - 1);
  });
});
