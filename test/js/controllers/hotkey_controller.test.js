import { afterEach, describe, expect, test } from "vitest";
import HotkeyController from "../../../app/javascript/controllers/hotkey_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `<form>
  <input id="field" type="text">
  <textarea id="notes"></textarea>
  <select id="choice"><option>One</option></select>
  <div id="rich" role="textbox"></div>
  <button data-controller="hotkey" data-hotkey-key-value="s">Save and next</button>
</form>`;

function press(key, options = {}) {
  document.dispatchEvent(new KeyboardEvent("keydown", { key, ...options }));
}

describe("HotkeyController", () => {
  let app;
  let clicks;

  function trackClicks() {
    clicks = 0;
    document.querySelector("button").addEventListener("click", () => {
      clicks += 1;
    });
  }

  afterEach(() => {
    // The controller adds a document-level keydown listener in connect();
    // app.stop() halts the observers but does not disconnect mounted contexts,
    // so disconnect each controller explicitly to avoid leaking listeners between tests.
    app?.controllers.forEach((controller) => controller.disconnect());
    app?.stop();
    setBody("");
  });

  test("pressing the configured key clicks the element", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    press("s");
    expect(clicks).toBe(1);
  });

  test("fires under Caps Lock (uppercase key, no Shift)", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    press("S");
    expect(clicks).toBe(1);
  });

  test("Shift is treated as a modifier and suppresses the hotkey", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    press("S", { shiftKey: true });
    expect(clicks).toBe(0);
  });

  test("a different key does nothing", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    press("a");
    expect(clicks).toBe(0);
  });

  test("modifier keys suppress the hotkey", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    press("s", { metaKey: true });
    press("s", { ctrlKey: true });
    press("s", { altKey: true });
    expect(clicks).toBe(0);
  });

  test("does not fire while typing in form fields", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    for (const id of ["field", "notes", "choice", "rich"]) {
      const target = document.getElementById(id);
      target.dispatchEvent(new KeyboardEvent("keydown", { key: "s", bubbles: true }));
    }
    expect(clicks).toBe(0);
  });

  test("disconnect removes the document listener", async () => {
    app = mount("hotkey", HotkeyController, TEMPLATE);
    await flush();
    trackClicks();

    const button = document.querySelector("button");
    const ctrl = app.getControllerForElementAndIdentifier(button, "hotkey");
    ctrl.disconnect();

    press("s");
    expect(clicks).toBe(0);
  });
});
