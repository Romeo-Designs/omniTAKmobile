# Valdi CLI

The Valdi CLI tool provides helpful commands for working with Valdi applications.

When working on this module please set your npm registry

```sh
npm config set registry https://registry.npmjs.org/
```

## General Use

### New Module Creations

```sh
valdi new_module

# Create module without prompts
valdi new_module my_new_module --skip-checks --android-class-path='com.example.my_module' --ios-module-name='XYZMyModule'

# Help
$ valdi new_module --help
valdi new_module [module-name]


******************************************
Valdi Module Creation Guide
******************************************

Requirements for Valdi module names:
- May contain: A-Z, a-z, 0-9, '-', '_', '.'
- Must start with a letter.

Recommended Directory Structure:
my_application/          # Root directory of your application
├── WORKSPACE            # Bazel Workspace
├── BUILD.bazel          # Bazel build
└── modules/
    ├── module_a/
    │   ├── BUILD.bazel
    │   ├── android/     # Native Android sources
    │   ├── ios/         # Native iOS sources
    │   ├── cpp/         # Native C++ sources
    │   └── src/         # Valdi sources
    │       └── ModuleAComponent.tsx
    ├── module_b/
        ├── BUILD.bazel
    │   ├── res/         # Image and font resources
    │   ├── strings/     # Localizable strings
        └── src/
            └── ModuleBComponent.tsx

For more comprehensive details, refer to the core-module documentation:
https://github.com/Snapchat/Valdi/blob/main/docs/docs/core-module.md

******************************************


Positionals:
  module-name  Name of the Valdi module.

Options:
  --debug               Run with debug logging                                                                                                  [boolean] [default: false]
  --version             Show version number                                                                                                                      [boolean]
  --help                Show help                                                                                                                                [boolean]
  --skip-checks         Skips confirmation prompts.                                                                                                              [boolean]
  --android-class-path  Android class path to use for generated Android sources.                                                                                  [string]
  --ios-module-name     iOS class prefix to use for generated iOS sources.                                                                                        [string]
```

## Development Setup

# Install dependencies

```sh
npm install
```

## Development

# Run the cli

```sh
npm run main
```

# Pass in command line arguments

```sh
npm run main bootstrap -- --confirm-bootstrap
```

# Build javascript output to ./dist

```sh
npm run build
```

# Develop with hotreload

```sh
npm run watch
node ./dist/index.js
node ./dist/index.js bootstrap --confirm-bootstrap
```

# Show the help menu

```sh
node ./dist/index.js new_module --help
```

# Run unit tests

```sh
npm test
```

# Install the `valdi` command

```sh
npm run cli:install
```
