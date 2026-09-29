/*
 * Logs messages to the console with the [CodePush] prefix.
 *
 * In dev builds, warn() and error() show LogBox toasts, so only use them for problems the app
 * developer has to act on (warn) or for failed operations (error).
 */
const PREFIX = "[CodePush]";

function info(message) {
  console.log(`${PREFIX} ${message}`);
}

// The stack goes into the string itself: RN's console polyfill formats an Error argument as
// "[Error: message]" before it goes to logcat / the Xcode log, so the stack is not in those logs.
// (DevTools gets the Error object itself and shows the stack.)
function formatError(err) {
  return err ? `\n${err.stack || err}` : "";
}

function warn(message, err) {
  console.warn(`${PREFIX} ${message}${formatError(err)}`);
}

function error(message, err) {
  console.error(`${PREFIX} ${message}${formatError(err)}`);
}

module.exports = { info, warn, error };
