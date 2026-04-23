import gleeunit
import pontil/platform

pub fn main() {
  gleeunit.main()
}

pub fn is_helpers_consistent_with_os_test() {
  let os = platform.os()
  assert platform.is_windows() == { os == platform.Win32 }
  assert platform.is_macos() == { os == platform.Darwin }
  assert platform.is_linux() == { os == platform.Linux }
}

pub fn runtime_to_string_test() {
  assert "erlang" == platform.runtime_to_string(platform.Erlang)
  assert "node" == platform.runtime_to_string(platform.Node)
  assert "bun" == platform.runtime_to_string(platform.Bun)
  assert "deno" == platform.runtime_to_string(platform.Deno)
  assert "browser" == platform.runtime_to_string(platform.Browser)
  assert "wasm" == platform.runtime_to_string(platform.OtherRuntime("wasm"))
}

pub fn os_to_string_test() {
  assert "linux" == platform.os_to_string(platform.Linux)
  assert "darwin" == platform.os_to_string(platform.Darwin)
  assert "win32" == platform.os_to_string(platform.Win32)
  assert "freebsd" == platform.os_to_string(platform.FreeBsd)
  assert "haiku" == platform.os_to_string(platform.OtherOs("haiku"))
}

pub fn arch_to_string_test() {
  assert "x64" == platform.arch_to_string(platform.X64)
  assert "arm64" == platform.arch_to_string(platform.Arm64)
  assert "mipsel" == platform.arch_to_string(platform.MipsLittleEndian)
  assert "z80" == platform.arch_to_string(platform.OtherArch("z80"))
}

pub fn details_fields_are_consistent_test() {
  let info = platform.details()
  assert info.runtime == platform.runtime()
  assert info.os == platform.os()
  assert info.arch == platform.arch()
  assert info.runtime_version == platform.runtime_version()
}
