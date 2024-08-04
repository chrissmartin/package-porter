pub mod npm;
pub mod pypi;

use crate::config::Config;
use std::error::Error;

pub trait PackageManager {
    fn fetch_versions(config: &Config) -> Result<Vec<String>, Box<dyn Error>>;
    fn download_package(config: &Config, version: &str) -> Result<String, Box<dyn Error>>;
    fn publish_package(config: &Config, package: &str) -> Result<(), Box<dyn Error>>;
}

pub fn fetch_versions(config: &Config) -> Result<Vec<String>, Box<dyn Error>> {
    match config.registry_type.as_str() {
        "npm" => npm::NpmPackageManager::fetch_versions(config),
        "pypi" => pypi::PyPiPackageManager::fetch_versions(config),
        _ => Err("Unsupported registry type".into()),
    }
}

pub fn download_package(config: &Config, version: &str) -> Result<String, Box<dyn Error>> {
    match config.registry_type.as_str() {
        "npm" => npm::NpmPackageManager::download_package(config, version),
        "pypi" => pypi::PyPiPackageManager::download_package(config, version),
        _ => Err("Unsupported registry type".into()),
    }
}

pub fn publish_package(config: &Config, package: &str) -> Result<(), Box<dyn Error>> {
    match config.registry_type.as_str() {
        "npm" => npm::NpmPackageManager::publish_package(config, package),
        "pypi" => pypi::PyPiPackageManager::publish_package(config, package),
        _ => Err("Unsupported registry type".into()),
    }
}
