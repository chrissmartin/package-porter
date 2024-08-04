use crate::config::Config;
use crate::package_managers::PackageManager;
use reqwest;
use serde_json::Value;
use std::error::Error;
use std::process::Command;

pub struct PyPiPackageManager;

impl PackageManager for PyPiPackageManager {
    fn fetch_versions(config: &Config) -> Result<Vec<String>, Box<dyn Error>> {
        let url = format!(
            "{}/pypi/{}/json",
            config.source_registry, config.package_name
        );
        let response: Value = reqwest::blocking::get(&url)?.json()?;

        let versions = response["releases"]
            .as_object()
            .ok_or("Failed to parse releases")?
            .keys()
            .map(|v| v.to_string())
            .collect();

        Ok(versions)
    }

    fn download_package(config: &Config, version: &str) -> Result<String, Box<dyn Error>> {
        let output = Command::new("pip")
            .arg("download")
            .arg(format!("{}=={}", config.package_name, version))
            .arg("-d")
            .arg(".")
            .arg("--no-deps")
            .arg("--index-url")
            .arg(&config.source_registry)
            .output()?;

        if !output.status.success() {
            return Err(format!("Failed to download package: {:?}", output.stderr).into());
        }

        let filename = format!("{}-{}.tar.gz", config.package_name, version);
        Ok(filename)
    }

    fn publish_package(config: &Config, package: &str) -> Result<(), Box<dyn Error>> {
        let output = Command::new("twine")
            .arg("upload")
            .arg(package)
            .arg("--repository-url")
            .arg(&config.target_registry)
            .output()?;

        if !output.status.success() {
            return Err(format!("Failed to publish package: {:?}", output.stderr).into());
        }

        Ok(())
    }
}
