use crate::config::Config;
use crate::utils::validate_and_normalize_url;
use clap::{Arg, ArgAction, Command};
use std::error::Error;

pub fn parse_args() -> Result<Config, Box<dyn Error>> {
    let env_config = Config::from_env()?;

    let matches = Command::new("package-porter")
        .version("1.0")
        .author("Chriss Martin")
        .about("Universal Package Migration Tool")
        .arg(
            Arg::new("source-registry")
                .short('s')
                .long("source-registry")
                .value_name("URL")
                .help("Source registry URL"),
        )
        .arg(
            Arg::new("target-registry")
                .short('t')
                .long("target-registry")
                .value_name("URL")
                .help("Target registry URL"),
        )
        .arg(
            Arg::new("package")
                .short('p')
                .long("package")
                .value_name("NAME")
                .help("Package name"),
        )
        .arg(
            Arg::new("scope")
                .long("scope")
                .value_name("SCOPE")
                .help("Package scope (if applicable)"),
        )
        .arg(
            Arg::new("registry-type")
                .short('r')
                .long("registry-type")
                .value_name("TYPE")
                .help("Registry type (npm, pypi)"),
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .help("Enable verbose output")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("dry-run")
                .long("dry-run")
                .help("Perform a dry run without actual publishing")
                .action(ArgAction::SetTrue),
        )
        .get_matches();

    let source_registry = validate_and_normalize_url(
        matches
            .get_one::<String>("source-registry")
            .map(|s| s.to_string())
            .unwrap_or(env_config.source_registry),
    )?;

    let target_registry = validate_and_normalize_url(
        matches
            .get_one::<String>("target-registry")
            .map(|s| s.to_string())
            .unwrap_or(env_config.target_registry),
    )?;

    Ok(Config {
        source_registry,
        target_registry,
        package_name: matches
            .get_one::<String>("package")
            .map(|s| s.to_string())
            .unwrap_or(env_config.package_name),
        package_scope: matches
            .get_one::<String>("scope")
            .map(|s| s.to_string())
            .or(env_config.package_scope),
        source_auth_token: env_config.source_auth_token,
        target_auth_token: env_config.target_auth_token,
        registry_type: matches
            .get_one::<String>("registry-type")
            .map(|s| s.to_string())
            .unwrap_or(env_config.registry_type),
        verbose: matches.get_flag("verbose") || env_config.verbose,
        dry_run: matches.get_flag("dry-run") || env_config.dry_run,
    })
}
