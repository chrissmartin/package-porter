use dotenv::dotenv;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub source_registry: String,
    pub target_registry: String,
    pub package_name: String,
    pub package_scope: Option<String>,
    pub source_auth_token: String,
    pub target_auth_token: String,
    pub registry_type: String,
    pub verbose: bool,
    pub dry_run: bool,
}

impl Config {
    pub fn from_env() -> Result<Self, env::VarError> {
        dotenv().ok(); // This will load the .env file

        Ok(Config {
            source_registry: env::var("SOURCE_REGISTRY")?,
            target_registry: env::var("TARGET_REGISTRY")?,
            package_name: env::var("PACKAGE_NAME")?,
            package_scope: env::var("PACKAGE_SCOPE").ok(),
            source_auth_token: env::var("SOURCE_AUTH_TOKEN")?,
            target_auth_token: env::var("TARGET_AUTH_TOKEN")?,
            registry_type: env::var("REGISTRY_TYPE")?,
            verbose: env::var("VERBOSE").map(|v| v == "true").unwrap_or(false),
            dry_run: env::var("DRY_RUN").map(|v| v == "true").unwrap_or(false),
        })
    }

    pub fn full_package_name(&self) -> String {
        match &self.package_scope {
            Some(scope) => format!("{}/{}", scope, self.package_name),
            None => self.package_name.clone(),
        }
    }
}