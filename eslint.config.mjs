import bitrise from '@bitrise/eslint-plugin';

const files = ['src/**/*.ts', 'test/**/*.mts'];

export default [
  { ...bitrise.react, files },
  {
    files,
    rules: {
      // tsc already reports undefined identifiers, and no-undef misreads Node/mocha globals and type namespaces.
      'no-undef': 'off',
      // React Native has no stdout, so console is the logging channel.
      'no-console': 'off',
    },
  },
  {
    // The root tsconfig.json excludes the unit tests.
    files: ['src/**/__tests__/**/*.ts'],
    languageOptions: { parserOptions: { project: './tsconfig.unit.json', tsconfigRootDir: import.meta.dirname } },
  },
  {
    files: ['src/**/__tests__/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['react-native', 'react-native/*'],
              message:
                'Avoid depending on react-native in unit-testable TS code. Extract logic into testable units instead.',
            },
          ],
        },
      ],
    },
  },
];
