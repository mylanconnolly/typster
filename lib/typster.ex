defmodule Typster do
  @moduledoc """
  High-level API for rendering Typst templates to PDF, SVG, and PNG formats.

  Typster is an Elixir wrapper for the Typst document preparation system,
  providing easy-to-use functions for compiling Typst templates with variable
  binding, package support, and metadata injection.

  ## Quick Start

      # Simple PDF rendering
      source = "#set page(width: 200pt, height: 100pt)\\n= Hello World"
      {:ok, pdf} = Typster.render_pdf(source)
      File.write!("output.pdf", pdf)

      # With variables
      template = "= Invoice for #customer_name"
      {:ok, pdf} = Typster.render_pdf(template, %{customer_name: "Acme Corp"})

      # With metadata
      {:ok, pdf} = Typster.render_pdf(template, %{},
        metadata: %{title: "Invoice", author: "Billing System"})

  ## Formats

  Typster supports three output formats:
  - **PDF**: Single binary output
  - **SVG**: List of SVG strings (one per page)
  - **PNG**: List of PNG binaries (one per page)

  ## Options

  All render functions accept an options keyword list:
  - `:variables` - Map of variables to bind into the template
  - `:package_paths` - List of local package directories
  - `:metadata` - Map of PDF metadata (title, author, description, keywords, date)
  - `:pixel_per_pt` - PNG resolution (default: 2.0)

  ## Concurrency

  Typster is fully thread-safe and supports concurrent rendering from multiple processes.
  The underlying Rust NIFs can handle parallel execution efficiently:

      # Render multiple documents concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          Typster.render_pdf(template, %{id: i})
        end)
      end

      results = Task.await_many(tasks)

  **Performance**: Tested with 100 concurrent renders completing in ~22ms total.

  **Package Downloads**: Concurrent downloads of the same package are safely handled
  with a mutex lock to prevent race conditions. The first process downloads, subsequent
  processes wait and then use the cached package.
  """

  alias Typster.Native

  @type metadata :: %{
          optional(:title) => String.t(),
          optional(:author) => String.t(),
          optional(:description) => String.t(),
          optional(:keywords) => String.t(),
          optional(:date) => String.t()
        }
  @type package_paths :: [String.t()]
  @type root_path :: String.t()
  @type variables :: map()
  @type render_options :: [
          metadata: metadata(),
          package_paths: package_paths(),
          pixel_per_pt: float(),
          root_path: root_path(),
          variables: variables()
        ]

  @type pdf_binary :: binary()
  @type svg_pages :: [String.t()]
  @type png_pages :: [binary()]

  ## Core API

  @doc """
  Render a Typst template to PDF format.

  ## Parameters
  - `source` - The Typst template source code
  - `opts` - Keyword list of options

  ## Options
  - `:metadata` - Map of PDF metadata (default: %{})
  - `:package_paths` - List of local package directories (default: [])
  - `:root_path` - Root path for resolving relative imports (default: ".")
  - `:variables` - Map of variables to bind (default: %{})

  ## Examples

      # Simple rendering
      {:ok, pdf} = Typster.render_pdf("= Hello World")

      # With variables
      template = "= Report for #year"
      {:ok, pdf} = Typster.render_pdf(template, variables: %{year: 2025})

      # With metadata
      {:ok, pdf} = Typster.render_pdf(
        template,
        variables: %{year: 2025},
        metadata: %{title: "Annual Report", author: "Corp"}
      )

      # With packages
      template = ~S(#import "@preview/tiaoma:0.3.0": qrcode
      #qrcode("https://example.com"))
      {:ok, pdf} = Typster.render_pdf(template, package_paths: [])
  """
  @spec render_pdf(String.t(), render_options()) ::
          {:ok, pdf_binary()} | {:error, String.t()}
  def render_pdf(source, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{}) |> stringify_keys()
    package_paths = Keyword.get(opts, :package_paths, [])
    root_path = Keyword.get(opts, :root_path, ".")
    variables = Keyword.get(opts, :variables, %{}) |> stringify_keys()

    options = %Native.TypsterOptions{
      metadata: metadata,
      package_paths: package_paths,
      root_path: root_path,
      variables: variables
    }

    case Native.compile_to_pdf(source, options) do
      {:ok, pdf} -> {:ok, pdf}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Render a Typst template to SVG format.

  Returns a list of SVG strings, one for each page in the document.

  ## Parameters
  - `source` - The Typst template source code
  - `opts` - Keyword list of options

  ## Options
  - `:package_paths` - List of local package directories (default: [])
  - `:root_path` - Root path for resolving relative imports (default: ".")
  - `:variables` - Map of variables to bind (default: %{})

  ## Examples

      {:ok, svg_pages} = Typster.render_svg("= Hello World")
      # svg_pages is a list like ["<svg>...</svg>"]

      # Multi-page document
      template = "= Page 1\\n#pagebreak()\\n= Page 2"
      {:ok, [svg1, svg2]} = Typster.render_svg(template)
  """
  @spec render_svg(String.t(), render_options()) ::
          {:ok, svg_pages()} | {:error, String.t()}
  def render_svg(source, opts \\ []) do
    package_paths = Keyword.get(opts, :package_paths, [])
    root_path = Keyword.get(opts, :root_path, ".")
    variables = Keyword.get(opts, :variables, %{}) |> stringify_keys()

    options = %Typster.Native.TypsterOptions{
      metadata: %{},
      package_paths: package_paths,
      root_path: root_path,
      variables: variables
    }

    case Native.compile_to_svg(source, options) do
      {:ok, svg_pages} -> {:ok, svg_pages}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Render a Typst template to PNG format.

  Returns a list of PNG binaries, one for each page in the document.

  ## Parameters
  - `source` - The Typst template source code
  - `opts` - Keyword list of options

  ## Options
  - `:package_paths` - List of local package directories (default: [])
  - `:pixel_per_pt` - Resolution in pixels per point (default: 2.0, higher = better quality)
  - `:root_path` - Root path for resolving relative imports (default: ".")
  - `:variables` - Map of variables to bind (default: %{})

  ## Examples

      {:ok, png_pages} = Typster.render_png("= Hello World")

      # High resolution
      {:ok, png_pages} = Typster.render_png(template, %{}, pixel_per_pt: 4.0)

      # Multi-page document
      template = "= Page 1\\n#pagebreak()\\n= Page 2"
      {:ok, [png1, png2]} = Typster.render_png(template)
  """
  @spec render_png(String.t(), render_options()) ::
          {:ok, png_pages()} | {:error, String.t()}
  def render_png(source, opts \\ []) do
    package_paths = Keyword.get(opts, :package_paths, [])
    pixel_per_pt = Keyword.get(opts, :pixel_per_pt, 2.0)
    root_path = Keyword.get(opts, :root_path, ".")
    variables = Keyword.get(opts, :variables, %{}) |> stringify_keys()

    options = %Typster.Native.TypsterOptions{
      metadata: %{},
      package_paths: package_paths,
      pixel_per_pt: pixel_per_pt,
      root_path: root_path,
      variables: variables
    }

    case Native.compile_to_png(source, options) do
      {:ok, png_pages} -> {:ok, png_pages}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Render a Typst template and save to a file.

  The output format is determined by the file extension:
  - `.pdf` - PDF format
  - `.svg` - SVG format (first page only for multi-page documents)
  - `.png` - PNG format (first page only for multi-page documents)

  ## Parameters
  - `source` - The Typst template source code
  - `output_path` - Path to save the output file
  - `opts` - Keyword list of options (same as format-specific functions)

  ## Examples

      Typster.render_to_file(template, "output.pdf")
      Typster.render_to_file(template, "output.svg", %{title: "Report"})
      Typster.render_to_file(template, "output.png", %{}, pixel_per_pt: 4.0)
  """
  @spec render_to_file(String.t(), String.t(), render_options()) ::
          :ok | {:error, String.t()}
  def render_to_file(source, output_path, opts \\ []) do
    extension = Path.extname(output_path) |> String.downcase()

    case extension do
      ".pdf" ->
        with {:ok, pdf} <- render_pdf(source, opts) do
          File.write(output_path, pdf)
        end

      ".svg" ->
        with {:ok, [svg | _]} <- render_svg(source, opts) do
          File.write(output_path, svg)
        end

      ".png" ->
        with {:ok, [png | _]} <- render_png(source, opts) do
          File.write(output_path, png)
        end

      _ ->
        {:error, "Unsupported file extension: #{extension}. Use .pdf, .svg, or .png"}
    end
  end

  @doc """
  Check the syntax of a Typst template without rendering.

  This function validates the template syntax by attempting to compile it,
  but doesn't produce any output. It's useful for validating templates before
  rendering or providing syntax feedback to users.

  ## Parameters
  - `source` - The Typst template source code
  - `opts` - Keyword list of options

  ## Options
  - `:package_paths` - List of local package directories (default: [])
  - `:root_path` - Root path for resolving relative imports (default: ".")
  - `:variables` - Map of variables to bind (default: %{})

  ## Returns
  - `:ok` if the template syntax is valid
  - `{:error, errors}` where errors is a list of error messages

  ## Examples

      # Valid template
      :ok = Typster.check("= Hello World")

      # Invalid template
      {:error, errors} = Typster.check("= Unclosed #for")
      # errors will contain a list of error messages

      # With variables
      template = "= Report for #year"
      :ok = Typster.check(template, %{year: 2025})

      # With packages
      template = ~S(#import "@preview/tiaoma:0.3.0": qrcode)
      :ok = Typster.check(template, %{}, package_paths: [])
  """
  @spec check(String.t(), render_options()) :: :ok | {:error, [String.t()]}
  def check(source, opts \\ []) do
    package_paths = Keyword.get(opts, :package_paths, [])
    root_path = Keyword.get(opts, :root_path, ".")
    variables = Keyword.get(opts, :variables, %{}) |> stringify_keys()

    options = %Typster.Native.TypsterOptions{
      metadata: %{},
      package_paths: package_paths,
      root_path: root_path,
      variables: variables
    }

    case Native.check_syntax(source, options) do
      {:ok, []} -> :ok
      {:ok, errors} -> {:error, errors}
      {:error, reason} -> {:error, [reason]}
    end
  end

  @doc """
  Check the syntax of a Typst template, raising on error.

  Same as `check/3` but raises `Typster.CompileError` if there are syntax errors.

  ## Examples

      # Valid template
      :ok = Typster.check!("= Hello World")

      # Invalid template - raises
      try do
        Typster.check!("= Invalid #syntax")
      rescue
        e in Typster.CompileError ->
          IO.puts("Syntax error: \#{e.message}")
      end
  """
  @spec check!(String.t(), render_options()) :: :ok
  def check!(source, opts \\ []) do
    case check(source, opts) do
      :ok -> :ok
      {:error, errors} -> raise Typster.CompileError, message: Enum.join(errors, "\n")
    end
  end

  @doc """
  Render a Typst template to PDF format, raising on error.

  Same as `render_pdf/3` but raises `Typster.CompileError` on failure.

  ## Examples

      pdf = Typster.render_pdf!(template)
      pdf = Typster.render_pdf!(template, %{year: 2025})
  """
  @spec render_pdf!(String.t(), render_options()) :: pdf_binary()
  def render_pdf!(source, opts \\ []) do
    case render_pdf(source, opts) do
      {:ok, pdf} -> pdf
      {:error, reason} -> raise Typster.CompileError, message: reason
    end
  end

  @doc """
  Render a Typst template to SVG format, raising on error.

  Same as `render_svg/3` but raises `Typster.CompileError` on failure.
  """
  @spec render_svg!(String.t(), render_options()) :: svg_pages()
  def render_svg!(source, opts \\ []) do
    case render_svg(source, opts) do
      {:ok, svg_pages} -> svg_pages
      {:error, reason} -> raise Typster.CompileError, message: reason
    end
  end

  @doc """
  Render a Typst template to PNG format, raising on error.

  Same as `render_png/3` but raises `Typster.CompileError` on failure.
  """
  @spec render_png!(String.t(), render_options()) :: png_pages()
  def render_png!(source, opts \\ []) do
    case render_png(source, opts) do
      {:ok, png_pages} -> png_pages
      {:error, reason} -> raise Typster.CompileError, message: reason
    end
  end

  @doc """
  Render a Typst template to a file, raising on error.

  Same as `render_to_file/4` but raises on failure.
  """
  @spec render_to_file!(String.t(), String.t(), render_options()) :: :ok
  def render_to_file!(source, output_path, opts \\ []) do
    case render_to_file(source, output_path, opts) do
      :ok -> :ok
      {:error, reason} -> raise Typster.CompileError, message: reason
    end
  end

  ## Private Helpers

  # Convert map with atom keys to string keys for NIF compatibility
  # Recursively handle nested maps and lists
  # NOTE: Only keys are converted to strings, values are preserved as-is
  # (numbers, booleans, etc.) except for atoms which are converted to strings
  # Structs like Date, DateTime, NaiveDateTime are converted to maps with string keys
  defp stringify_keys(map) when is_struct(map) do
    # Convert struct to map with string keys for NIF compatibility
    map
    |> Map.from_struct()
    |> Map.new(fn {key, value} ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: to_string(key)
      string_value = stringify_value(value)
      {string_key, string_value}
    end)
    |> Map.put("__struct__", to_string(map.__struct__))
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: to_string(key)
      string_value = stringify_value(value)
      {string_key, string_value}
    end)
  end

  # Convert structs
  defp stringify_value(value) when is_struct(value), do: stringify_keys(value)
  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)

  defp stringify_value(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  # Keep numbers, booleans, strings as-is
  defp stringify_value(value), do: value
end
