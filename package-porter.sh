#!/bin/bash

# package-porter: Universal Package Migration Tool

# Default Configuration
SOURCE_REGISTRY=""
TARGET_REGISTRY=""
PACKAGE_NAME=""
PACKAGE_SCOPE=""
SOURCE_AUTH_TOKEN=""
TARGET_AUTH_TOKEN=""
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=".env"
REGISTRY_TYPE="npm"  # Default to npm, but could be "pypi", "rubygems", etc.
SOURCE_NPMRC_FILE="source.npmrc"
TARGET_NPMRC_FILE="target.npmrc"

# Function to display usage information
usage() {
    echo "package-porter: Universal Package Migration Tool"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --source-registry URL     Source registry URL"
    echo "  -t, --target-registry URL     Target registry URL"
    echo "  -p, --package NAME            Package name"
    echo "  --scope SCOPE                 Package scope (if applicable)"
    echo "  -r, --registry-type TYPE      Registry type (npm, pypi, rubygems, etc.)"
    echo "  -c, --config FILE             Path to configuration file (default: ~/.package-porter.env)"
    echo "  -v, --verbose                 Enable verbose output"
    echo "  --dry-run                     Perform a dry run without actual publishing"
    echo "  -h, --help                    Display this help message"
    echo ""
    echo "Configuration can be provided via:"
    echo "1. Command-line arguments"
    echo "2. Configuration file (default: ~/.package-porter.env)"
    echo "3. Interactive prompt (for auth tokens if not provided by other methods)"
}

# Function for verbose logging
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "[VERBOSE] $1"
    fi
}

# Function for dry run logging
log_dry_run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] $1"
    fi
}

wait_for_command() {
    local pid=$1
    local message=$2
    echo "$message"
    wait $pid
    return $?
}

# Function to read configuration file
read_config_file() {
    if [ -f "$1" ]; then
        log_verbose "Reading configuration from $1"
        while IFS='=' read -r key value
        do
            # Ignore comments and empty lines
            [[ $key == \#* ]] && continue
            [[ -z "$key" ]] && continue

            # Trim leading and trailing whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Remove quotes if present
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

            case "$key" in
                SOURCE_REGISTRY) SOURCE_REGISTRY="$value" ;;
                TARGET_REGISTRY) TARGET_REGISTRY="$value" ;;
                PACKAGE_NAME) PACKAGE_NAME="$value" ;;
                PACKAGE_SCOPE) PACKAGE_SCOPE="$value" ;;
                SOURCE_AUTH_TOKEN) SOURCE_AUTH_TOKEN="$value" ;;
                TARGET_AUTH_TOKEN) TARGET_AUTH_TOKEN="$value" ;;
                VERBOSE) VERBOSE="$value" ;;
                DRY_RUN) DRY_RUN="$value" ;;
                REGISTRY_TYPE) REGISTRY_TYPE="$value" ;;
            esac
        done < "$1"
    else
        log_verbose "Configuration file $1 not found"
    fi
}

# Function to prompt for auth tokens
prompt_for_tokens() {
    if [ -z "$SOURCE_AUTH_TOKEN" ]; then
        read -sp "Enter source registry auth token: " SOURCE_AUTH_TOKEN
        echo
    fi
    if [ -z "$TARGET_AUTH_TOKEN" ]; then
        read -sp "Enter target registry auth token: " TARGET_AUTH_TOKEN
        echo
    fi
}

# Function to validate and normalize version string
validate_version() {
    local version=$1
    local normalized_version

    # Regex for strict semver (major.minor.patch)
    local semver_regex="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"

    # Regex for lenient version format (at least major.minor)
    local lenient_regex="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\.[0-9]+)?(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"

    if [[ $version =~ $semver_regex ]]; then
        normalized_version=$version
    elif [[ $version =~ $lenient_regex ]]; then
        # Normalize to semver format
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        local patch="${BASH_REMATCH[3]:-0}"
        patch="${patch#.}"  # Remove leading dot if present
        local prerelease="${BASH_REMATCH[4]:-}"
        local buildmeta="${BASH_REMATCH[6]:-}"
        normalized_version="$major.$minor.$patch$prerelease$buildmeta"
        log_verbose "Normalized non-standard version '$version' to '$normalized_version'"
    else
        log_verbose "Invalid version format: $version"
        return 1
    fi

    echo "$normalized_version"
}

