defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  use Phoenix.LiveView
  @topic "circle"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:dots, [])}
  end

  def handle_event("move", %{"id" => <<"d-", id::binary>>, "x" => x, "y" => y}, socket) do
    index = String.to_integer(id)
    {:noreply, socket |> update(:dots, &List.replace_at(&1, index, {x, y}))}
  end

  def handle_event("create", %{"x" => x, "y" => y}, socket) do
    GeomextricWeb.Endpoint.broadcast(@topic, "created", {x, y})

    {:noreply, socket}
  end

  def handle_info(%{event: "created", payload: {x, y}}, socket) do
    {:noreply,
     socket
     |> update(:dots, &[{x, y} | &1])}
  end

  def render(assigns) do
    minX =
      assigns.dots
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    minY =
      assigns.dots
      |> Enum.map(fn {_, y} -> y end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    maxX =
      assigns.dots
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    maxY =
      assigns.dots
      |> Enum.map(fn {_, y} -> y end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    assigns =
      assign(assigns, :box, %{
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY
      })

    ~H"""
    <.canvas box={@box}>
      <%= for {{x,y}, i} <- @dots |> Enum.with_index() do %>
        <.circle id={"d-#{i}"} x={x} y={y} r={50.0} fill="magenta" />
      <% end %>
    </.canvas>
    """
  end
end
