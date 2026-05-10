import { Ok, Error } from "./gleam.mjs";

export function getExitCode() {
  if (globalThis?.Deno) {
    return new Ok(globalThis.Deno.exitCode ?? 0);
  } else if (globalThis?.process) {
    return new Ok(globalThis.process.exitCode ?? 0);
  }
  return new Error(undefined);
}

export function clearExitCode() {
  if (globalThis?.Deno) {
    globalThis.Deno.exitCode = 0;
  } else if (globalThis?.process) {
    globalThis.process.exitCode = 0;
  }
}