# Function to parse version string into an array
parse_version() {
    local version=$1
    local regex="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"
    if [[ $version =~ $regex ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]:-} ${BASH_REMATCH[6]:-}"
    else
        echo "Invalid version format: $version" >&2
        return 1
    fi
}

# Function to compare two versions
version_compare() {
    local v1=($1)
    local v2=($2)
    local i

    # Compare major.minor.patch
    for i in 0 1 2; do
        if [[ ${v1[$i]} -gt ${v2[$i]} ]]; then
            echo 1
            return
        elif [[ ${v1[$i]} -lt ${v2[$i]} ]]; then
            echo -1
            return
        fi
    done

    # If we're here, major.minor.patch are equal, so check pre-release
    if [[ ${v1[3]} && ! ${v2[3]} ]]; then
        echo -1
        return
    elif [[ ! ${v1[3]} && ${v2[3]} ]]; then
        echo 1
        return
    elif [[ ${v1[3]} && ${v2[3]} ]]; then
        if [[ ${v1[3]} > ${v2[3]} ]]; then
            echo 1
            return
        elif [[ ${v1[3]} < ${v2[3]} ]]; then
            echo -1
            return
        fi
    fi

    # Everything is equal
    echo 0
}

# Function to sort versions
sort_versions() {
    local versions=("$@")
    local valid_versions=()
    local invalid_versions=()

    # Validate and normalize versions
    for version in "${versions[@]}"; do
        if normalized_version=$(validate_version "$version"); then
            valid_versions+=("$normalized_version")
        else
            invalid_versions+=("$version")
        fi
    done

    if [ ${#invalid_versions[@]} -gt 0 ]; then
        log_verbose "Warning: The following versions were ignored due to invalid format:"
        for invalid_version in "${invalid_versions[@]}"; do
            log_verbose "invalid_versions: $invalid_version"
        done
    fi

    # Sort valid versions
    local sorted_versions=()
    local swapped=true
    local i

    # Bubble sort implementation
    while [[ $swapped == true ]]; do
        swapped=false
        for ((i=0; i<${#valid_versions[@]}-1; i++)); do
            local v1=($(parse_version "${valid_versions[i]}"))
            local v2=($(parse_version "${valid_versions[i+1]}"))
            if [[ $(version_compare "${v1[*]}" "${v2[*]}") -gt 0 ]]; then
                local temp=${valid_versions[i]}
                valid_versions[i]=${valid_versions[i+1]}
                valid_versions[i+1]=$temp
                swapped=true
            fi
        done
    done

    echo "${valid_versions[@]}"
}

# Function to create temporary npmrc files
create_npmrc_files() {
    local script_dir=$(dirname "$0")
    SOURCE_NPMRC_FILE="${script_dir}/source.npmrc"
    TARGET_NPMRC_FILE="${script_dir}/target.npmrc"

    echo "registry=${SOURCE_REGISTRY}" > "$SOURCE_NPMRC_FILE"
    echo "//${SOURCE_REGISTRY#*//}:_authToken=${SOURCE_AUTH_TOKEN}" >> "$SOURCE_NPMRC_FILE"

    echo "registry=${TARGET_REGISTRY}" > "$TARGET_NPMRC_FILE"
    echo "//${TARGET_REGISTRY#*//}:_authToken=${TARGET_AUTH_TOKEN}" >> "$TARGET_NPMRC_FILE"

    log_verbose "Created npmrc files in script directory:"
    log_verbose "Source npmrc: $SOURCE_NPMRC_FILE"
    log_verbose "Target npmrc: $TARGET_NPMRC_FILE"
}

# Registry-specific functions

npm_fetch_versions() {
    local full_package_name="$PACKAGE_NAME"
    if [ ! -z "$PACKAGE_SCOPE" ]; then
        full_package_name="${PACKAGE_SCOPE}/${PACKAGE_NAME}"
    fi
    log_verbose "Fetching versions for $full_package_name from npm registry: $SOURCE_REGISTRY"
    local versions
    versions=$(npm view "$full_package_name" versions --registry "$SOURCE_REGISTRY" --userconfig="$SOURCE_NPMRC_FILE" | tr -d "[]'," | tr ' ' '\n') &
    wait_for_command $! "Fetching versions of package $full_package_name"

    if [ -z "$versions" ]; then
        echo "Error: Unable to fetch versions for $full_package_name" >&2
        return 1
    fi
    echo "$versions"
}

npm_download_package() {
    local version=$1
    local full_package_name="$PACKAGE_NAME"
    if [ ! -z "$PACKAGE_SCOPE" ]; then
        full_package_name="${PACKAGE_SCOPE}/${PACKAGE_NAME}"
    fi
    npm pack "$full_package_name@$version" --registry "$SOURCE_REGISTRY" --userconfig="$SOURCE_NPMRC_FILE" --pack-destination ./tarballs &
    wait_for_command $! "Downloading package $full_package_name@$version..."
}

npm_publish_package() {
    local tarball=$1
    npm publish "./tarballs/$tarball" --registry "$TARGET_REGISTRY" --userconfig="$TARGET_NPMRC_FILE" &
    wait_for_command $! "Publishing package $tarball..."
}

pypi_fetch_versions() {
    log_verbose "Fetching versions for $PACKAGE_NAME from PyPI registry: $SOURCE_REGISTRY"
    local versions=$(pip index versions $PACKAGE_NAME)
    log_verbose "Fetched versions: $versions"
    echo "$versions"
}

pypi_download_package() {
    local version=$1
    pip download $PACKAGE_NAME==$version -d ./tarballs &
    wait_for_command $! "Downloading package $PACKAGE_NAME==$version..."
}

pypi_publish_package() {
    local tarball=$1
    twine upload "./tarballs/$tarball" --repository-url $TARGET_REGISTRY &
    wait_for_command $! "Publishing package $tarball..."
}


# Main logic functions
fetch_versions() {
    log_verbose "Starting version fetch for $PACKAGE_NAME using $REGISTRY_TYPE registry"
    local versions
    case $REGISTRY_TYPE in
        npm)
            versions=$(npm_fetch_versions)
            ;;
        pypi)
            versions=$(pypi_fetch_versions)
            ;;
        *)
            echo "Unsupported registry type: $REGISTRY_TYPE" >&2
            exit 1
            ;;
    esac

    if [ -z "$versions" ]; then
        log_verbose "No versions found for $PACKAGE_NAME"
        echo ""
    else
        log_verbose "Fetched versions for $PACKAGE_NAME: $versions"
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would process the following versions: $versions"
        fi
        echo "$versions"
    fi
}

download_package() {
    case $REGISTRY_TYPE in
        npm) npm_download_package $1 ;;
        pypi) pypi_download_package $1 ;;
        *) echo "Unsupported registry type: $REGISTRY_TYPE"; exit 1 ;;
    esac
}

