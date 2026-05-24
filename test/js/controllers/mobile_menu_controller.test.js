import { afterEach, describe, expect, test } from "vitest";
import MobileMenuController from "../../../app/javascript/controllers/mobile_menu_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `
<div data-controller="mobile-menu">
  <div class="site-header__bar">
    <button id="trigger" data-action="mobile-menu#open" data-mobile-menu-target="trigger" aria-expanded="false">Open</button>
  </div>
  <div class="mobile-menu" data-mobile-menu-target="panel" role="dialog" aria-modal="true" aria-label="Menu" aria-hidden="true">
    <a id="link-first" href="/first">First</a>
    <a id="link-second" href="/second">Second</a>
    <button id="close-btn" data-action="mobile-menu#close">Close</button>
  </div>
</div>
<main class="site-main">Main content</main>`;

function panel() {
  return document.querySelector("[data-mobile-menu-target='panel']");
}

function trigger() {
  return document.getElementById("trigger");
}

describe("MobileMenuController", () => {
  let app;

  afterEach(() => {
    app?.stop();
    setBody("");
  });

  test("open adds is-open class", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    expect(panel().classList.contains("is-open")).toBe(true);
  });

  test("close removes is-open class", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    document.getElementById("close-btn").click();
    expect(panel().classList.contains("is-open")).toBe(false);
  });

  test("open moves focus to the first focusable element inside the panel", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    await flush();
    expect(document.activeElement.id).toBe("link-first");
  });

  test("close restores focus to the element that opened the menu", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().focus();
    trigger().click();
    document.getElementById("close-btn").click();
    expect(document.activeElement.id).toBe("trigger");
  });

  test("Escape key closes the menu", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().focus();
    trigger().click();
    await flush();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    expect(panel().classList.contains("is-open")).toBe(false);
    expect(document.activeElement.id).toBe("trigger");
  });

  test("Tab from last focusable wraps to first", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    await flush();
    document.getElementById("close-btn").focus();

    const event = new KeyboardEvent("keydown", { key: "Tab", bubbles: true, cancelable: true });
    document.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement.id).toBe("link-first");
  });

  test("Shift+Tab from first focusable wraps to last", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    await flush();
    document.getElementById("link-first").focus();

    const event = new KeyboardEvent("keydown", {
      key: "Tab",
      shiftKey: true,
      bubbles: true,
      cancelable: true,
    });
    document.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement.id).toBe("close-btn");
  });

  test("calling open twice does not duplicate listeners", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    trigger().click();

    document.getElementById("close-btn").click();
    expect(panel().classList.contains("is-open")).toBe(false);
  });

  test("open sets aria-expanded on trigger and removes aria-hidden from panel", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    expect(trigger().getAttribute("aria-expanded")).toBe("true");
    expect(panel().hasAttribute("aria-hidden")).toBe(false);
  });

  test("close sets aria-expanded to false and aria-hidden on panel", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    document.getElementById("close-btn").click();
    expect(trigger().getAttribute("aria-expanded")).toBe("false");
    expect(panel().getAttribute("aria-hidden")).toBe("true");
  });

  test("open sets inert on background elements", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    expect(document.querySelector(".site-header__bar").hasAttribute("inert")).toBe(true);
    expect(document.querySelector("main.site-main").hasAttribute("inert")).toBe(true);
  });

  test("close removes inert from background elements", async () => {
    app = mount("mobile-menu", MobileMenuController, TEMPLATE);
    await flush();

    trigger().click();
    document.getElementById("close-btn").click();
    expect(document.querySelector(".site-header__bar").hasAttribute("inert")).toBe(false);
    expect(document.querySelector("main.site-main").hasAttribute("inert")).toBe(false);
  });
});
