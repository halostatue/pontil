import {
  ExitCode$isFailure,
  ExitCode$isSuccess,
} from "./pontil/core/command.mjs";

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