publish_package() {
    case $REGISTRY_TYPE in
        npm) npm_publish_package $1 ;;
        pypi) pypi_publish_package $1 ;;
        *) echo "Unsupported registry type: $REGISTRY_TYPE"; exit 1 ;;
    esac
}

# Read configuration file
read_config_file "$CONFIG_FILE"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -s|--source-registry)
        SOURCE_REGISTRY="$2"
        shift 2
        ;;
        -t|--target-registry)
        TARGET_REGISTRY="$2"
        shift 2
        ;;
        -p|--package)
        PACKAGE_NAME="$2"
        shift 2
        ;;
        --scope)
        PACKAGE_SCOPE="$2"
        shift 2
        ;;
        -r|--registry-type)
        REGISTRY_TYPE="$2"
        shift 2
        ;;
        -c|--config)
        CONFIG_FILE="$2"
        read_config_file "$CONFIG_FILE"
        shift 2
        ;;
        -v|--verbose)
        VERBOSE=true
        shift
        ;;
        --dry-run)
        DRY_RUN=true
        shift
        ;;
        -h|--help)
        usage
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

# Prompt for tokens if not provided
prompt_for_tokens

# Validate required parameters
if [ -z "$SOURCE_REGISTRY" ] || [ -z "$TARGET_REGISTRY" ] || [ -z "$PACKAGE_NAME" ] || [ -z "$SOURCE_AUTH_TOKEN" ] || [ -z "$TARGET_AUTH_TOKEN" ]; then
    echo "Error: Missing required parameters or authentication tokens."
    usage
    exit 1
