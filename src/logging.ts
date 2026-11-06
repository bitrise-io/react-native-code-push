/*
 * Logs messages to the console with the [CodePush] prefix.
 *
 * In dev builds, warn() and error() show LogBox toasts, so only use them for problems the app
 * developer has to act on (warn) or for failed operations (error).
 */
const PREFIX = '[CodePush]';

function info(message: string): void {
  console.log(`${PREFIX} ${message}`);
}

// The stack goes into the string itself: RN's console polyfill formats an Error argument as
// "[Error: message]" before it goes to logcat / the Xcode log, so the stack is not in those logs.
// (DevTools gets the Error object itself and shows the stack.)
function formatError(err?: Error): string {
  return err ? `\n${err.stack || err}` : '';
}

function warn(message: string, err?: Error): void {
  console.warn(`${PREFIX} ${message}${formatError(err)}`);
}

function error(message: string, err?: Error): void {
  console.error(`${PREFIX} ${message}${formatError(err)}`);
}

export function logFields(fields: Record<string, unknown>): string {
  return Object.entries(fields)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${value}`)
    .join(' ');
}

export function packageLogFields(pkg?: { versionLabel?: string; packageHash?: string }) {
  return {
    versionLabel: pkg && pkg.versionLabel,
    packageHash: pkg && pkg.packageHash,
  };
}

// Signed download URLs can have credentials in the query string.
export function redactUrl(url?: string): string | undefined {
  return url ? url.split('?')[0] : url;
}

export default { info, warn, error };
