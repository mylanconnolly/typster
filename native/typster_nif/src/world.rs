use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

use chrono::Datelike;
use typst::diag::FileResult;
use typst::foundations::{Bytes, Datetime, Dict, Value};
use typst::syntax::{FileId, Source, VirtualPath};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, World};
use typst_kit::fonts::{FontSlot, Fonts};

use crate::packages;
use crate::TypstError;

/// A simple implementation of the World trait for Typst compilation
pub struct TypstWorld {
    /// The root directory for resolving files
    root: PathBuf,
    /// Additional package directories to search
    package_paths: Vec<PathBuf>,
    /// Directory for caching downloaded packages
    package_cache_dir: PathBuf,
    /// The standard library
    library: LazyHash<Library>,
    /// Font book for font discovery
    book: LazyHash<FontBook>,
    /// Available fonts
    fonts: Vec<FontSlot>,
    /// Cache of loaded source files
    sources: HashMap<FileId, Source>,
    /// Main source file
    main: FileId,
    /// Cache of loaded files (non-source)
    files: HashMap<FileId, Bytes>,
    /// Mutex to ensure thread-safe package downloads
    download_lock: Mutex<()>,
}

impl TypstWorld {
    /// Create a new TypstWorld with the given source code, variables, and package paths
    pub fn new(
        source_code: String,
        variables: Dict,
        package_paths: Vec<PathBuf>,
        root_path: PathBuf,
    ) -> Result<Self, TypstError> {
        // Create a virtual path for the main source
        let main_path = VirtualPath::new("main.typ");
        let main_id = FileId::new(None, main_path);

        // Generate variable declarations
        let mut var_declarations = String::new();
        for (key, value) in variables.iter() {
            let typst_value = Self::value_to_typst_repr(value);
            var_declarations.push_str(&format!("#let {} = {}\n", key.as_str(), typst_value));
        }

        // Prepend variable declarations to the source code
        let full_source = if var_declarations.is_empty() {
            source_code
        } else {
            format!("{}\n{}", var_declarations, source_code)
        };

        // Parse the source
        let source = Source::new(main_id, full_source);

        // Initialize fonts
        let fonts = Self::search_fonts();

        let mut sources = HashMap::new();
        sources.insert(main_id, source);

        // Get or create the package cache directory
        let package_cache_dir = packages::get_cache_dir()?;

        Ok(Self {
            root: root_path,
            package_paths,
            package_cache_dir,
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(fonts.book.clone()),
            fonts: fonts.fonts,
            sources,
            main: main_id,
            files: HashMap::new(),
            download_lock: Mutex::new(()),
        })
    }

    /// Convert a Typst Value to its Typst code representation
    fn value_to_typst_repr(value: &Value) -> String {
        match value {
            Value::None => "none".to_string(),
            Value::Auto => "auto".to_string(),
            Value::Bool(b) => b.to_string(),
            Value::Int(i) => i.to_string(),
            Value::Float(f) => f.to_string(),
            Value::Str(s) => format!("\"{}\"", s.as_str().replace("\"", "\\\"")),
            Value::Array(arr) => {
                let items: Vec<String> = arr.iter().map(|v| Self::value_to_typst_repr(v)).collect();
                format!("({})", items.join(", "))
            }
            Value::Dict(dict) => {
                let items: Vec<String> = dict
                    .iter()
                    .map(|(k, v)| {
                        // Always quote dictionary keys to handle:
                        // - Keys with special characters (e.g., "2025-01" would be parsed as subtraction)
                        // - Keys that conflict with Typst built-ins (e.g., "h" for horizontal spacing)
                        format!(
                            "\"{}\": {}",
                            k.as_str().replace('\\', "\\\\").replace('"', "\\\""),
                            Self::value_to_typst_repr(v)
                        )
                    })
                    .collect();
                format!("({})", items.join(", "))
            }
            Value::Datetime(dt) => {
                // Convert Datetime to Typst datetime constructor call
                match (
                    dt.year(),
                    dt.month(),
                    dt.day(),
                    dt.hour(),
                    dt.minute(),
                    dt.second(),
                ) {
                    (Some(y), Some(m), Some(d), Some(h), Some(min), Some(s)) => {
                        // Full datetime
                        format!("datetime(year: {}, month: {}, day: {}, hour: {}, minute: {}, second: {})", y, m, d, h, min, s)
                    }
                    (Some(y), Some(m), Some(d), None, None, None) => {
                        // Date only
                        format!("datetime(year: {}, month: {}, day: {})", y, m, d)
                    }
                    (None, None, None, Some(h), Some(min), Some(s)) => {
                        // Time only
                        format!("datetime(hour: {}, minute: {}, second: {})", h, min, s)
                    }
                    _ => "none".to_string(), // Invalid datetime
                }
            }
            _ => "none".to_string(), // For unsupported types, use none
        }
    }

