defmodule Typster.MemoryTest do
  @moduledoc """
  Guards against Typst's global memoization cache growing without bound.
  """

  use ExUnit.Case, async: false

  @template """
  #set page(paper: "us-letter", margin: 1in)
  = Letter #id

  #for p in paragraphs [
    #p

  ]
  """

  defp rss_mb do
    kb =
      case File.read("/proc/self/status") do
        {:ok, status} ->
          [_, kb] = Regex.run(~r/VmRSS:\s+(\d+) kB/, status)
          String.to_integer(kb)

        {:error, _} ->
          {out, 0} = System.cmd("ps", ["-o", "rss=", "-p", System.pid()])
          out |> String.trim() |> String.to_integer()
      end

    div(kb, 1024)
  end

  defp render_batch(range, opts) do
    range
    |> Task.async_stream(
      fn i ->
        paragraphs = for j <- 1..6, do: String.duplicate("letter #{i} paragraph #{j} ", 40)
        variables = %{id: i, paragraphs: paragraphs}
        assert {:ok, _pdf} = Typster.render_pdf(@template, [variables: variables] ++ opts)
      end,
      max_concurrency: 10,
      timeout: :infinity
    )
    |> Stream.run()
  end

  for max_age <- [0, 10] do
    @tag timeout: 120_000
    test "memory stays flat across many distinct renders (cache_max_age: #{max_age})" do
      opts = [cache_max_age: unquote(max_age)]

      # Warm up so one-time allocations (fonts, allocator arenas) are excluded
      render_batch(1..200, opts)
      before = rss_mb()

      render_batch(201..1200, opts)
      growth = rss_mb() - before

      # Without eviction these 1000 renders retain several hundred MB
      assert growth < 60, "RSS grew by #{growth} MB over 1000 renders"
    end
  end
end
