import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import AutoSubmitController from "../../../app/javascript/controllers/auto_submit_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `<select data-controller="auto-submit" name="sort">
  <option value="title">Title</option>
  <option value="author">Author</option>
</select>`;

describe("AutoSubmitController", () => {
  let app;

  beforeEach(() => {
    globalThis.Turbo = { visit: vi.fn() };
  });

  afterEach(() => {
    app?.stop();
    setBody("");
    delete globalThis.Turbo;
  });

  test("change event triggers Turbo.visit with the element's name and value", async () => {
    app = mount("auto-submit", AutoSubmitController, TEMPLATE);
    await flush();

    const select = document.querySelector("select");
    select.value = "author";
    select.dispatchEvent(new Event("change", { bubbles: true }));

    expect(Turbo.visit).toHaveBeenCalledOnce();
    const url = new URL(Turbo.visit.mock.calls[0][0]);
    expect(url.searchParams.get("sort")).toBe("author");
    expect(Turbo.visit.mock.calls[0][1]).toEqual({ action: "replace" });
  });

  test("disconnect removes the change listener", async () => {
    app = mount("auto-submit", AutoSubmitController, TEMPLATE);
    await flush();

    const select = document.querySelector("select");
    const ctrl = app.getControllerForElementAndIdentifier(select, "auto-submit");
    ctrl.disconnect();

    select.value = "author";
    select.dispatchEvent(new Event("change", { bubbles: true }));
    expect(Turbo.visit).not.toHaveBeenCalled();
  });

  test("multiple changes each trigger Turbo.visit", async () => {
    app = mount("auto-submit", AutoSubmitController, TEMPLATE);
    await flush();

    const select = document.querySelector("select");
    select.value = "author";
    select.dispatchEvent(new Event("change", { bubbles: true }));
    select.value = "title";
    select.dispatchEvent(new Event("change", { bubbles: true }));

    expect(Turbo.visit).toHaveBeenCalledTimes(2);
  });
});
