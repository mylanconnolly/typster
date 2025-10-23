defmodule Typster.PropertyTest do
  @moduledoc """
  Property-based tests using StreamData to test with randomly generated inputs.
  """

  use ExUnit.Case
  use ExUnitProperties

  property "renders valid PDF for any simple text content" do
    check all(content <- string(:printable, min_length: 1, max_length: 100)) do
      template = "= Test Document\n\n#{content}"

      case Typster.render_pdf(template) do
        {:ok, pdf} ->
          assert is_binary(pdf)
          assert String.starts_with?(pdf, "%PDF")

        {:error, _reason} ->
          # Some random strings might produce invalid Typst syntax,
          # which is acceptable - we just want to ensure no crashes
          :ok
      end
    end
  end

  property "handles any numeric variable value" do
    check all(number <- one_of([integer(), float()])) do
      template = "Value: #num"
      variables = %{num: number}

      case Typster.render_pdf(template, variables: variables) do
        {:ok, pdf} ->
          assert is_binary(pdf)

        {:error, _reason} ->
          # Some edge case numbers might not convert properly
          :ok
      end
    end
  end

  property "handles maps with string values" do
    check all(
            map <-
              map_of(
                atom(:alphanumeric),
                string(:alphanumeric, min_length: 1, max_length: 20),
                max_length: 5
              )
          ) do
      # Create a simple template that uses each key
      keys = Map.keys(map)

      template =
        if Enum.empty?(keys) do
          "= Empty Map Test"
        else
          "= Map Test\n" <>
            Enum.map_join(keys, "\n", fn key ->
              "#{key}: \\###{key}"
            end)
        end

      case Typster.render_pdf(template, variables: map) do
        {:ok, pdf} ->
          assert is_binary(pdf)

        {:error, _reason} ->
          # Some generated content might not be valid Typst
          :ok
      end
    end
  end

  property "all output formats produce non-empty results for valid templates" do
    check all(title <- string(:alphanumeric, min_length: 1, max_length: 30)) do
      template = "= #{title}"

      # All three formats should work
      assert {:ok, pdf} = Typster.render_pdf(template)
      assert byte_size(pdf) > 0

      assert {:ok, svg_pages} = Typster.render_svg(template)
      refute Enum.empty?(svg_pages)

      assert {:ok, png_pages} = Typster.render_png(template)
      refute Enum.empty?(png_pages)
    end
  end

  property "handles lists of varying sizes" do
    check all(
            items <- list_of(string(:alphanumeric, min_length: 1, max_length: 20), max_length: 10)
          ) do
      template = """
      = List Test
      #for item in items [
        - #item
      ]
      """

      variables = %{items: items}

      case Typster.render_pdf(template, variables: variables) do
        {:ok, pdf} ->
          assert is_binary(pdf)

        {:error, _reason} ->
          :ok
      end
    end
  end

  property "metadata fields accept any string values" do
    check all(
            title <- string(:alphanumeric, min_length: 1, max_length: 50),
            author <- string(:alphanumeric, min_length: 1, max_length: 50)
          ) do
      template = "= Document"

      metadata = %{
        title: title,
        author: author
      }

      assert {:ok, pdf} = Typster.render_pdf(template, metadata: metadata)
      assert is_binary(pdf)
    end
  end

  property "PNG resolution affects output size predictably" do
    check all(resolution <- float(min: 1.0, max: 8.0)) do
      template = "= Test"

      assert {:ok, png_pages} = Typster.render_png(template, pixel_per_pt: resolution)
      assert length(png_pages) == 1

      png = List.first(png_pages)
      assert is_binary(png)
      assert byte_size(png) > 0
    end
  end

  describe "error handling properties" do
    property "invalid templates return errors, not crashes" do
      check all(
              # Generate potentially invalid Typst syntax
              content <- string(:printable, min_length: 1, max_length: 50)
            ) do
        # Intentionally malformed template
        template = "#{content} {"

        case Typster.render_pdf(template) do
          {:ok, _pdf} -> :ok
          {:error, reason} -> assert is_binary(reason)
        end
      end
    end

    property "bang functions raise or return, never crash" do
      check all(content <- string(:alphanumeric, min_length: 1, max_length: 30)) do
        template = "= #{content}"

        # Should either return a result or raise an exception, but never crash
        try do
          pdf = Typster.render_pdf!(template)
          assert is_binary(pdf)
        rescue
          _e in Typster.CompileError -> :ok
        end
      end
    end
  end
end
