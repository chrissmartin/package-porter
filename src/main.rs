mod cli;
mod config;
mod package_managers;
mod utils;
use log::info;

use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    env_logger::init();
    info!("Starting package-porter");
    let config = cli::parse_args()?;

    if config.verbose {
        println!("Using configuration: {:?}", config);
    }

    let versions = package_managers::fetch_versions(&config)?;

    let sorted_versions = utils::sort_versions(versions);

    for version in sorted_versions {
        println!("Processing version {}", version);
        if !config.dry_run {
            let package = package_managers::download_package(&config, &version)?;
            package_managers::publish_package(&config, &package)?;
        } else {
            println!("Dry run: Would process version {}", version);
        }
    }

    Ok(())
}
