defmodule TypsterTest do
  use ExUnit.Case

  doctest Typster

  @simple_template """
  #set page(width: 200pt, height: 100pt)
  = Hello World
  This is a test document.
  """

  @template_with_vars """
  #set page(width: 300pt, height: 150pt)
  = Report for #year
  *Author:* #author_name
  *Status:* #status
  """

  describe "render_pdf/3" do
    test "renders simple template to PDF" do
      assert {:ok, pdf} = Typster.render_pdf(@simple_template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 0
      # PDF files start with %PDF
      assert String.starts_with?(pdf, "%PDF")
    end

    test "renders template with variables" do
      variables = %{
        year: 2025,
        author_name: "John Doe",
        status: "Published"
      }

      assert {:ok, pdf} = Typster.render_pdf(@template_with_vars, variables: variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 0
    end

    test "renders with metadata" do
      metadata = %{
        title: "Test Document",
        author: "Test Suite",
        keywords: "test, elixir"
      }

      assert {:ok, pdf} = Typster.render_pdf(@simple_template, metadata: metadata)
      assert is_binary(pdf)
      # Metadata doesn't change output structure significantly but should not error
    end

    test "renders with package paths" do
      assert {:ok, pdf} = Typster.render_pdf(@simple_template, package_paths: [])
      assert is_binary(pdf)
    end

    test "returns error for invalid template" do
      invalid_template = "#invalid syntax {"
      assert {:error, reason} = Typster.render_pdf(invalid_template)
      assert is_binary(reason)
      assert reason =~ "Compilation failed"
    end

    test "accepts atom keys in variables" do
      variables = %{year: 2025}
      assert {:ok, pdf} = Typster.render_pdf("= Year #year", variables: variables)
      assert is_binary(pdf)
    end

    test "accepts string keys in variables" do
      variables = %{"year" => 2025}
      assert {:ok, pdf} = Typster.render_pdf("= Year #year", variables: variables)
      assert is_binary(pdf)
    end
  end

  describe "render_svg/3" do
    test "renders simple template to SVG" do
      assert {:ok, svg_pages} = Typster.render_svg(@simple_template)
      assert is_list(svg_pages)
      assert length(svg_pages) == 1

      svg = List.first(svg_pages)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
    end

    test "renders multi-page document" do
      multipage = """
      #set page(width: 200pt, height: 100pt)
      = Page 1
      #pagebreak()
      = Page 2
      #pagebreak()
      = Page 3
      """

      assert {:ok, svg_pages} = Typster.render_svg(multipage)
      assert length(svg_pages) == 3

      Enum.each(svg_pages, fn svg ->
        assert is_binary(svg)
        assert String.contains?(svg, "<svg")
      end)
    end

    test "renders with variables" do
      variables = %{title: "SVG Test"}
      assert {:ok, svg_pages} = Typster.render_svg("= #title", variables: variables)
      assert length(svg_pages) == 1
    end

    test "returns error for invalid template" do
      assert {:error, _reason} = Typster.render_svg("#invalid {")
    end
  end

  describe "render_png/3" do
    test "renders simple template to PNG" do
      assert {:ok, png_pages} = Typster.render_png(@simple_template)
      assert is_list(png_pages)
      assert length(png_pages) == 1

      png = List.first(png_pages)
      assert is_binary(png)
      assert byte_size(png) > 0
      # PNG files start with specific magic bytes
      assert binary_part(png, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
    end

    test "renders with different resolutions" do
      {:ok, png_2x} = Typster.render_png(@simple_template, pixel_per_pt: 2.0)
      {:ok, png_4x} = Typster.render_png(@simple_template, pixel_per_pt: 4.0)

      # Higher resolution should produce larger files
      assert byte_size(List.first(png_4x)) > byte_size(List.first(png_2x))
    end

    test "renders multi-page document" do
      multipage = """
      = Page 1
      #pagebreak()
      = Page 2
      """

      assert {:ok, png_pages} = Typster.render_png(multipage)
      assert length(png_pages) == 2
    end

    test "renders with variables" do
      variables = %{content: "PNG Content"}
      assert {:ok, png_pages} = Typster.render_png("= #content", variables: variables)
      assert length(png_pages) == 1
    end
  end

  describe "render_to_file/4" do
    setup do
      on_exit(fn ->
        # Cleanup test files
        ["test_output.pdf", "test_output.svg", "test_output.png"]
        |> Enum.each(fn file ->
          if File.exists?(file), do: File.rm!(file)
        end)
      end)
    end

    test "saves PDF to file" do
      assert :ok = Typster.render_to_file(@simple_template, "test_output.pdf")
      assert File.exists?("test_output.pdf")

      content = File.read!("test_output.pdf")
      assert String.starts_with?(content, "%PDF")
    end

    test "saves SVG to file" do
      assert :ok = Typster.render_to_file(@simple_template, "test_output.svg")
      assert File.exists?("test_output.svg")

      content = File.read!("test_output.svg")
      assert String.contains?(content, "<svg")
    end

    test "saves PNG to file" do
      assert :ok = Typster.render_to_file(@simple_template, "test_output.png")
      assert File.exists?("test_output.png")

      content = File.read!("test_output.png")
      # PNG magic bytes
      assert binary_part(content, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
    end

    test "passes variables to render functions" do
      template = "= Title: #title"

      assert :ok =
               Typster.render_to_file(template, "test_output.pdf", variables: %{title: "Test"})

      assert File.exists?("test_output.pdf")
    end

    test "returns error for unsupported extension" do
      assert {:error, reason} = Typster.render_to_file(@simple_template, "test.txt")
      assert reason =~ "Unsupported file extension"
    end
  end

  describe "bang functions" do
    test "render_pdf! returns binary on success" do
      pdf = Typster.render_pdf!(@simple_template)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "render_pdf! raises on error" do
      assert_raise Typster.CompileError, fn ->
        Typster.render_pdf!("#invalid {")
      end
    end

    test "render_svg! returns list on success" do
      svg_pages = Typster.render_svg!(@simple_template)
      assert is_list(svg_pages)
      assert length(svg_pages) == 1
    end

    test "render_svg! raises on error" do
      assert_raise Typster.CompileError, fn ->
        Typster.render_svg!("#invalid {")
      end
    end

    test "render_png! returns list on success" do
      png_pages = Typster.render_png!(@simple_template)
      assert is_list(png_pages)
      assert length(png_pages) == 1
    end

    test "render_png! raises on error" do
      assert_raise Typster.CompileError, fn ->
        Typster.render_png!("#invalid {")
      end
    end

    test "render_to_file! returns :ok on success" do
      on_exit(fn -> if File.exists?("test_output.pdf"), do: File.rm!("test_output.pdf") end)

      assert :ok = Typster.render_to_file!(@simple_template, "test_output.pdf")
      assert File.exists?("test_output.pdf")
    end

    test "render_to_file! raises on error" do
      assert_raise Typster.CompileError, fn ->
        Typster.render_to_file!("#invalid {", "test_output.pdf")
      end
    end
  end

  describe "nested variables" do
    test "handles nil values" do
      template = """
      = User Profile
      #if description == none [
        No description provided
      ] else [
        #description
      ]
      """

      variables = %{
        description: nil
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end

    test "handles nil values in nested structures" do
      template = """
      = #user.name
      #if user.middle_name == none [
        (no middle name)
      ] else [
        Middle: #user.middle_name
      ]
      """

      variables = %{
        user: %{
          name: "Alice",
          middle_name: nil
        }
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end

    test "handles nested maps" do
      template = """
      = #user.name
      Email: #user.email
      City: #user.address.city
      """

      variables = %{
        user: %{
          name: "Alice",
          email: "alice@example.com",
          address: %{
            city: "Portland",
            state: "OR"
          }
        }
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end

    test "handles arrays" do
      template = """
      = Items
      #for item in items [
        - #item
      ]
      """

      variables = %{
        items: ["Apple", "Banana", "Cherry"]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end
  end

  describe "check/3" do
    test "returns :ok for valid template" do
      assert :ok = Typster.check(@simple_template)
    end

    test "returns :ok for template with variables" do
      variables = %{
        year: 2025,
        author_name: "John Doe",
        status: "Published"
      }

      assert :ok = Typster.check(@template_with_vars, variables: variables)
    end

    test "returns error for invalid template" do
      invalid_template = "#invalid syntax {"
      assert {:error, errors} = Typster.check(invalid_template)
      assert is_list(errors)
      refute Enum.empty?(errors)
      assert Enum.all?(errors, &is_binary/1)
    end

    test "returns error for unclosed brackets" do
      invalid_template = "= Title\n#for item in items ["
      assert {:error, errors} = Typster.check(invalid_template)
      assert is_list(errors)
      refute Enum.empty?(errors)
    end

    test "returns error for undefined variable reference" do
      template = "= Value: #undefined_var"
      assert {:error, errors} = Typster.check(template)
      assert is_list(errors)
      refute Enum.empty?(errors)
    end

    test "accepts package_paths option" do
      assert :ok = Typster.check(@simple_template, package_paths: [])
    end

    test "validates template with nested variables" do
      template = """
      = #user.name
      Email: #user.email
      """

      variables = %{
        user: %{
          name: "Alice",
          email: "alice@example.com"
        }
      }

      assert :ok = Typster.check(template, variables: variables)
    end

    test "validates template with arrays" do
      template = """
      #for item in items [
        - #item
      ]
      """

      variables = %{
        items: ["Apple", "Banana"]
      }

      assert :ok = Typster.check(template, variables: variables)
    end
  end

  describe "check!/3" do
    test "returns :ok for valid template" do
      assert :ok = Typster.check!(@simple_template)
    end

    test "raises CompileError for invalid template" do
      assert_raise Typster.CompileError, fn ->
        Typster.check!("#invalid syntax {")
      end
    end

    test "raises CompileError with error message" do
      error =
        assert_raise Typster.CompileError, fn ->
          Typster.check!("#for unclosed")
        end

      assert is_binary(error.message)
      assert String.length(error.message) > 0
    end

    test "works with variables" do
      variables = %{title: "Test"}
      assert :ok = Typster.check!("= #title", variables: variables)
    end
  end

  describe "error messages for unsupported types" do
    test "reports variable name for unsupported type at top level" do
      assert {:error, reason} =
               Typster.render_pdf("= Test", variables: %{my_var: {:tuple, "value"}})

      assert reason =~ "my_var"
      assert reason =~ "tuple"
      assert reason =~ "Supported types"
    end

    test "reports variable name and path for unsupported type in nested map" do
      assert {:error, reason} =
               Typster.render_pdf("= Test",
                 variables: %{
                   user: %{
                     name: "Alice",
                     data: self()
                   }
                 }
               )

      assert reason =~ "user"
      assert reason =~ "data"
      assert reason =~ "pid"
    end

    test "reports array index for unsupported type in array" do
      assert {:error, reason} =
               Typster.render_pdf("= Test",
                 variables: %{
                   items: ["valid", "also valid", fn -> :oops end]
                 }
               )

      assert reason =~ "items"
      assert reason =~ "index 2"
      assert reason =~ "function"
    end

    test "reports deeply nested path for unsupported type" do
      assert {:error, reason} =
               Typster.render_pdf("= Test",
                 variables: %{
                   level1: %{
                     level2: %{
                       level3: make_ref()
                     }
                   }
                 }
               )

      assert reason =~ "level1"
      assert reason =~ "level2"
      assert reason =~ "level3"
      assert reason =~ "reference"
    end

    test "shows supported types in error message" do
      assert {:error, reason} =
               Typster.render_pdf("= Test", variables: %{bad: {1, 2, 3}})

      assert reason =~ "nil"
      assert reason =~ "boolean"
      assert reason =~ "integer"
      assert reason =~ "float"
      assert reason =~ "string"
      assert reason =~ "list"
      assert reason =~ "map"
    end
  end
end
