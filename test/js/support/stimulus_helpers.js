import { Application } from "@hotwired/stimulus";

export function setBody(html) {
  document.body.replaceChildren();
  if (!html) return;
  const fragment = document.createRange().createContextualFragment(html);
  document.body.appendChild(fragment);
}

export function mount(identifier, ControllerClass, html) {
  setBody(html);
  const app = Application.start();
  app.register(identifier, ControllerClass);
  return app;
}

// One macrotask is enough: Stimulus connects via a MutationObserver, whose
// callback runs as a microtask before the next setTimeout fires.
export function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}
