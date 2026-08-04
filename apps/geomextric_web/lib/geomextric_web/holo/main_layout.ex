defmodule Blog.MainLayout do
  use Hologram.Component

  alias Hologram.UI.Link
  alias Hologram.UI.Runtime

  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>My Blog</title>
        <Runtime />
      </head>
      <body>
        <nav>
          <Link to={Blog.HomePage}>Home</Link>
        </nav>
        <main>
          <slot />
        </main>
      </body>
    </html>
    """
  end
end
