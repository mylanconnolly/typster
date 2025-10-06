defmodule Typster.PackageTest do
  @moduledoc """
  Tests for Typst package downloads from the registry.
  """
  # Package downloads shouldn't run in parallel due to mutex
  use ExUnit.Case, async: false

  describe "package downloads" do
    test "imports and uses qrcode package" do
      template = """
      #import "@preview/tiaoma:0.3.0": qrcode

      = QR Code Test

      #qrcode("https://typst.app", width: 2cm)
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
      assert String.starts_with?(pdf, "%PDF")
    end

    test "imports and uses cetz drawing package" do
      template = """
      #import "@preview/cetz:0.3.2": canvas, draw

      = CeTZ Test

      #canvas({
        import draw: *
        rect((0, 0), (2, 2), fill: blue.lighten(80%))
      })
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
      assert String.starts_with?(pdf, "%PDF")
    end

    test "handles package with EAN barcode" do
      template = """
      #import "@preview/tiaoma:0.3.0": ean

      = Barcode Test

      #ean("012345678905", width: 5cm)
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end

    test "returns error for non-existent package" do
      template = """
      #import "@preview/nonexistent-package-12345:1.0.0": foo

      = Test
      """

      assert {:error, reason} = Typster.render_pdf(template)
      assert is_binary(reason)
      # Should contain some indication of failure
      assert reason =~ ~r/(failed|not found|error)/i
    end

    test "returns error for non-existent package version" do
      template = """
      #import "@preview/tiaoma:99.99.99": qrcode

      = Test
      """

      assert {:error, reason} = Typster.render_pdf(template)
      assert is_binary(reason)
    end

    test "handles multiple package imports in one document" do
      template = """
      #import "@preview/tiaoma:0.3.0": qrcode
      #import "@preview/cetz:0.3.2": canvas, draw

      = Multi-Package Test

      #qrcode("test", width: 2cm)

      #canvas({
        import draw: *
        circle((1, 1), radius: 0.5)
      })
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end
  end

  describe "package caching" do
    test "uses cached package on second render" do
      template = """
      #import "@preview/tiaoma:0.3.0": qrcode

      = Cached Package Test

      #qrcode("cache-test", width: 2cm)
      """

      # First render (may download or use existing cache)
      assert {:ok, _pdf1} = Typster.render_pdf(template)

      # Second render (should use cache)
      {time, {:ok, pdf2}} =
        :timer.tc(fn ->
          Typster.render_pdf(template)
        end)

      assert is_binary(pdf2)
      # Second render should be fast (< 500ms) since it uses cache
      # 500ms in microseconds
      assert time < 500_000
    end
  end
end
