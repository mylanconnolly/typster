mod convert;
mod packages;
mod world;

use rustler::types::Binary;
use rustler::{Env, Error as RustlerError, OwnedBinary, Term};
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
        parts.push(format!("description: \"{}\"", description.replace("\"", "\\\"")));
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

// Placeholder NIF function - will be replaced with actual implementation
#[rustler::nif]
fn test_nif() -> String {
    "Typster NIF loaded successfully".to_string()
}

/// Compile a Typst template to PDF
#[rustler::nif]
fn compile_to_pdf<'a>(env: Env<'a>, source: String) -> Result<Binary<'a>, String> {
    // Create the world with the source code
    let world = TypstWorld::new(source)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("Compilation failed: {}", error_messages.join(", "))
        })?;

    // Render to PDF with default options
    let pdf_options = typst_pdf::PdfOptions::default();
    let pdf_bytes = typst_pdf::pdf(&document, &pdf_options)
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("PDF generation failed: {}", error_messages.join(", "))
        })?;

    // Convert Vec<u8> to Binary
    let mut binary = OwnedBinary::new(pdf_bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&pdf_bytes);

    Ok(binary.release(env))
}

/// Compile a Typst template to PDF with variables
#[rustler::nif]
fn compile_to_pdf_with_variables<'a>(env: Env<'a>, source: String, variables: Term<'a>) -> Result<Binary<'a>, String> {
    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, variables)
        .map_err(|e| format!("Failed to convert variables: {}", e))?;

    // Create the world with the source code and variables
    let world = TypstWorld::new_with_variables(source, var_dict)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("Compilation failed: {}", error_messages.join(", "))
        })?;

    // Render to PDF with default options
    let pdf_options = typst_pdf::PdfOptions::default();
    let pdf_bytes = typst_pdf::pdf(&document, &pdf_options)
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("PDF generation failed: {}", error_messages.join(", "))
        })?;

    // Convert Vec<u8> to Binary
    let mut binary = OwnedBinary::new(pdf_bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&pdf_bytes);

    Ok(binary.release(env))
}

/// Compile a Typst template to PDF with variables and package paths
#[rustler::nif]
fn compile_to_pdf_with_options<'a>(
    env: Env<'a>,
    source: String,
    variables: Term<'a>,
    package_paths: Vec<String>,
) -> Result<Binary<'a>, String> {
    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, variables)
        .map_err(|e| format!("Failed to convert variables: {}", e))?;

    // Convert package path strings to PathBufs
    let paths: Vec<std::path::PathBuf> = package_paths
        .into_iter()
        .map(std::path::PathBuf::from)
        .collect();

    // Create the world with the source code, variables, and package paths
    let world = TypstWorld::new_with_options(source, var_dict, paths)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("Compilation failed: {}", error_messages.join(", "))
        })?;

    // Render to PDF with default options
    let pdf_options = typst_pdf::PdfOptions::default();
    let pdf_bytes = typst_pdf::pdf(&document, &pdf_options)
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("PDF generation failed: {}", error_messages.join(", "))
        })?;

    // Convert Vec<u8> to Binary
    let mut binary = OwnedBinary::new(pdf_bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&pdf_bytes);

    Ok(binary.release(env))
}

/// Compile a Typst template to PDF with full options including metadata
#[rustler::nif]
fn compile_to_pdf_with_full_options<'a>(
    env: Env<'a>,
    source: String,
    variables: Term<'a>,
    package_paths: Vec<String>,
    metadata: HashMap<String, String>,
) -> Result<Binary<'a>, String> {
    // Generate metadata statement
    let metadata_stmt = generate_document_metadata(metadata);

    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, variables)
        .map_err(|e| format!("Failed to convert variables: {}", e))?;

    // Convert package path strings to PathBufs
    let paths: Vec<std::path::PathBuf> = package_paths
        .into_iter()
        .map(std::path::PathBuf::from)
        .collect();

    // Prepend metadata to source
    let full_source = if metadata_stmt.is_empty() {
        source
    } else {
        format!("{}{}", metadata_stmt, source)
    };

    // Create the world with the full source code, variables, and package paths
    let world = TypstWorld::new_with_options(full_source, var_dict, paths)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("Compilation failed: {}", error_messages.join(", "))
        })?;

    // Render to PDF with default options
    let pdf_options = typst_pdf::PdfOptions::default();
    let pdf_bytes = typst_pdf::pdf(&document, &pdf_options)
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("PDF generation failed: {}", error_messages.join(", "))
        })?;

    // Convert Vec<u8> to Binary
    let mut binary = OwnedBinary::new(pdf_bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&pdf_bytes);

    Ok(binary.release(env))
}

/// Compile a Typst template to SVG
#[rustler::nif]
fn compile_to_svg_with_options<'a>(
    env: Env<'a>,
    source: String,
    variables: Term<'a>,
    package_paths: Vec<String>,
) -> Result<Vec<String>, String> {
    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, variables)
        .map_err(|e| format!("Failed to convert variables: {}", e))?;

    // Convert package path strings to PathBufs
    let paths: Vec<std::path::PathBuf> = package_paths
        .into_iter()
        .map(std::path::PathBuf::from)
        .collect();

    // Create the world with the source code, variables, and package paths
    let world = TypstWorld::new_with_options(source, var_dict, paths)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document: PagedDocument = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
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
fn compile_to_png_with_options<'a>(
    env: Env<'a>,
    source: String,
    variables: Term<'a>,
    package_paths: Vec<String>,
    pixel_per_pt: f32,
) -> Result<Vec<Binary<'a>>, String> {
    // Convert Elixir variables to Typst Dict
    let var_dict = convert::terms_to_dict(env, variables)
        .map_err(|e| format!("Failed to convert variables: {}", e))?;

    // Convert package path strings to PathBufs
    let paths: Vec<std::path::PathBuf> = package_paths
        .into_iter()
        .map(std::path::PathBuf::from)
        .collect();

    // Create the world with the source code, variables, and package paths
    let world = TypstWorld::new_with_options(source, var_dict, paths)
        .map_err(|e| format!("Failed to create world: {}", e))?;

    // Compile the document
    let document: PagedDocument = typst::compile(&world)
        .output
        .map_err(|errors| {
            let error_messages: Vec<String> = errors
                .iter()
                .map(|e| format!("{:?}", e))
                .collect();
            format!("Compilation failed: {}", error_messages.join(", "))
        })?;

    // Render each page to PNG
    let mut png_pages = Vec::new();
    for page in document.pages.iter() {
        let pixmap = typst_render::render(page, pixel_per_pt);
        let png_bytes = pixmap.encode_png()
            .map_err(|e| format!("PNG encoding failed: {}", e))?;

        // Convert to Binary
        let mut binary = OwnedBinary::new(png_bytes.len()).unwrap();
        binary.as_mut_slice().copy_from_slice(&png_bytes);
        png_pages.push(binary.release(env));
    }

    Ok(png_pages)
}

rustler::init!("Elixir.Typster.Native");
