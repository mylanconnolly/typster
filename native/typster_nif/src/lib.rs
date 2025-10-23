mod convert;
mod packages;
mod world;

use rustler::types::Binary;
use rustler::{Env, Error as RustlerError, NifStruct, OwnedBinary, Term};
use std::collections::HashMap;
use std::fmt;
use typst::layout::PagedDocument;

use world::TypstWorld;

/// Custom error type for Typster operations
#[derive(Debug)]
pub enum TypstError {
    CompileError(String),
    RenderError(String),
    PackageError(String),
    IoError(String),
    InvalidInput(String),
}

/// Options for configuring Typster compilation
#[derive(NifStruct)]
#[module = "Typster.Native.TypsterOptions"]
struct TypsterOptions<'a> {
    metadata: HashMap<String, String>,
    pixel_per_pt: f32,
    package_paths: Vec<String>,
    root_path: String,
    variables: Term<'a>,
}

impl fmt::Display for TypstError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            TypstError::CompileError(msg) => write!(f, "Compilation error: {}", msg),
            TypstError::RenderError(msg) => write!(f, "Render error: {}", msg),
            TypstError::PackageError(msg) => write!(f, "Package error: {}", msg),
            TypstError::IoError(msg) => write!(f, "IO error: {}", msg),
            TypstError::InvalidInput(msg) => write!(f, "Invalid input: {}", msg),
        }
    }
}

impl std::error::Error for TypstError {}

impl From<TypstError> for RustlerError {
    fn from(err: TypstError) -> Self {
        RustlerError::Term(Box::new(err.to_string()))
    }
}

impl From<std::io::Error> for TypstError {
    fn from(err: std::io::Error) -> Self {
        TypstError::IoError(err.to_string())
    }
}

impl From<serde_json::Error> for TypstError {
    fn from(err: serde_json::Error) -> Self {
        TypstError::InvalidInput(format!("JSON error: {}", err))
    }
}

impl From<RustlerError> for TypstError {
    fn from(err: RustlerError) -> Self {
        TypstError::InvalidInput(format!("Rustler error: {:?}", err))
    }
}

/// Result type alias for Typster operations
pub type TypstResult<T> = Result<T, TypstError>;

/// Generate a #set document() statement from metadata map
fn generate_document_metadata(metadata: std::collections::HashMap<String, String>) -> String {
    if metadata.is_empty() {
        return String::new();
    }

    let mut parts = Vec::new();

    if let Some(title) = metadata.get("title") {
        parts.push(format!("title: \"{}\"", title.replace("\"", "\\\"")));
    }

    if let Some(author) = metadata.get("author") {
        parts.push(format!("author: \"{}\"", author.replace("\"", "\\\"")));
    }

    if let Some(description) = metadata.get("description") {
        parts.push(format!(
            "description: \"{}\"",
            description.replace("\"", "\\\"")
        ));
    }

    if let Some(keywords) = metadata.get("keywords") {
        // Keywords can be comma-separated string
        let keywords_list: Vec<String> = keywords
            .split(',')
            .map(|k| format!("\"{}\"", k.trim().replace("\"", "\\\"")))
            .collect();
        parts.push(format!("keywords: ({})", keywords_list.join(", ")));
    }

    if let Some(date) = metadata.get("date") {
        let date_lower = date.to_lowercase();
        if date_lower == "auto" {
            parts.push("date: auto".to_string());
        } else if date_lower == "none" {
            parts.push("date: none".to_string());
        } else {
            // Assume it's a datetime string - for now, just skip it
            // Full datetime support would require parsing the format
            // Users can set the date directly in the template if needed
        }
    }

    if parts.is_empty() {
        String::new()
    } else {
        format!("#set document({})\n", parts.join(", "))
    }
}

