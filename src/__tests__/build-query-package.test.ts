import * as assert from 'assert';

import { buildQueryPackage } from '../build-query-package';

describe('buildQueryPackage', () => {
  it('sends the binary hash when no update is installed', () => {
    assert.deepStrictEqual(buildQueryPackage(null, { appVersion: '1.0.0', packageHash: 'abc' }), {
      appVersion: '1.0.0',
      packageHash: 'abc',
    });
  });

  it('omits the hash when the binary has none', () => {
    assert.deepStrictEqual(buildQueryPackage(undefined, { appVersion: '1.0.0', packageHash: null }), {
      appVersion: '1.0.0',
    });
    assert.deepStrictEqual(buildQueryPackage(undefined, { appVersion: '1.0.0' }), { appVersion: '1.0.0' });
  });

  it('uses the installed package as is', () => {
    const localPackage = { appVersion: '1.0.0', packageHash: 'installed' };
    assert.strictEqual(buildQueryPackage(localPackage, { appVersion: '1.0.0', packageHash: 'abc' }), localPackage);
  });
});
