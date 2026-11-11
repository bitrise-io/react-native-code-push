import * as assert from 'assert';

import { packageMetadata } from '../package-metadata';

describe('packageMetadata', () => {
  it('copies every value but the functions, and leaves the package as it was', () => {
    const download = () => Promise.resolve();
    const pkg = { label: 'v2', packageSize: 0, isMandatory: false, description: '', download };

    assert.deepStrictEqual(packageMetadata(pkg), {
      label: 'v2',
      packageSize: 0,
      isMandatory: false,
      description: '',
    });
    assert.strictEqual(pkg.download, download);
  });
});
