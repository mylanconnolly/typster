defmodule Typster.ConcurrentTest do
  @moduledoc """
  Tests for concurrent rendering to ensure thread safety and proper resource handling.
  """

  use ExUnit.Case

  @simple_template """
  #set page(width: 200pt, height: 100pt)
  = Concurrent Test
  This is document #doc_id
  """

  @complex_template """
  #set page(width: 8.5in, height: 11in)
  = Report #report_id

  #for i in range(50) [
    == Section #(i + 1)
    Content for section #(i + 1) in report #report_id.
  ]
  """

  describe "concurrent PDF rendering" do
    test "renders multiple PDFs concurrently from different processes" do
      # Spawn 10 tasks that each render a PDF
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            variables = %{doc_id: i}
            Typster.render_pdf(@simple_template, variables)
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, pdf} -> is_binary(pdf) and byte_size(pdf) > 0
               _ -> false
             end)

      # All PDFs should be valid
      Enum.each(results, fn {:ok, pdf} ->
        assert String.starts_with?(pdf, "%PDF")
      end)
    end

    test "handles 50 concurrent renders without issues" do
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            variables = %{doc_id: i}
            Typster.render_pdf(@simple_template, variables)
          end)
        end

      results = Task.await_many(tasks, 60_000)

      # Count successes
      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert successes == 50

      IO.puts("  Successfully rendered 50 PDFs concurrently")
    end

    test "concurrent complex document rendering" do
      # Render more complex documents concurrently
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            variables = %{report_id: i}
            Typster.render_pdf(@complex_template, variables)
          end)
        end

      results = Task.await_many(tasks, 60_000)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, pdf} -> byte_size(pdf) > 5000
               _ -> false
             end)
    end
  end

  describe "concurrent SVG rendering" do
    test "renders SVGs concurrently" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            variables = %{doc_id: i}
            Typster.render_svg(@simple_template, variables)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      assert Enum.all?(results, fn
               {:ok, svg_pages} when is_list(svg_pages) -> not Enum.empty?(svg_pages)
               _ -> false
             end)
    end
  end

  describe "concurrent PNG rendering" do
    test "renders PNGs concurrently with different resolutions" do
      resolutions = [1.0, 2.0, 3.0, 4.0]

      tasks =
        for resolution <- resolutions do
          Task.async(fn ->
            {resolution,
             Typster.render_png(@simple_template, %{doc_id: 1}, pixel_per_pt: resolution)}
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert Enum.all?(results, fn
               {_res, {:ok, png_pages}} -> not Enum.empty?(png_pages)
               _ -> false
             end)

      # Higher resolution should produce larger files
      sizes =
        results
        |> Enum.map(fn {res, {:ok, [png | _]}} -> {res, byte_size(png)} end)
        |> Enum.sort_by(fn {res, _} -> res end)

      # Verify size increases with resolution
      [s1, s2, s3, s4] = Enum.map(sizes, fn {_, size} -> size end)
      assert s1 < s2
      assert s2 < s3
      assert s3 < s4
    end
  end

  describe "concurrent package downloads" do
    @tag :packages
    @tag timeout: 120_000
    test "handles concurrent package downloads safely" do
      # Multiple processes trying to use the same package
      template = """
      #import "@preview/tiaoma:0.3.0": qrcode
      = QR Code #doc_id
      #qrcode("https://example.com/doc/#doc_id")
      """

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            variables = %{doc_id: i}
            Typster.render_pdf(template, variables)
          end)
        end

      results = Task.await_many(tasks, 120_000)

      # All should succeed - the download lock should prevent race conditions
      assert Enum.all?(results, fn
               {:ok, pdf} -> byte_size(pdf) > 1000
               _ -> false
             end)

      IO.puts("  Concurrent package downloads handled correctly")
    end
  end

  describe "mixed concurrent operations" do
    test "handles mix of PDF, SVG, and PNG rendering concurrently" do
      pdf_tasks =
        for i <- 1..5 do
          Task.async(fn ->
            {:pdf, Typster.render_pdf(@simple_template, %{doc_id: i})}
          end)
        end

      svg_tasks =
        for i <- 1..5 do
          Task.async(fn ->
            {:svg, Typster.render_svg(@simple_template, %{doc_id: i})}
          end)
        end

      png_tasks =
        for i <- 1..5 do
          Task.async(fn ->
            {:png, Typster.render_png(@simple_template, %{doc_id: i})}
          end)
        end

      all_tasks = pdf_tasks ++ svg_tasks ++ png_tasks
      results = Task.await_many(all_tasks, 60_000)

      # All should succeed
      assert length(results) == 15

      successes =
        Enum.count(results, fn
          {:pdf, {:ok, _}} -> true
          {:svg, {:ok, _}} -> true
          {:png, {:ok, _}} -> true
          _ -> false
        end)

      assert successes == 15
      IO.puts("  Mixed concurrent operations (PDF/SVG/PNG) successful")
    end
  end

  describe "error handling under concurrent load" do
    test "handles concurrent errors gracefully" do
      # Half valid, half invalid templates
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            template = if rem(i, 2) == 0, do: @simple_template, else: "#invalid {"
            Typster.render_pdf(template, %{doc_id: i})
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # Should have 5 successes and 5 errors
      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      errors =
        Enum.count(results, fn
          {:error, _} -> true
          _ -> false
        end)

      assert successes == 5
      assert errors == 5

      # All errors should have messages
      Enum.each(results, fn
        {:error, reason} -> assert is_binary(reason)
        {:ok, _} -> :ok
      end)
    end
  end

  describe "stress test" do
    @tag :stress
    @tag timeout: 180_000
    test "handles 100 concurrent renders" do
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            # Vary the templates to simulate realistic usage
            template =
              case rem(i, 3) do
                0 -> @simple_template
                1 -> @complex_template
                2 -> "= Quick doc #doc_id"
              end

            variables = %{doc_id: i, report_id: i}
            Typster.render_pdf(template, variables)
          end)
        end

      start_time = System.monotonic_time(:millisecond)
      results = Task.await_many(tasks, 180_000)
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time

      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert successes == 100

      IO.puts("  100 concurrent renders completed in #{duration}ms")
      IO.puts("     Average: #{div(duration, 100)}ms per document")
    end
  end
end
