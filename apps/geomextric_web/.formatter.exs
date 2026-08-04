[
  import_deps: [:phoenix, :hologram],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs,holo}"],
  tag_formatters: %{script: PrettierJS, style: PrettierCSS}
]
