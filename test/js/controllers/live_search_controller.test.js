import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import LiveSearchController from "../../../app/javascript/controllers/live_search_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `<div data-controller="live-search">
  <input data-live-search-target="input" data-action="input->live-search#search" type="text" />
  <button data-action="click->live-search#clear">Clear</button>
</div>`;

describe("LiveSearchController", () => {
  let app;

  beforeEach(() => {
    globalThis.Turbo = { visit: vi.fn() };
  });

  afterEach(() => {
    vi.useRealTimers();
    app?.stop();
    setBody("");
    delete globalThis.Turbo;
  });

  test("search debounces and calls Turbo.visit with query param", async () => {
    app = mount("live-search", LiveSearchController, TEMPLATE);
    await flush();
    vi.useFakeTimers();

    const input = document.querySelector("input");
    input.value = "hobbit";
    input.dispatchEvent(new Event("input", { bubbles: true }));

    expect(Turbo.visit).not.toHaveBeenCalled();
    vi.advanceTimersByTime(300);

    expect(Turbo.visit).toHaveBeenCalledOnce();
    const url = new URL(Turbo.visit.mock.calls[0][0]);
    expect(url.searchParams.get("q")).toBe("hobbit");
    expect(Turbo.visit.mock.calls[0][1]).toEqual({ action: "replace" });
  });

  test("rapid inputs only trigger one Turbo.visit", async () => {
    app = mount("live-search", LiveSearchController, TEMPLATE);
    await flush();
    vi.useFakeTimers();

    const input = document.querySelector("input");

    input.value = "h";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    vi.advanceTimersByTime(100);

    input.value = "ho";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    vi.advanceTimersByTime(100);

    input.value = "hob";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    vi.advanceTimersByTime(300);

    expect(Turbo.visit).toHaveBeenCalledOnce();
    const url = new URL(Turbo.visit.mock.calls[0][0]);
    expect(url.searchParams.get("q")).toBe("hob");
  });

  test("empty search removes the q param", async () => {
    app = mount("live-search", LiveSearchController, TEMPLATE);
    await flush();
    vi.useFakeTimers();

    const input = document.querySelector("input");
    input.value = "  ";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    vi.advanceTimersByTime(300);

    expect(Turbo.visit).toHaveBeenCalledOnce();
    const url = new URL(Turbo.visit.mock.calls[0][0]);
    expect(url.searchParams.has("q")).toBe(false);
  });

  test("clear empties the input and triggers a search", async () => {
    app = mount("live-search", LiveSearchController, TEMPLATE);
    await flush();
    vi.useFakeTimers();

    const input = document.querySelector("input");
    input.value = "tolkien";
    document.querySelector("button").click();

    expect(input.value).toBe("");
    vi.advanceTimersByTime(300);

    expect(Turbo.visit).toHaveBeenCalledOnce();
    const url = new URL(Turbo.visit.mock.calls[0][0]);
    expect(url.searchParams.has("q")).toBe(false);
  });

  test("disconnect cancels pending timeout", async () => {
    app = mount("live-search", LiveSearchController, TEMPLATE);
    await flush();
    vi.useFakeTimers();

    const wrapper = document.querySelector("[data-controller='live-search']");
    const ctrl = app.getControllerForElementAndIdentifier(wrapper, "live-search");

    const input = document.querySelector("input");
    input.value = "test";
    input.dispatchEvent(new Event("input", { bubbles: true }));

    ctrl.disconnect();
    vi.advanceTimersByTime(300);

    expect(Turbo.visit).not.toHaveBeenCalled();
  });
});
