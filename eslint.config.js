import js from "@eslint/js";
import playwright from "eslint-plugin-playwright";
import tseslint from "typescript-eslint";
import globals from "globals";

export default [
  { ignores: ["vendor/**", "public/**"] },
  {
    files: ["test/e2e/**/*.ts"],
    ...playwright.configs["flat/recommended"],
    languageOptions: {
      ...playwright.configs["flat/recommended"].languageOptions,
      parser: tseslint.parser,
    },
  },
  {
    files: ["app/javascript/**/*.js", "test/js/**/*.js", "vitest.config.js"],
    ...js.configs.recommended,
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser, Turbo: "readonly", Stimulus: "readonly" },
    },
  },
];