    /// Search for system fonts
    fn search_fonts() -> Fonts {
        let fonts = Fonts::searcher()
            .include_system_fonts(true)
            .include_embedded_fonts(true)
            .search();

        fonts
    }

    /// Resolve a FileId to an actual file system path
    fn resolve_path(&self, id: FileId) -> FileResult<PathBuf> {
        // Check if this is a package file
        if let Some(package) = id.package() {
            // Try to find the package in configured package_paths first
            for package_root in &self.package_paths {
                // Package format: @namespace/name/version
                let package_dir = package_root
                    .join(package.namespace.as_str())
                    .join(package.name.as_str())
                    .join(package.version.to_string());

                if let Some(resolved) = id.vpath().resolve(&package_dir) {
                    if resolved.exists() {
                        return Ok(resolved);
                    }
                }
            }

            // Not found in package_paths, try the cache directory
            let cache_package_dir = self
                .package_cache_dir
                .join(package.namespace.as_str())
                .join(package.name.as_str())
                .join(package.version.to_string());

            if let Some(resolved) = id.vpath().resolve(&cache_package_dir) {
                if resolved.exists() {
                    return Ok(resolved);
                }
            }

            // Not in cache either, try to download it
            // Use a lock to prevent concurrent downloads of the same package
            let _lock = self.download_lock.lock().unwrap();

            // Check again after acquiring lock (another thread might have downloaded it)
            if let Some(resolved) = id.vpath().resolve(&cache_package_dir) {
                if resolved.exists() {
                    return Ok(resolved);
                }
            }

            // Download the package
            let downloaded_dir = packages::download_package(package, &self.package_cache_dir)
                .map_err(|e| typst::diag::FileError::Other(Some(e.to_string().into())))?;

            // Now try to resolve the path again
            id.vpath().resolve(&downloaded_dir).ok_or_else(|| {
                typst::diag::FileError::NotFound(id.vpath().as_rootless_path().into())
            })
        } else {
            // Not a package file, resolve relative to root
            id.vpath().resolve(&self.root).ok_or_else(|| {
                typst::diag::FileError::NotFound(id.vpath().as_rootless_path().into())
            })
        }
    }
}

impl World for TypstWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.main
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        // Check cache first
        if let Some(source) = self.sources.get(&id) {
            return Ok(source.clone());
        }

        // Try to load the source file from disk
        let path = self.resolve_path(id)?;
        let content = std::fs::read_to_string(&path)
            .map_err(|e| typst::diag::FileError::from_io(e, &path))?;

        Ok(Source::new(id, content))
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        // Check cache first
        if let Some(bytes) = self.files.get(&id) {
            return Ok(bytes.clone());
        }

        // Try to resolve the file path
        let path = self.resolve_path(id)?;

        // Read the file
        let bytes = std::fs::read(&path).map_err(|e| typst::diag::FileError::from_io(e, &path))?;

        Ok(Bytes::new(bytes))
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index)?.get()
    }

    fn today(&self, offset: Option<i64>) -> Option<Datetime> {
        let now = chrono::Local::now();
        let offset_hours = offset.unwrap_or(0);
        let offset_duration = chrono::Duration::hours(offset_hours);
        let adjusted = now + offset_duration;

        Datetime::from_ymd(
            adjusted.year(),
            adjusted.month().try_into().ok()?,
            adjusted.day().try_into().ok()?,
        )
    }
}
