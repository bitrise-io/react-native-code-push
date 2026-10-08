import bitrise from '@bitrise/eslint-plugin';

// The ported upstream tests in src/**/__tests__ are not part of any tsconfig yet, see "Testing Notes" in AGENTS.md.
const files = ['src/**/*.ts', 'test/**/*.mts'];
const ignores = ['src/**/__tests__/**'];

export default [
  { ...bitrise.react, files, ignores },
  {
    files,
    ignores,
    rules: {
      // tsc already reports undefined identifiers, and no-undef misreads Node/mocha globals and type namespaces.
      'no-undef': 'off',
      // React Native has no stdout, so console is the logging channel.
      'no-console': 'off',
    },
  },
];
