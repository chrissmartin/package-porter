# package-porter

## Universal Package Migration Tool

package-porter is a versatile command-line tool designed to facilitate the migration of packages between different registries. It currently supports npm and PyPI, with the flexibility to extend support for other package ecosystems.

### Features

- Migrate packages between registries (e.g., from npm to a private registry)
- Support for multiple package ecosystems (currently npm and PyPI)
- Version sorting and comparison following semver rules
- Dry-run mode for testing migrations without making changes
- Verbose logging for detailed operation information
- Configurable via command-line arguments or configuration file

### Installation

1. Clone the repository or download the `package-porter` script.
2. Make the script executable:
   ```
   chmod +x package-porter
   ```
3. Optionally, move the script to a directory in your PATH for easier access.

### Configuration

package-porter can be configured using command-line arguments or a configuration file. The default configuration file is `~/.package-porter.env`.

Example configuration file (`~/.package-porter.env`):

```
SOURCE_REGISTRY=https://registry.npmjs.org
TARGET_REGISTRY=https://your-private-registry.com
PACKAGE_NAME=your-package-name
PACKAGE_SCOPE=@your-scope
SOURCE_AUTH_TOKEN=your-source-auth-token
TARGET_AUTH_TOKEN=your-target-auth-token
REGISTRY_TYPE=npm
VERBOSE=false
DRY_RUN=false
```

### Usage

Basic usage:

```
./package-porter -r npm -p your-package-name
```

With additional options:

```
./package-porter -r npm -p your-package-name -s https://registry.npmjs.org -t https://your-private-registry.com --verbose
```

### Command-line Options

- `-s, --source-registry URL`: Source registry URL
- `-t, --target-registry URL`: Target registry URL
- `-p, --package NAME`: Package name
- `--scope SCOPE`: Package scope (if applicable)
- `-r, --registry-type TYPE`: Registry type (npm, pypi)
- `-c, --config FILE`: Path to configuration file
- `-v, --verbose`: Enable verbose output
- `--dry-run`: Perform a dry run without actual publishing
- `-h, --help`: Display help message

### Supported Registry Types

- npm
- PyPI

### Extending Support for Other Registries

To add support for a new package ecosystem:

1. Add new functions for fetching versions, downloading, and publishing packages.
2. Update the `fetch_versions`, `download_package`, and `publish_package` functions to include the new registry type.
3. Add any necessary configuration options or authentication methods for the new registry.

### Examples

1. Migrate an npm package:

   ```
   ./package-porter -r npm -p lodash -s https://registry.npmjs.org -t https://your-private-registry.com
   ```

2. Dry run for a PyPI package:

   ```
   ./package-porter -r pypi -p requests --dry-run
   ```

3. Migrate a scoped npm package with verbose logging:
   ```
   ./package-porter -r npm -p @types/node --scope @types -v
   ```

### Notes

- Ensure you have the necessary permissions and authentication tokens for both source and target registries.
- For PyPI migrations, make sure you have `pip` and `twine` installed.
- Always test migrations using the `--dry-run` option before performing actual migrations.

### Contributing

Contributions to package-porter are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
