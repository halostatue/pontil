import {
  action_mode,
  ExitCode$isExit,
  ExitCode$isFailure,
  ExitCode$isSuccess,
} from "./pontil/core.mjs";
import { toList } from "./gleam.mjs";

export function setExitCode(value) {
  if (ExitCode$isFailure(value)) {
    setExitCode_(1);
  } else if (ExitCode$isSuccess(value)) {
    setExitCode_(0);
  } else if (ExitCode$isExit(value)) {
    setExitCode_(value[0]);
  }
}

function setExitCode_(value) {
  if (globalThis?.Deno) {
    globalThis.Deno.exitCode = value;
  } else if (globalThis?.process) {
    globalThis.process.exitCode = value;
  }
}

let outputMode = undefined;

export function getOutputMode() {
  if (outputMode === undefined) {
    outputMode = action_mode();
  }
  return outputMode;
}

export function setOutputMode(mode) {
  outputMode = mode;
}

const secrets = new Set();

export function addSecrets(newSecrets) {
  let list = newSecrets;
  while (list.head !== undefined) {
    secrets.add(list.head);
    list = list.tail;
  }
}

export function getSecrets() {
  return toList(Array.from(secrets));
}

export function clearSecrets() {
  secrets.clear();
}
