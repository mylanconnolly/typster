defmodule Typster.Native do
  @moduledoc """
  Native Implemented Functions (NIFs) for Typster.

  This module provides the low-level Rust NIF interface for Typst compilation
  and rendering. Most users should use the high-level `Typster` module instead,
  which provides a more ergonomic API with better error handling.

  ## Available NIFs

  - `test_nif/0` - Basic connectivity test
  - `compile_to_pdf/1` - Simple PDF compilation
  - `compile_to_pdf_with_variables/2` - PDF with variable binding
  - `compile_to_pdf_with_options/3` - PDF with packages
  - `compile_to_pdf_with_full_options/4` - PDF with metadata
  - `compile_to_svg_with_options/3` - Multi-page SVG
  - `compile_to_png_with_options/4` - Multi-page PNG

  ## Note

  These functions return raw results from the Rust layer and should not be
  called directly unless you need low-level control. Use the `Typster` module
  for the recommended API.
  """

  use Rustler, otp_app: :typster, crate: "typster_nif"

  # Placeholder functions - these will be replaced by the actual NIF implementations
  # If the NIF is not loaded, these fallback implementations will be called

  def test_nif, do: :erlang.nif_error(:nif_not_loaded)
  def compile_to_pdf(_source), do: :erlang.nif_error(:nif_not_loaded)
  def compile_to_pdf_with_variables(_source, _variables), do: :erlang.nif_error(:nif_not_loaded)

  def compile_to_pdf_with_options(_source, _variables, _package_paths),
    do: :erlang.nif_error(:nif_not_loaded)

  def compile_to_pdf_with_full_options(_source, _variables, _package_paths, _metadata),
    do: :erlang.nif_error(:nif_not_loaded)

  def compile_to_svg_with_options(_source, _variables, _package_paths),
    do: :erlang.nif_error(:nif_not_loaded)

  def compile_to_png_with_options(_source, _variables, _package_paths, _pixel_per_pt),
    do: :erlang.nif_error(:nif_not_loaded)
end
