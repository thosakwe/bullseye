# Getting started

## Installation
To develop programs with Bullseye, you will need to get a copy of the compiler.
The full Bullseye toolchain includes a few tools:
* A `package:build` builder that compiles Bullseye sources
* A standalone compiler (you will likely not use this often)
* A Dart analyzer plugin, so you can get IDE features immediately

### From Pub
The easiest way to get Bullseye is to install a stable release from Pub:

```bash
pub global activate bullseye_lang
bullseye --help
```

### From source
Alternatively, you can download the source code as a ZIP repository.
After unzipping it, run `pub global activate --source path <path_to_sources>` to
install the compiler.
