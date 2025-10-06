defmodule Typster.CompileError do
  @moduledoc """
  Exception raised when Typst compilation fails.

  This exception is raised by the bang (!) versions of rendering functions
  when compilation or rendering fails.

  ## Examples

      try do
        Typster.render_pdf!("invalid typst syntax")
      rescue
        e in Typster.CompileError ->
          IO.puts("Compilation failed: " <> e.message)
      end
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "Typst compilation failed")
    %__MODULE__{message: message}
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end
