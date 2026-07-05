[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["mix.exs", "config/*.exs"],
  subdirectories: ["apps/*"],
  tag_formatters: %{script: Prettier}
]
