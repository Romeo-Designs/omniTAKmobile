# Borrowed from downstream with path modifications
# harfbuzz-ft elminated due to freetype dependency

COMPILER_FLAGS = [
    "-Werror",
    "-Wall",
    "-Wextra",
    "-Wno-unused-parameter",
    "-Wc99-extensions",
    "-Wno-unused-command-line-argument",
    "-fdiagnostics-color",
    "-DGRPC_USE_PROTO_LITE",
    "-DHAVE_PTHREAD=1",
    "-pedantic",
    "-Wimplicit-fallthrough",
    "-Wno-error=deprecated-declarations",
    "-Wno-extra-semi",
    "-Wno-format-pedantic",
    "-Wno-gnu-anonymous-struct",
    "-Wno-gnu-zero-variadic-macro-arguments",
    "-Wno-nested-anon-types",
    "-Wno-unreachable-code",
    "-Wno-unused-local-typedef",
    "-Wno-unused-variable",
    "-Wshorten-64-to-32",
    "-Wstring-conversion",
    "-Wno-bitwise-instead-of-logical",
    "-Wno-deprecated-this-capture",
    "-Wno-ambiguous-reversed-operator",
]

LOCAL_DEFINES = [
    "HAVE_ROUND",
    "HAVE_OT",
    "HAVE_UCDN",
    "HB_LEAN",
    "HB_NO_LEGACY",
    "HAVE_UNISTD_H",
    "HAVE_SYS_MMAN_H",
    "HB_NO_PRAGMA_GCC_DIAGNOSTIC_WARNING",
]

# This specific source list is intended to match the source list used in the CMakeList
# of the LensCore fork of harfbuzz. See the readme for more info.
SOURCES = [
    "src/hb-ucd.cc",
    "src/hb-ot-shape-complex-hangul.cc",
    "src/hb-set.cc",
    "src/hb-ot-shape-normalize.cc",
    "src/hb-shape-plan.cc",
    "src/hb-ot-math.cc",
    "src/hb-ot-cff1-table.cc",
    "src/hb-ot-font.cc",
    "src/hb-aat-layout.cc",
    "src/hb-ot-shape-complex-vowel-constraints.cc",
    "src/hb-ot-shape-complex-arabic.cc",
    "src/hb-ot-shape-complex-khmer.cc",
    "src/hb-subset-plan.cc",
    "src/hb-ot-shape-complex-use.cc",
    "src/hb-common.cc",
    "src/hb-map.cc",
    "src/hb-warning.cc",
    "src/hb-buffer.cc",
    "src/hb-ot-shape-complex-myanmar.cc",
    "src/hb-ot-var.cc",
    "src/hb-subset-cff-common.cc",
    "src/hb-unicode.cc",
    "src/hb-ot-shape-complex-hebrew.cc",
    "src/hb-font.cc",
    "src/hb-ot-tag.cc",
    "src/hb-subset-cff2.cc",
    "src/hb-ot-color.cc",
    "src/hb-ot-name.cc",
    "src/hb-subset-cff1.cc",
    "src/hb-ot-shape-complex-indic.cc",
    "src/hb-ot-shape-complex-thai.cc",
    "src/hb-ot-layout.cc",
    "src/hb-ot-shape-complex-default.cc",
    "src/hb-ot-shape-complex-use-table.cc",
    "src/hb-buffer-serialize.cc",
    "src/hb-shape.cc",
    "src/hb-subset.cc",
    "src/hb-ot-shape-complex-indic-table.cc",
    "src/hb-static.cc",
    "src/hb-ot-face.cc",
    "src/hb-subset-input.cc",
    "src/hb-ot-shape.cc",
    "src/hb-blob.cc",
    "src/hb-shaper.cc",
    "src/hb-ot-cff2-table.cc",
    "src/hb-ot-shape-fallback.cc",
    "src/hb-ot-map.cc",
    "src/hb-face.cc",
    "src/hb-aat-map.cc",
]

# Harfbuzz defines public headers as .h instead of .hh
PUBLIC_HEADERS = glob([
    "src/**/*.h",
])

cc_library(
    name = "harfbuzz",

    # Expose just the public headers (.h, not .hh).
    hdrs = PUBLIC_HEADERS,
    copts = COMPILER_FLAGS,
    local_defines = LOCAL_DEFINES,
    strip_include_prefix = "src",
    visibility = ["//visibility:public"],
    deps = [
        ":harfbuzz_impl",
    ],
)

cc_library(
    name = "harfbuzz_impl",
    srcs = SOURCES + glob([
        # Harfbuzz defines its private headers using .hh instead of .h
        "src/**/*.hh",
    ]),
    # Depend on public headers even though this target is private, since the public
    # headers are included by private headers or .c files.
    hdrs = PUBLIC_HEADERS,
    copts = COMPILER_FLAGS,
    local_defines = LOCAL_DEFINES,
    deps = [],
)
