export function promiseFinally(promise, fn) {
  return promise.finally(fn);
}

export function registerProcessHandlers(exceptionFn, rejectionFn) {
  process.on("unhandledRejection", (reason) => {
    const msg = reason instanceof Error ? reason.message : String(reason);
    rejectionFn(`Unhandled rejection: ${msg}`);
  });
  process.on("uncaughtException", (err) => {
    const msg = err instanceof Error ? err.message : String(err);
    exceptionFn(`Uncaught exception: ${msg}`);
  });
}
