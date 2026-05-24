import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import ThemeController, { STORAGE_KEY } from "../../../app/javascript/controllers/theme_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `<button data-controller="theme" data-action="click->theme#toggle">
  <svg data-theme-target="moon" class="moon"></svg>
  <svg data-theme-target="sun" class="sun"></svg>
</button>`;

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
    app = mount("theme", ThemeController, TEMPLATE);
    await flush();

    const moon = document.querySelector("[data-theme-target='moon']");
    const sun = document.querySelector("[data-theme-target='sun']");
    expect(moon.style.display).toBe("block");
    expect(sun.style.display).toBe("none");
  });

  test("shows the sun icon when starting in dark mode", async () => {
    document.documentElement.classList.add("dark");
    app = mount("theme", ThemeController, TEMPLATE);
    await flush();

    const moon = document.querySelector("[data-theme-target='moon']");
    const sun = document.querySelector("[data-theme-target='sun']");
    expect(moon.style.display).toBe("none");
    expect(sun.style.display).toBe("block");
  });

  test("toggle adds the dark class, persists to localStorage, and updates the icons", async () => {
    app = mount("theme", ThemeController, TEMPLATE);
    await flush();

    document.querySelector("button").click();

    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("dark");
    expect(document.querySelector("[data-theme-target='moon']").style.display).toBe("none");
    expect(document.querySelector("[data-theme-target='sun']").style.display).toBe("block");
  });

  test("toggling twice returns to light mode and persists 'light'", async () => {
    app = mount("theme", ThemeController, TEMPLATE);
    await flush();

    const button = document.querySelector("button");
    button.click();
    button.click();

    expect(document.documentElement.classList.contains("dark")).toBe(false);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("light");
    expect(document.querySelector("[data-theme-target='moon']").style.display).toBe("block");
    expect(document.querySelector("[data-theme-target='sun']").style.display).toBe("none");
  });

  test("toggle still updates DOM when localStorage.setItem throws", async () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("storage unavailable");
    });

    app = mount("theme", ThemeController, TEMPLATE);
    await flush();

    expect(() => document.querySelector("button").click()).not.toThrow();
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(document.querySelector("[data-theme-target='moon']").style.display).toBe("none");
  });

  test("toggle works without icon targets", async () => {
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
