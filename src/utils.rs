use semver::Version;
use std::cmp::Ordering;
use url::Url;

pub fn sort_versions(versions: Vec<String>) -> Vec<String> {
    let mut parsed_versions: Vec<(String, Option<Version>)> = versions
        .into_iter()
        .map(|v| (v.clone(), Version::parse(&v).ok()))
        .collect();

    parsed_versions.sort_by(|a, b| match (&a.1, &b.1) {
        (Some(v1), Some(v2)) => v1.cmp(v2),
        (Some(_), None) => Ordering::Greater,
        (None, Some(_)) => Ordering::Less,
        (None, None) => a.0.cmp(&b.0),
    });

    parsed_versions.into_iter().map(|(v, _)| v).collect()
}

pub fn validate_and_normalize_url(url: String) -> Result<String, Box<dyn std::error::Error>> {
    let mut parsed_url = Url::parse(&url).map_err(|e| format!("Invalid URL '{}': {}", url, e))?;

    if !parsed_url.path().ends_with('/') {
        parsed_url.set_path(&format!("{}/", parsed_url.path()));
    }

    Ok(parsed_url.to_string())
}

// pub fn is_valid_semver(version: &str) -> bool {
//     Version::parse(version).is_ok()
// }

// pub fn normalize_version(version: &str) -> Option<String> {
//     Version::parse(version).ok().map(|v| v.to_string())
// }
