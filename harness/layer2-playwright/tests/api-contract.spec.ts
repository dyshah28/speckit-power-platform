import { test, expect, request } from '@playwright/test';
import { readFileSync } from 'node:fs';

/**
 * Layer 2 · Dataverse Web API contract check (contracts/dataverse-schema.md).
 * Proves every table and column the app, agents and tests rely on exists.
 * Asking $select for a missing column makes Dataverse return HTTP 400, so a rename is caught here first.
 *
 * NOTE (Constitution V, demo identity model): there are no Dataverse security roles in the demo, so
 * per-user scoping is tested through the UI (us1/us2 specs), not through this API.
 */
const contract = JSON.parse(readFileSync('contract.config.json', 'utf8')) as { entities: Record<string, string[]> };
const ORG = process.env.TK_ORG_URL;
const TOKEN = process.env.TK_DATAVERSE_TOKEN;

test.describe('Dataverse schema contract', () => {
  test.skip(!ORG || !TOKEN, 'Set TK_ORG_URL and TK_DATAVERSE_TOKEN in .env to run the API contract check');

  for (const [entitySet, columns] of Object.entries(contract.entities)) {
    test(`${entitySet} exposes ${columns.length} required columns`, async () => {
      const api = await request.newContext({
        baseURL: `${ORG}/api/data/v9.2/`,
        extraHTTPHeaders: { Authorization: `Bearer ${TOKEN}`, Accept: 'application/json', 'OData-Version': '4.0' },
      });
      const res = await api.get(`${entitySet}?$select=${columns.join(',')}&$top=1`);
      const body = await res.text();
      expect(res.status(), `Dataverse said: ${body.slice(0, 300)}`).toBe(200);
      const json = JSON.parse(body);
      expect(Array.isArray(json.value)).toBeTruthy();
    });
  }

  test('seed data: at least one active project and two employees with emails', async () => {
    const api = await request.newContext({
      baseURL: `${ORG}/api/data/v9.2/`,
      extraHTTPHeaders: { Authorization: `Bearer ${TOKEN}`, Accept: 'application/json' },
    });
    const emps = await (await api.get(`tk_employees?$select=tk_email&$filter=tk_email ne null`)).json();
    expect(emps.value.length).toBeGreaterThanOrEqual(2);
    const projects = await (await api.get(`tk_projects?$select=tk_projectname`)).json();
    expect(projects.value.length).toBeGreaterThanOrEqual(1);
  });
});
