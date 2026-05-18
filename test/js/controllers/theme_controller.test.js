import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import ThemeController, { STORAGE_KEY } from "../../../app/javascript/controllers/theme_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

describe("ThemeController", () => {
  let app;

  beforeEach(() => {
    document.documentElement.className = "";
    localStorage.clear();
  });

  afterEach(() => {
    app?.stop();
    setBody("");
    vi.restoreAllMocks();
  });

  test("shows the moon icon when starting in light mode", async () => {
    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme" data-action="click->theme#toggle">
         <span data-theme-target="icon"></span>
       </button>`
    );
    await flush();

    const icon = document.querySelector("[data-theme-target='icon']");
    expect(icon.textContent).toBe("☾");
  });

  test("shows the sun icon when starting in dark mode", async () => {
    document.documentElement.classList.add("dark");
    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme">
         <span data-theme-target="icon"></span>
       </button>`
    );
    await flush();

    const icon = document.querySelector("[data-theme-target='icon']");
    expect(icon.textContent).toBe("☀");
  });

  test("toggle adds the dark class, persists to localStorage, and updates the icon", async () => {
    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme" data-action="click->theme#toggle">
         <span data-theme-target="icon"></span>
       </button>`
    );
    await flush();

    document.querySelector("button").click();

    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("dark");
    expect(document.querySelector("[data-theme-target='icon']").textContent).toBe("☀");
  });

  test("toggling twice returns to light mode and persists 'light'", async () => {
    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme" data-action="click->theme#toggle">
         <span data-theme-target="icon"></span>
       </button>`
    );
    await flush();

    const button = document.querySelector("button");
    button.click();
    button.click();

    expect(document.documentElement.classList.contains("dark")).toBe(false);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("light");
    expect(document.querySelector("[data-theme-target='icon']").textContent).toBe("☾");
  });

  test("toggle still updates DOM when localStorage.setItem throws", async () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("storage unavailable");
    });

    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme" data-action="click->theme#toggle">
         <span data-theme-target="icon"></span>
       </button>`
    );
    await flush();

    expect(() => document.querySelector("button").click()).not.toThrow();
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(document.querySelector("[data-theme-target='icon']").textContent).toBe("☀");
  });

  test("toggle works without an icon target", async () => {
    app = mount(
      "theme",
      ThemeController,
      `<button data-controller="theme" data-action="click->theme#toggle"></button>`
    );
    await flush();

    expect(() => document.querySelector("button").click()).not.toThrow();
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("dark");
  });
});
