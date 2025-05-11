module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    // 👇 Allow both single and double quotes
    "quotes": ["warn", "double", { allowTemplateLiterals: true }],

    // 👇 Prefer arrow functions but not enforced
    "prefer-arrow-callback": "off",

    // 👇 Turn off restricted globals if not needed
    "no-restricted-globals": "off",

    // 👇 Increase max line length
    "max-len": ["warn", { code: 120 }],

    // 👇 Relax indentation errors (default Google is 2)
    "indent": ["warn", 2],

    // 👇 Allow trailing commas
    "comma-dangle": "off",

    // 👇 Turn off brace spacing enforcement
    "object-curly-spacing": "off"

  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