fi

# Validate package scope format if provided
if [ ! -z "$PACKAGE_SCOPE" ]; then
    if [[ "$PACKAGE_SCOPE" != @* ]]; then
        echo "Error: Package scope must start with '@'. Current value: $PACKAGE_SCOPE"
        exit 1
    fi
fi

# Main execution
echo "Starting package migration with package-porter..."
if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode enabled. No actual publishing will be performed."
fi
log_verbose "Source Registry: $SOURCE_REGISTRY"
log_verbose "Target Registry: $TARGET_REGISTRY"
log_verbose "Package Name: $PACKAGE_NAME"
log_verbose "Package Scope: $PACKAGE_SCOPE"
log_verbose "Registry Type: $REGISTRY_TYPE"

# Create temporary npmrc files
create_npmrc_files

# Create directory for tarballs
mkdir -p ./tarballs
log_verbose "Created directory: ./tarballs"

# Fetch all versions
echo "Fetching all versions from source registry..."
VERSIONS=$(fetch_versions)
if [ $? -ne 0 ]; then
    echo "Failed to fetch versions. Exiting."
    exit 1
fi
echo "All versions from source registry: ${VERSIONS}"

if [ -z "$VERSIONS" ]; then
    echo "No versions found for package $PACKAGE_NAME in registry $SOURCE_REGISTRY"
    exit 1
fi

# Sort versions
SORTED_VERSIONS=($(sort_versions $VERSIONS))

if [ ${#SORTED_VERSIONS[@]} -eq 0 ]; then
    echo "Error: No valid versions found for package $PACKAGE_NAME"
    exit 1
fi

echo "Found valid versions (in ascending order): ${SORTED_VERSIONS[*]}"
log_verbose "Versions to migrate: ${SORTED_VERSIONS[*]}"

# Ensure temp directory is cleaned up on exit
trap "rm -rf ./tarballs" EXIT
log_verbose "Set up cleanup trap for temporary directories"

# Iterate over each version
for VERSION in "${SORTED_VERSIONS[@]}"; do
    echo "Processing version $VERSION"
    log_verbose "Starting migration for version $VERSION"

    # Download the specific version
    echo "Downloading version $VERSION..."
    if [ "$DRY_RUN" = false ]; then
        download_package $VERSION
        if [ $? -ne 0 ]; then
            echo "Failed to download version $VERSION of $PACKAGE_NAME"
            log_verbose "Download command failed for version $VERSION"
            continue
        fi
    else
        log_dry_run "Would download version $VERSION of $PACKAGE_NAME"
    fi

    # Get the generated tarball name (this might need adjustment for different registry types)
    TARBALL="${PACKAGE_NAME//\//-}-$VERSION.tgz"
    echo "File Name: $TARBALL"
    log_verbose "Generated tarball: $TARBALL"

    # Publish to target registry
    echo "Publishing version $VERSION to target registry..."
    if [ "$DRY_RUN" = false ]; then
        log_verbose "Running: npm publish ./tarballs/$TARBALL --registry $TARGET_REGISTRY --userconfig=$TARGET_NPMRC_FILE"
        npm publish "./tarballs/$TARBALL" --registry $TARGET_REGISTRY --userconfig=$TARGET_NPMRC_FILE
        if [ $? -ne 0 ]; then
            echo "Failed to publish version $VERSION of $PACKAGE_NAME"
            log_verbose "npm publish command failed for version $VERSION"
            continue
        fi
    else
        log_dry_run "Would run: npm publish ./tarballs/$TARBALL --registry $TARGET_REGISTRY --userconfig=$TARGET_NPMRC_FILE"
    fi

    # Remove the tarball to keep the temp directory clean
    echo "Cleaning up tarball for version $VERSION..."
    rm "./tarballs/$TARBALL"
    log_verbose "Removed tarball: ./tarballs/$TARBALL"
done

echo "Migration process completed."
if [ "$DRY_RUN" = true ]; then
    echo "This was a dry run. No actual publishing was performed."
fi
log_verbose "Migration process finished successfully"

# Clean up npmrc files
if [ "$DRY_RUN" = false ]; then
    rm -f "$SOURCE_NPMRC_FILE" "$TARGET_NPMRC_FILE"
    log_verbose "Removed npmrc files"
fi