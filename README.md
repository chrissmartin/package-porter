# Package Porter

Package Porter is a universal package migration tool built in Rust. It allows you to easily transfer packages between different registries of the same type (e.g., npm to npm, PyPI to PyPI).

## Features

- Support for npm and PyPI package registries
- Fetch package versions from a source registry
- Download specific package versions
- Publish packages to a target registry
- Authentication support for both source and target registries
- Verbose mode for detailed output
- Dry-run option for testing without actual publishing
- Configuration via command-line arguments or environment variables

## Installation

1. Ensure you have Rust and Cargo installed on your system. If not, you can install them from [https://www.rust-lang.org/tools/install](https://www.rust-lang.org/tools/install).

2. Clone the repository:

   ```
   git clone https://github.com/your-username/package-porter.git
   cd package-porter
   ```

3. Build the project:

   ```
   cargo build --release
   ```

4. The binary will be available at `target/release/package-porter`.

## Usage

You can run Package Porter using the following command structure:

```
package-porter [OPTIONS]
```

### Options

- `-s, --source-registry <URL>`: Source registry URL
- `-t, --target-registry <URL>`: Target registry URL
- `-p, --package <NAME>`: Package name
- `--scope <SCOPE>`: Package scope (if applicable)
- `-r, --registry-type <TYPE>`: Registry type (npm, pypi)
- `-v, --verbose`: Enable verbose output
- `--dry-run`: Perform a dry run without actual publishing

### Environment Variables

You can also configure Package Porter using environment variables. Create a `.env` file in the project directory with the following structure:

```
SOURCE_REGISTRY=https://registry.npmjs.org
TARGET_REGISTRY=https://your-private-registry.com
PACKAGE_NAME=your-package
PACKAGE_SCOPE=your-scope
SOURCE_AUTH_TOKEN=your-source-token
TARGET_AUTH_TOKEN=your-target-token
REGISTRY_TYPE=npm
VERBOSE=true
DRY_RUN=false
```

### Examples

1. Migrate an npm package:

   ```
   package-porter -s https://registry.npmjs.org -t https://your-private-registry.com -p your-package -r npm
   ```

2. Migrate a scoped npm package with verbose output:

   ```
   package-porter -s https://registry.npmjs.org -t https://your-private-registry.com -p your-package --scope @your-scope -r npm -v
   ```

3. Perform a dry run for a PyPI package:
   ```
   package-porter -s https://pypi.org -t https://your-private-pypi.com -p your-package -r pypi --dry-run
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
