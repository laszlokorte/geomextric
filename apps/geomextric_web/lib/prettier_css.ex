if Mix.env() == :dev do
  defmodule PrettierCSS do
    @moduledoc false

    @behaviour Phoenix.LiveView.HTMLFormatter.TagFormatter

    require Logger

    @impl true
    def render_tag({"style", attrs, content}, _opts)
        when not is_map_key(attrs, "runtime") do
      tmp_file =
        Path.join(
          System.tmp_dir!(),
          "prettier_#{System.unique_integer([:positive])}.css"
        )

      try do
        File.write!(tmp_file, content)

        case System.cmd("npx", ["prettier", "--parser", "css", tmp_file], stderr_to_stdout: false) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {error, _} ->
            Logger.error("Failed to format CSS with prettier: #{error}")
            :skip
        end
      after
        File.rm(tmp_file)
      end
    end

    def render_tag({_other, _attrs, _content}, _opts) do
      :skip
    end
  end
end
