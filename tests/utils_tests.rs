use package_porter::utils::sort_versions;

#[test]
fn test_sort_versions() {
    let versions = vec![
        "1.0.0".to_string(),
        "2.0.0".to_string(),
        "1.1.0".to_string(),
        "1.0.1".to_string(),
        "1.0.0-alpha".to_string(),
        "1.0.0-beta".to_string(),
        "0.9.9".to_string(),
    ];

    let sorted = sort_versions(versions);
    assert_eq!(
        sorted,
        vec![
            "0.9.9",
            "1.0.0-alpha",
            "1.0.0-beta",
            "1.0.0",
            "1.0.1",
            "1.1.0",
            "2.0.0"
        ]
    );
}

// #[test]
// fn test_is_valid_semver() {
//     assert!(is_valid_semver("1.0.0"));
//     assert!(is_valid_semver("1.0.0-alpha"));
//     assert!(is_valid_semver("1.0.0+build.1"));
//     assert!(!is_valid_semver("1.0"));
//     assert!(!is_valid_semver("v1.0.0"));
// }

// #[test]
// fn test_normalize_version() {
//     assert_eq!(normalize_version("1.0.0"), Some("1.0.0".to_string()));
//     assert_eq!(
//         normalize_version("1.0.0-alpha"),
//         Some("1.0.0-alpha".to_string())
//     );
//     assert_eq!(normalize_version("1.0"), None);
//     assert_eq!(normalize_version("v1.0.0"), None);
// }