fn world_from_options<'a>(
    env: Env<'a>,
    source: String,
    options: &TypsterOptions<'a>,
) -> TypstResult<TypstWorld> {
    // Generate metadata statement
    let metadata_stmt = generate_document_metadata(options.metadata.clone());

    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, options.variables.clone())
        .map_err(|e| TypstError::InvalidInput(format!("Failed to convert variables: {}", e)))?;

    // Convert package path strings to PathBufs
    let paths: Vec<std::path::PathBuf> = options
        .package_paths
        .iter()
        .map(|p| std::path::PathBuf::from(p))
        .collect();

    // Prepend metadata to source
    let full_source = if metadata_stmt.is_empty() {
        source
    } else {
        format!("{}{}", metadata_stmt, source)
    };

    // Convert root path string to PathBuf
    let root_path = std::path::PathBuf::from(options.root_path.clone());

    // Create the world with the full source code, variables, and package paths
    let world = TypstWorld::new(full_source, var_dict, paths, root_path)
        .map_err(|e| TypstError::CompileError(format!("Failed to create world: {}", e)))?;

    Ok(world)
}

// Placeholder NIF function - will be replaced with actual implementation
#[rustler::nif]
fn test_nif() -> String {
    "Typster NIF loaded successfully".to_string()
}

/// Compile a Typst template to PDF with options
#[rustler::nif]
fn compile_to_pdf<'a>(
    env: Env<'a>,
    source: String,
    options: TypsterOptions<'a>,
) -> Result<Binary<'a>, String> {
    // Create the world with the source code and options
    let world = world_from_options(env, source, &options)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document = typst::compile(&world).output.map_err(|errors| {
        let error_messages: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
        format!("Compilation failed: {}", error_messages.join(", "))
    })?;

    // Render to PDF with default options
    let pdf_options = typst_pdf::PdfOptions::default();
    let pdf_bytes = typst_pdf::pdf(&document, &pdf_options).map_err(|errors| {
        let error_messages: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
        format!("PDF generation failed: {}", error_messages.join(", "))
    })?;

    // Convert Vec<u8> to Binary
    let mut binary = OwnedBinary::new(pdf_bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&pdf_bytes);

    Ok(binary.release(env))
}

/// Compile a Typst template to SVG
#[rustler::nif]
fn compile_to_svg<'a>(
    env: Env<'a>,
    source: String,
    options: TypsterOptions<'a>,
) -> Result<Vec<String>, String> {
    // Create the world with the source code and options
    let world = world_from_options(env, source, &options)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document: PagedDocument = typst::compile(&world).output.map_err(|errors| {
        let error_messages: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
        format!("Compilation failed: {}", error_messages.join(", "))
    })?;

    // Render each page to SVG
    let mut svg_pages = Vec::new();
    for page in document.pages.iter() {
        let svg = typst_svg::svg(page);
        svg_pages.push(svg);
    }

    Ok(svg_pages)
}

/// Compile a Typst template to PNG with options
#[rustler::nif]
fn compile_to_png<'a>(
    env: Env<'a>,
    source: String,
    options: TypsterOptions<'a>,
) -> Result<Vec<Binary<'a>>, String> {
    // Create the world with the source code and options
    let world = world_from_options(env, source, &options)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document: PagedDocument = typst::compile(&world).output.map_err(|errors| {
        let error_messages: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
        format!("Compilation failed: {}", error_messages.join(", "))
    })?;

    // Render each page to PNG
    let mut png_pages = Vec::new();
    for page in document.pages.iter() {
        let pixmap = typst_render::render(page, options.pixel_per_pt);
        let png_bytes = pixmap
            .encode_png()
            .map_err(|e| format!("PNG encoding failed: {}", e))?;

        // Convert to Binary
        let mut binary = OwnedBinary::new(png_bytes.len()).unwrap();
        binary.as_mut_slice().copy_from_slice(&png_bytes);
        png_pages.push(binary.release(env));
    }

    Ok(png_pages)
}

/// Check the syntax of a Typst template without rendering
/// Returns a list of error messages if compilation fails, or an empty list if successful
#[rustler::nif]
fn check_syntax<'a>(
    env: Env<'a>,
    source: String,
    options: TypsterOptions<'a>,
) -> Result<Vec<String>, String> {
    // Create the world with the source code and options
    let world = world_from_options(env, source, &options)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Attempt to compile the document
    match typst::compile::<PagedDocument>(&world).output {
        Ok(_) => Ok(Vec::new()), // Success - return empty list
        Err(errors) => {
            // Extract error messages
            let error_messages: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
            Ok(error_messages) // Return list of errors
        }
    }
}

rustler::init!("Elixir.Typster.Native");
