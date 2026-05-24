import { afterEach, describe, expect, test } from "vitest";
import DropdownController from "../../../app/javascript/controllers/dropdown_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

const TEMPLATE = `<div data-controller="dropdown">
  <button data-dropdown-target="button" data-action="click->dropdown#toggle" aria-expanded="false">Menu</button>
  <ul data-dropdown-target="menu">
    <li>Item 1</li>
    <li>Item 2</li>
  </ul>
</div>
<div id="outside">Outside</div>`;

describe("DropdownController", () => {
  let app;

  afterEach(() => {
    app?.stop();
    setBody("");
  });

  test("toggle opens the dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(true);
    expect(document.querySelector("button").getAttribute("aria-expanded")).toBe("true");
  });

  test("toggle closes an open dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    const button = document.querySelector("button");
    button.click();
    button.click();

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(false);
    expect(button.getAttribute("aria-expanded")).toBe("false");
  });

  test("clicking outside closes the dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();
    document.getElementById("outside").click();

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(false);
  });

  test("clicking inside does not close the dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();
    document.querySelector("li").click();

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(true);
  });

  test("Escape key closes the dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(false);
    expect(document.querySelector("button").getAttribute("aria-expanded")).toBe("false");
  });

  test("non-Escape keys do not close the dropdown", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));

    const wrapper = document.querySelector("[data-controller='dropdown']");
    expect(wrapper.classList.contains("is-open")).toBe(true);
  });

  test("disconnect removes document listeners added by open", async () => {
    app = mount("dropdown", DropdownController, TEMPLATE);
    await flush();

    document.querySelector("button").click();

    const wrapper = document.querySelector("[data-controller='dropdown']");
    const ctrl = app.getControllerForElementAndIdentifier(wrapper, "dropdown");
    ctrl.disconnect();

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(wrapper.classList.contains("is-open")).toBe(true);
  });
});
