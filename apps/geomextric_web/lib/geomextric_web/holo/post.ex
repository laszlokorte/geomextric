defmodule Blog.PostPage do
  use Hologram.Page
  alias Blog.Components.Box

  route("/posts/:id")

  param(:id, :integer)

  layout(Blog.MainLayout)

  def init(params, component, _server) do
    # In real app, fetch from database
    post = %{
      id: params.id,
      title: "Example Post",
      content: "This is the full content...",
      likes: 0
    }

    put_state(component, :post, post)
  end

  def template do
    ~HOLO"""
    <article>
      <h1>{@post.title}</h1>
      <p>{@post.content}</p>

      <div class="likes">
        Likes: {@post.likes}
        <button $click="like_post">Like</button>
        <button $click="like_local">Like</button>
      </div>
      <Box cid="123" post={@post}/>
      <svg viewBox="-100 -100 200 200">
      <circle $pointer_down="start_drag" $pointer_move.prevent_default="move_drag" cx={0} cy={0} r={20}/>
      </svg>
    </article>
    """
  end

  def action(:move_drag, _params, component) do
    # Update likes locally first for instant feedback
    component
  end

  def action(:start_drag, _params, component) do
    # Update likes locally first for instant feedback
    component
  end

  def action(:like_post, _params, component) do
    # Update likes locally first for instant feedback
    component
    |> put_state([:post, :likes], component.state.post.likes + 1)
    |> put_command(:save_like, post_id: component.state.post.id)
  end

  def action(:like_local, _params, component) do
    # Update likes locally first for instant feedback
    component
    |> put_state([:post, :likes], component.state.post.likes + 1)
  end

  def action(:confirm_like, _params, component) do
    # Update likes locally first for instant feedback
    component
    |> put_state([:post, :likes], component.state.post.likes + 2)
  end

  def command(:save_like, params, server) do
    # In real app, save to database
    IO.puts("Liked post #{params.post_id}")

    server
    |> put_action(:confirm_like)
  end
end
