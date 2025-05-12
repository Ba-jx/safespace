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

    // 👇 Relax linebreaks (CRLF/LF)
    "linebreak-style": "off",

    // 👇 Don't enforce brace style (e.g., } else {)
    "brace-style": "off",

    // 👇 Allow long lines but warn only
    "max-len": ["warn", { code: 140 }],

    // 👇 Relax indent enforcement
    "indent": ["warn", 2],

    // 👇 Allow trailing commas
    "comma-dangle": "off",

    // 👇 Don't enforce spacing in curly braces
    "object-curly-spacing": "off",

    // 👇 Allow unused vars (warn only, don't block)
    "no-unused-vars": "warn",

    // 👇 Allow console logs (important for Firebase Functions)
    "no-console": "off",

    // 👇 Disable Google style semicolon enforcement
    "semi": "off",

    // 👇 Turn off restricted globals if not needed
    "no-restricted-globals": "off",

    // 👇 Prefer arrow functions but not enforced
    "prefer-arrow-callback": "off",
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
  globals: {
    onDocumentUpdated: "readonly",
    onRequest: "readonly",
    logger: "readonly",
    db: "readonly",
    messaging: "readonly",
  },
};
