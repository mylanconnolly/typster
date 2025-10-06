use std::fs;
use std::path::{Path, PathBuf};

use flate2::read::GzDecoder;
use tar::Archive;
use typst::syntax::package::PackageSpec;

use crate::TypstError;

/// The base URL for the Typst package registry
const PACKAGE_REGISTRY_URL: &str = "https://packages.typst.org";

/// Download and extract a package from the Typst registry
pub fn download_package(
    spec: &PackageSpec,
    cache_dir: &Path,
) -> Result<PathBuf, TypstError> {
    // Create cache directory structure: cache_dir/namespace/name/version
    let package_dir = cache_dir
        .join(spec.namespace.as_str())
        .join(spec.name.as_str())
        .join(spec.version.to_string());

    // Check if package already exists in cache
    if package_dir.exists() {
        return Ok(package_dir);
    }

    // Construct download URL
    let package_name = format!("{}-{}", spec.name.as_str(), spec.version);
    let url = format!("{}/{}/{}.tar.gz",
        PACKAGE_REGISTRY_URL,
        spec.namespace.as_str(),
        package_name
    );

    // Download the package
    let response = reqwest::blocking::get(&url)
        .map_err(|e| TypstError::PackageError(format!("Failed to download package: {}", e)))?;

    if !response.status().is_success() {
        return Err(TypstError::PackageError(format!(
            "Failed to download package {}: HTTP {}",
            package_name,
            response.status()
        )));
    }

    let bytes = response.bytes()
        .map_err(|e| TypstError::PackageError(format!("Failed to read package data: {}", e)))?;

    // Create parent directory
    fs::create_dir_all(package_dir.parent().unwrap())
        .map_err(|e| TypstError::IoError(format!("Failed to create cache directory: {}", e)))?;

    // Extract the tar.gz
    let decoder = GzDecoder::new(&bytes[..]);
    let mut archive = Archive::new(decoder);

    archive.unpack(&package_dir)
        .map_err(|e| TypstError::PackageError(format!("Failed to extract package: {}", e)))?;

    Ok(package_dir)
}

/// Get or create the default cache directory for Typst packages
pub fn get_cache_dir() -> Result<PathBuf, TypstError> {
    // Try to use the same cache directory as the official Typst CLI
    // On Unix: ~/.cache/typst/packages
    // On Windows: %LOCALAPPDATA%\typst\packages
    // On macOS: ~/Library/Caches/typst/packages

    let cache_dir = if cfg!(target_os = "macos") {
        dirs::home_dir()
            .map(|h| h.join("Library/Caches/typst/packages"))
    } else if cfg!(target_os = "windows") {
        dirs::cache_dir()
            .map(|c| c.join("typst/packages"))
    } else {
        dirs::cache_dir()
            .map(|c| c.join("typst/packages"))
    };

    cache_dir.ok_or_else(|| TypstError::IoError("Failed to determine cache directory".to_string()))
}

// Helper crate for directory lookup (using std dirs)
mod dirs {
    use std::env;
    use std::path::PathBuf;

    pub fn home_dir() -> Option<PathBuf> {
        env::var_os("HOME").map(PathBuf::from)
    }

    pub fn cache_dir() -> Option<PathBuf> {
        if cfg!(target_os = "windows") {
            env::var_os("LOCALAPPDATA").map(PathBuf::from)
        } else {
            env::var_os("XDG_CACHE_HOME")
                .map(PathBuf::from)
                .or_else(|| home_dir().map(|h| h.join(".cache")))
        }
    }
}
