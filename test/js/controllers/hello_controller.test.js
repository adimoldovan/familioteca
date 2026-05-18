import { afterEach, describe, expect, test } from "vitest";
import HelloController from "../../../app/javascript/controllers/hello_controller.js";
import { flush, mount, setBody } from "../support/stimulus_helpers.js";

describe("HelloController", () => {
  let app;

  afterEach(() => {
    app?.stop();
    setBody("");
  });

  test("sets element text to 'Hello World!' on connect", async () => {
    app = mount("hello", HelloController, `<div data-controller="hello"></div>`);
    await flush();

    expect(document.querySelector("[data-controller='hello']").textContent).toBe(
      "Hello World!"
    );
  });
});
