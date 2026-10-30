import * as assert from 'assert';

import { onceUntilRejected } from '../once-until-rejected';

describe('onceUntilRejected', () => {
  it('does not run again after it resolves', async () => {
    let calls = 0;
    const run = onceUntilRejected(async () => ++calls);

    assert.strictEqual(await run(), 1);
    assert.strictEqual(await run(), 1);
    assert.strictEqual(calls, 1);
  });

  it('shares a pending attempt, and runs again after it rejects', async () => {
    let calls = 0;
    const run = onceUntilRejected(async () => {
      calls++;
      if (calls === 1) {
        throw new Error('first attempt failed');
      }
      return calls;
    });

    const first = run();
    const second = run();
    assert.strictEqual(first, second);
    await assert.rejects(first, /first attempt failed/);

    assert.strictEqual(await run(), 2);
    assert.strictEqual(await run(), 2);
    assert.strictEqual(calls, 2);
  });
});
