import { chromium } from "playwright";

const headless = process.env.HEADLESS === "1";
const logger = console;
const pfsensePassword = process.env.PFSENSE_PASSWORD;
const pfsenseUrl = process.env.PFSENSE_URL;
const pfsenseUsername = process.env.PFSENSE_USERNAME;

(async () => {
	const browser = await chromium.launch({ headless });
	const context = await browser.newContext({
		ignoreHTTPSErrors: true,
	});
	const page = await context.newPage();
	try {
		await page.goto(pfsenseUrl, { waitUntil: "networkidle" });
		await page.locator('input[name="usernamefld"]').fill(pfsenseUsername);
		await page.locator('input[name="passwordfld"]').fill(pfsensePassword);
		await page.locator('input[name="login"]').click();
		await page.waitForLoadState("networkidle");
		if (page.url().includes("wizard.php")) {
			await page.goto(`${pfsenseUrl}/system_advanced_admin.php`, {
				waitUntil: "networkidle",
			});
		}
		await page.goto(`${pfsenseUrl}/system_advanced_admin.php`, {
			waitUntil: "networkidle",
		});
		const sshField = page.locator('input[name="sshdEnabled"]');
		if ((await sshField.count()) > 0) {
			const isChecked = await sshField.isChecked();
			if (!isChecked) await sshField.check();
		}
		const saveButton = page.locator('button[name="save"]');
		if ((await saveButton.count()) > 0) {
			await saveButton.click();
		} else {
			const inputSave = page.locator('input[name="save"]');
			if ((await inputSave.count()) > 0) {
				await inputSave.click();
			}
		}
		await page.waitForLoadState("networkidle");
	} catch (err) {
		logger.error(err);
		await browser.close();
		process.exit(1);
	} finally {
		await browser.close();
	}
})();
