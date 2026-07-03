defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  use Phoenix.LiveView
  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:dots, Geomextric.Canvas.get_all(Geomextric.Canvas))}
  end

  def handle_event("move", %{"id" => <<"d-", id::binary>>, "x" => x, "y" => y}, socket) do
    Geomextric.Canvas.move(Geomextric.Canvas, id, x, y)
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => <<"d-", id::binary>>}, socket) do
    Geomextric.Canvas.delete(Geomextric.Canvas, id)
    {:noreply, socket}
  end

  def handle_event("create", %{"x" => x, "y" => y}, socket) do
    Geomextric.Canvas.put(Geomextric.Canvas, x, y)
    {:noreply, socket}
  end

  def handle_event("clear", %{}, socket) do
    Geomextric.Canvas.clear(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_info({:inserted, id, {x, y}}, socket) do
    {:noreply, socket |> update(:dots, &Map.put(&1, id, {x, y}))}
  end

  def handle_info({:moved, id, {x, y}}, socket) do
    {:noreply, socket |> update(:dots, &Map.replace(&1, id, {x, y}))}
  end

  def handle_info({:delete, id}, socket) do
    {:noreply, socket |> update(:dots, &Map.delete(&1, id))}
  end

  def handle_info(:clear, socket) do
    {:noreply, socket |> assign(:dots, Map.new())}
  end

  def render(assigns) do
    minX =
      assigns.dots
      |> Map.values()
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    minY =
      assigns.dots
      |> Map.values()
      |> Enum.map(fn {_, y} -> y end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    maxX =
      assigns.dots
      |> Map.values()
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    maxY =
      assigns.dots
      |> Map.values()
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
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
       .origin {
      scale: var(--cam-scale);
      transform-box: fill-box;
      transform-origin: 50% 50%;
      }

      [data-non-scaling] {
        scale: var(--cam-scale-min);
        transform-box: fill-box;
        transform-origin: 50% 50%;
        }
      [data-non-scaling][fill=magenta]:hover {
      transform: scale(150%);
      }
      nav {
        position: fixed;
        height: auto;
        top: 0;
        left: 0;
        right: 0;
        margin: 1ex;
        padding: 1ex;
        color: #fff;
        display: flex;
        gap: 1ex;

        background: #0003;
        z-index: 1000;
        flex-direction: row;
        align-items: center;
      }
      button {
      background: #000;
      color: #fff;
      padding: 1ex;
      }

      [draggable="true"]{
        cursor: grab;
      }
    </style>
    <nav>
      <div id="drag-circle" phx-hook=".Draggable" draggable="true">
        <svg viewBox="-10 -10 20 20" width="32" height="32">
          <circle cx="0" cy="0" r={8} fill="#0fa" stroke="white" stroke-width="2" />
        </svg>
      </div>

      <button phx-click="clear">Clear</button>
    </nav>
    <.canvas box={@box}>
      <circle class="origin" cx={0} cy={0} r={3} fill="#d0d0d0" data-non-scaling />
      <%= for {id, {x,y}} <- @dots  do %>
        <.circle id={"d-#{id}"} x={x} y={y} r={10.0} fill="magenta" />
      <% end %>
    </.canvas>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Draggable">
      export default {
        mounted() {
        function dragstartHandler(evt) {
          // Add different types of drag data
          var svg = evt.currentTarget.firstElementChild;
          evt.dataTransfer.setData(
            "text/uri-list",
            evt.target.ownerDocument.location.href,
          );
        }
          this.el.addEventListener('dragstart', dragstartHandler)

        }
      }
    </script>
    """
  end
end
