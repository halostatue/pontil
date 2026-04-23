// Platform detection FFI for JavaScript.
//
// Portions of the runtime FFI are adapted from https://github.com/DitherWither/platform,
// licensed under Apache-2.0.

import {
  Arch$Arm,
  Arch$Arm64,
  Arch$Loong64,
  Arch$Mips,
  Arch$MipsLittleEndian,
  Arch$OtherArch,
  Arch$PPC,
  Arch$PPC64,
  Arch$X64,
  Arch$X86,
  Os$Aix,
  Os$Darwin,
  Os$FreeBsd,
  Os$Linux,
  Os$OpenBsd,
  Os$OtherOs,
  Os$SunOs,
  Os$Win32,
  Runtime$Browser,
  Runtime$Bun,
  Runtime$Deno,
  Runtime$isBun,
  Runtime$isDeno,
  Runtime$isNode,
  Runtime$Node,
  Runtime$OtherRuntime,
} from "./pontil/platform.mjs";

export function runtime() {
  if (globalThis.Deno) {
    return Runtime$Deno();
  }
  if (globalThis.Bun) {
    return Runtime$Bun();
  }
  if (globalThis.process?.release?.name === "node") {
    return Runtime$Node();
  }
  if (typeof window !== "undefined" && typeof window.document !== "undefined") {
    return Runtime$Browser();
  }
  return Runtime$OtherRuntime("unknown");
}

export function os() {
  const rt = runtime();
  let platform = "unknown";

  if (Runtime$isBun(rt) || Runtime$isNode(rt)) {
    platform = process.platform;
  } else if (Runtime$isDeno(rt)) {
    const buildOs = globalThis.Deno.build.os;
    platform = buildOs === "windows" ? "win32" : buildOs;
  }

  switch (platform) {
    case "aix":
      return Os$Aix();
    case "darwin":
      return Os$Darwin();
    case "freebsd":
      return Os$FreeBsd();
    case "linux":
      return Os$Linux();
    case "openbsd":
      return Os$OpenBsd();
    case "sunos":
      return Os$SunOs();
    case "win32":
      return Os$Win32();
    default: {
      if (platform.startsWith("win")) {
        return Os$Win32();
      }

      return Os$OtherOs(platform);
    }
  }
}

export function arch() {
  const rt = runtime();
  let arch = "unknown";

  if (Runtime$isBun(rt) || Runtime$isNode(rt)) {
    arch = process.arch;
  } else if (Runtime$isDeno(rt)) {
    arch = globalThis.Deno.build.arch;
  }

  switch (arch) {
    case "arm":
      return Arch$Arm();
    case "arm64":
      return Arch$Arm64();
    case "aarch64":
      return Arch$Arm64();
    case "x86":
      return Arch$X86();
    case "ia32":
      return Arch$X86();
    case "x64":
      return Arch$X64();
    case "x86_64":
      return Arch$X64();
    case "amd64":
      return Arch$X64();
    case "loong64":
      return Arch$Loong64();
    case "mips":
      return Arch$Mips();
    case "mipsel":
      return Arch$MipsLittleEndian();
    case "ppc":
      return Arch$PPC();
    case "ppc64":
      return Arch$PPC64();
    case "riscv64":
      return Arch$RiscV64();
    case "s390":
      return Arch$S390();
    case "s390x":
      return Arch$S390X();
    default:
      return Arch$OtherArch(arch);
  }
}

export function runtimeVersion() {
  if (globalThis.Deno) {
    return globalThis.Deno.version.deno;
  }
  if (globalThis.Bun) {
    return globalThis.Bun.version;
  }
  if (globalThis.process?.version) {
    return globalThis.process.version.replace(/^v/, "");
  }

  if (globalThis.navigator !== "undefined") {
    return "browser";
  }

  return "unknown";
}
