# perfetto: support aarch64 build hosts
#
# perfetto.bb declares COMPATIBLE_HOST = "(i.86|x86_64|aarch64|arm).*-linux*", yet
# two parts of its build assume an x86_64 build host:
#   1. tools/gn is a prebuilt x86_64 ELF  -> needs the x86_64 loader/libs on the host,
#      provided by the kas-hailo-arm64 image (libc6:amd64 + /lib64 loader symlink).
#   2. the gcc_like_host target injects x86_64 CPU flags (-mbmi -mavx2 -msse4.2 ...)
#      into the generated ninja files; the aarch64 host g++ rejects them with
#      "unrecognized command-line option" during do_compile.
#
# Strip those x86_64 -m flags from the ninja files right after `gn gen`, so the
# host-side protobuf/protoc build compiles on aarch64 hosts. The target build
# (aarch64-poky-linux-g++) is unaffected because it never carries x86 -m flags.

do_configure:append() {
    find ${B} -name "*.ninja" | xargs sed -i \
        -e 's/ -mbmi\b//g' \
        -e 's/ -mbmi2\b//g' \
        -e 's/ -mavx\b//g' \
        -e 's/ -mavx2\b//g' \
        -e 's/ -mpopcnt\b//g' \
        -e 's/ -msse2\b//g' \
        -e 's/ -msse3\b//g' \
        -e 's/ -mssse3\b//g' \
        -e 's/ -msse4\.1\b//g' \
        -e 's/ -msse4\.2\b//g' \
        -e 's/ -mfma\b//g' \
        -e 's/ -mf16c\b//g' \
        -e 's/ -maes\b//g' \
        -e 's/ -mpclmul\b//g' \
        -e 's/ -mrdrnd\b//g'

    # Force PERFETTO_X64_CPU_OPT off in the generated build flags. The
    # gcc_like_host toolchain enables it unconditionally (it assumes an x86_64
    # build host), which pulls in x86 cpuid/xgetbv inline asm in src/base/utils.cc
    # ("impossible constraint in asm") that cannot compile on aarch64. The
    # target build already sets this to (0); only the host toolchain is wrong.
    find ${B} -name perfetto_build_flags.h | xargs sed -i \
        -e 's|PERFETTO_BUILDFLAG_DEFINE_PERFETTO_X64_CPU_OPT() ([01])|PERFETTO_BUILDFLAG_DEFINE_PERFETTO_X64_CPU_OPT() (0)|'
}
