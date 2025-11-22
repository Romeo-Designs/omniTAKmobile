# Shim to use different dependencies for open source and internal valdi

# TODO(mgalindo): return internal build dependencies when changing repo deps

INTERNAL_BUILD = False

def pngquant_linux():
    if INTERNAL_BUILD:
        pass
    return "pngquant/linux/pngquant"

def pngquant_macos():
    if INTERNAL_BUILD:
        pass
    return "pngquant/macos/pngquant"

def valdi_compiler_companion_files():
    if INTERNAL_BUILD:
        pass
    return native.glob([
        "compiler_companion/**/*.js",
        "compiler_companion/**/*.js.map",
        "compiler_companion/**/*.node",
    ])

def bundle_js():
    if INTERNAL_BUILD:
        pass
    return "compiler_companion/bundle.js"

def jscore_library():
    if INTERNAL_BUILD:
        pass
    return "libs/linux/x86_64/libjsc.so"
