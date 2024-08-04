use crate::config::Config;
use crate::package_managers::PackageManager;
use log::{debug, info};
use std::error::Error;
use std::fs::File;
use std::io::Write;
use std::process::Command;
use url::Url;

pub struct NpmPackageManager;

impl PackageManager for NpmPackageManager {
    fn fetch_versions(config: &Config) -> Result<Vec<String>, Box<dyn Error>> {
        let npmrc_path = create_temp_npmrc(
            &config.source_registry,
            &config.source_auth_token,
            &config.package_scope,
        )?;

        let mut command = Command::new("npm");
        command
            .arg("view")
            .arg(&config.full_package_name())
            .arg("versions")
            .arg("--json")
            .arg("--userconfig")
            .arg(npmrc_path.clone());

        // Log the command
        info!("Executing npm command: {:?}", command);

        let output = command.output()?;

        // Clean up the temporary .npmrc file
        std::fs::remove_file(npmrc_path)?;

        if !output.status.success() {
            let error_message = String::from_utf8_lossy(&output.stderr);
            if error_message.contains("E404") || error_message.contains("404 Not Found") {
                return Err(format!(
                    "Package '{}' not found in registry '{}'",
                    config.package_name, config.source_registry
                )
                .into());
            } else {
                return Err(format!("Failed to fetch versions: {}", error_message).into());
            }
        }

        let versions: Vec<String> = serde_json::from_slice(&output.stdout)?;

        Ok(versions)
    }

    fn download_package(config: &Config, version: &str) -> Result<String, Box<dyn Error>> {
        let npmrc_path = create_temp_npmrc(
            &config.source_registry,
            &config.source_auth_token,
            &config.package_scope,
        )?;

        let mut command = Command::new("npm");
        command
            .arg("pack")
            .arg(format!("{}@{}", config.package_name, version))
            .arg("--userconfig")
            .arg(&npmrc_path);

        // Log the command
        info!("Executing npm command: {:?}", command);

        let output = command.output()?;

        // Clean up the temporary .npmrc file
        std::fs::remove_file(npmrc_path)?;

        if !output.status.success() {
            return Err(format!("Failed to download package: {:?}", output.stderr).into());
        }

        let filename = String::from_utf8(output.stdout)?.trim().to_string();
        Ok(filename)
    }

    fn publish_package(config: &Config, package: &str) -> Result<(), Box<dyn Error>> {
        let npmrc_path = create_temp_npmrc(
            &config.target_registry,
            &config.target_auth_token,
            &config.package_scope,
        )?;

        let mut command = Command::new("npm");
        command
            .arg("publish")
            .arg(package)
            .arg("--userconfig")
            .arg(&npmrc_path);

        // Log the command
        info!("Executing npm command: {:?}", command);

        let output = command.output()?;

        // Clean up the temporary .npmrc file
        std::fs::remove_file(npmrc_path)?;

        if !output.status.success() {
            return Err(format!("Failed to publish package: {:?}", output.stderr).into());
        }

        Ok(())
    }
}

fn create_temp_npmrc(
    registry: &str,
    auth_token: &str,
    scope: &Option<String>,
) -> Result<String, Box<dyn Error>> {
    let temp_dir = std::env::temp_dir();
    let npmrc_path = temp_dir.join(".npmrc");
    let mut file = File::create(&npmrc_path)?;

    let registry_url = Url::parse(registry)?;
    let registry_host = registry_url.host_str().ok_or("Invalid registry URL")?;

    let npmrc_content = match scope {
        Some(s) => format!(
            "{}:registry={}\n//{}/:_authToken={}\n",
            s, registry, registry_host, auth_token
        ),
        None => format!(
            "registry={}\n//{}/:_authToken={}\n",
            registry, registry_host, auth_token
        ),
    };

    file.write_all(npmrc_content.as_bytes())?;

    // Log the content of the .npmrc file
    debug!(
        "Created temporary .npmrc file at {:?} with content:\n{}",
        npmrc_path, npmrc_content
    );

    Ok(npmrc_path.to_string_lossy().into_owned())
}
