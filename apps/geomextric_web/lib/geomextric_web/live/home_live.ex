defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  use Phoenix.LiveView
  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(:dots, Geomextric.Canvas.get_all(Geomextric.Canvas) |> Enum.sort_by(&elem(&1, 0)))}
  end

  def handle_event("move", %{"id" => <<"d-", id::binary>>, "x" => x, "y" => y}, socket) do
    Geomextric.Canvas.move(Geomextric.Canvas, id, x, y)
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => <<"d-", id::binary>>}, socket) do
    Geomextric.Canvas.delete(Geomextric.Canvas, id)
    {:noreply, socket}
  end

  def handle_event("create", %{"pos" => %{"x" => x, "y" => y}} = params, socket) do
    Geomextric.Canvas.put(Geomextric.Canvas, x, y, params)
    {:noreply, socket}
  end

  def handle_event("clear", %{}, socket) do
    Geomextric.Canvas.clear(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_info({:inserted, id, new}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(:dots, &[{id, new} | &1])}
  end

  def handle_info({:moved, id, {x, y}}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :dots,
       &Enum.map(&1, fn
         {^id, %{} = old} -> {id, %{old | pos: {x, y}}}
         e -> e
       end)
     )}
  end

  def handle_info({:delete, id}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :dots,
       &Enum.filter(&1, fn
         {^id, _} -> false
         _ -> true
       end)
     )}
  end

  def handle_info(:clear, socket) do
    {:noreply,
     socket
     |> assign(:dots, [])
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def render(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
      @keyframes enter {
        from { transform: scale(0); }
        to   { transform: scale(1); }
      }
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
      <div id="drag-circle-a" phx-hook=".Draggable" draggable="true">
        <svg viewBox="-10 -10 20 20" fill="rebeccapurple" width="32" height="32">
          <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
        </svg>
      </div>

      <div id="drag-circle-b" phx-hook=".Draggable" draggable="true">
        <svg viewBox="-10 -10 20 20" fill="cyan" width="32" height="32">
          <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
        </svg>
      </div>

      <div id="drag-circle-c" phx-hook=".Draggable" draggable="true">
        <svg viewBox="-10 -10 20 20" fill="magenta" width="32" height="32">
          <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
        </svg>
      </div>

      <button phx-click="clear">Clear</button>
    </nav>
    <.canvas box={@box}>
      <circle class="origin" cx={0} cy={0} r={3} fill="#d0d0d0" data-non-scaling />
      <.circle
        :for={{id, %{pos: {x, y}, attrs: %{color: col}}} <- @dots}
        id={"d-#{id}"}
        x={x}
        y={y}
        r={10.0}
        fill={col}
      />
    </.canvas>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Draggable">
      export default {
        mounted() {
        function dragstartHandler(evt) {
          // Add different types of drag data
          var svg = evt.currentTarget.firstElementChild;
          evt.dataTransfer.setData(
            "text",
            svg.getAttribute("fill"),
          );
        }
          this.el.addEventListener('dragstart', dragstartHandler)

        }
      }
    </script>
    """
  end
end
