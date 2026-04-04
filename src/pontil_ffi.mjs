import {
  ExitCode$isFailure,
  ExitCode$isSuccess,
  Linux,
  MacOS,
  Other,
  Windows,
} from "./pontil/types.mjs";

export function setExitCode(value) {
  if (ExitCode$isFailure(value)) {
    setExitCode_(1);
  } else if (ExitCode$isSuccess(value)) {
    setExitCode_(0);
  } else if (typeof value == "number") {
    setExitCode_(value);
  }
}

function setExitCode_(value) {
  if (globalThis?.Deno) {
    globalThis.Deno.exitCode = value;
  } else if (globalThis?.process) {
    globalThis.process.exitCode = value;
  }
}

export function stop() {}

export function isWindows() {
  return rawPlatform() === "win32";
}

export function isMacos() {
  return rawPlatform() === "darwin";
}

export function isLinux() {
  return rawPlatform() === "linux";
}

export function osType() {
  const p = rawPlatform();
  switch (p) {
    case "win32":
      return new Windows();
    case "darwin":
      return new MacOS();
    case "linux":
      return new Linux();
    default:
      return new Other(p);
  }
}

export function osArch() {
  if (globalThis?.Deno) {
    return globalThis.Deno.build.arch;
  }
  return globalThis?.process?.arch ?? "unknown";
}

function rawPlatform() {
  if (globalThis?.Deno) {
    const os = globalThis.Deno.build.os;
    return os === "windows" ? "win32" : os;
  }
  return globalThis?.process?.platform ?? "linux";
}
