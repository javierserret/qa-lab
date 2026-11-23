import { $, browser } from '@wdio/globals';

class StoreScreen {
    private nativeApp = false;
    private nativeId(name: string) {
        return $(`android=new UiSelector().resourceId("com.saucelabs.mydemoapp.android:id/${name}")`);
    }
    get backpack() { return $('android=new UiSelector().text("Sauce Labs Backpack")'); }
    get backpackImage() {
        return $('android=new UiSelector().text("Sauce Labs Backpack").fromParent(new UiSelector().resourceId("com.saucelabs.mydemoapp.android:id/productIV"))');
    }
    get addToCart() { return this.nativeApp ? this.nativeId('cartBt') : $('~Add To Cart button'); }
    get cart() { return this.nativeApp ? this.nativeId('cartRL') : $('~cart badge'); }
    get cartTitle() { return $('android=new UiSelector().text("My Cart")'); }
    get removeItem() { return this.nativeApp ? this.nativeId('removeBt') : $('android=new UiSelector().text("Remove Item")'); }
    get emptyCartMessage() { return this.nativeApp ? this.nativeId('noItemTitleTV') : $('android=new UiSelector().text("No Items" )'); }

    private async dismissCompatibilityDialog() {
        const title = $('android=new UiSelector().resourceId("android:id/alertTitle").text("Android App Compatibility")');
        if (await title.isDisplayed()) {
            // This warning can repeat for each activity; suppress it for this app.
            await $('android=new UiSelector().resourceId("android:id/button1").text("Don\'t Show Again")').click();
        }
    }

    async waitForProducts() {
        // Wait for either the compatibility dialog or the catalog, then dismiss the dialog.
        await browser.waitUntil(async () => {
            await this.dismissCompatibilityDialog();
            return this.backpack.isDisplayed();
        }, { timeout: 20000, timeoutMsg: 'Product catalog did not appear' });
        const packageName = await browser.getCurrentPackage();
        if (!['com.saucelabs.mydemoapp.android', 'com.saucelabs.mydemoapp.rn'].includes(packageName)) {
            throw new Error(`Unexpected app package: ${packageName}`);
        }
        this.nativeApp = packageName === 'com.saucelabs.mydemoapp.android';
    }

    async addBackpackToCart() {
        if (this.nativeApp) await this.backpackImage.click();
        else await this.backpack.click();
        await browser.waitUntil(async () => {
            await this.dismissCompatibilityDialog();
            return this.addToCart.isDisplayed();
        }, { timeout: 20000, timeoutMsg: 'Product details Add to Cart button did not appear' });
        await this.addToCart.click();
        await this.cart.click();
        await browser.waitUntil(async () => {
            await this.dismissCompatibilityDialog();
            return this.cartTitle.isDisplayed();
        }, { timeout: 20000, timeoutMsg: 'Cart screen did not appear' });
    }
}

export default new StoreScreen();
