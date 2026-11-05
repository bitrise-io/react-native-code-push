// Dedupes concurrent and repeat calls, but forgets a rejected attempt so a transient failure isn't permanent.
export function onceUntilRejected<T>(fn: () => Promise<T>): () => Promise<T> {
  let promise: Promise<T> | undefined;
  return () => {
    if (!promise) {
      promise = fn().catch((error) => {
        promise = undefined;
        throw error;
      });
    }
    return promise;
  };
}
