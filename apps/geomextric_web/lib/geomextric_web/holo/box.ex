defmodule Blog.Components.Box do
  use Hologram.Component

  prop(:post, :map)

  def init(params, component, _server) do
    # In real app, fetch from database
    post = %{
      id: params.post.id,
      title: "Example Pxost",
      content: "This is the full content...",
      likes: 0
    }

    IO.inspect(params)

    component
    |> put_state(:post, post)
  end

  def template do
    ~HOLO"""
    <article class="post-preview">
      <h2 style="color:red">{@post.title}</h2>
    </article>
    """
  end
end
