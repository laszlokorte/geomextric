defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  import GeomextricWeb.Rectangle
  use Phoenix.LiveView
  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:pen, "#0077ff")
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

  def handle_event("lasso", %{"width" => w, "height" => h, "x" => x, "y" => y}, socket) do
    Geomextric.Canvas.delete_box(Geomextric.Canvas, %{width: w, height: h, x: x, y: y})
    {:noreply, socket}
  end

  def handle_event(
        "create",
        %{"pos" => %{"x" => x, "y" => y, "width" => w, "height" => h}} = params,
        socket
      ) do
    Geomextric.Canvas.put(
      Geomextric.Canvas,
      x,
      y,
      w,
      h,
      Map.merge(%{"color" => socket.assigns.pen}, params)
    )

    {:noreply, socket}
  end

  def handle_event("create", %{"pos" => %{"x" => x, "y" => y}} = params, socket) do
    Geomextric.Canvas.put(
      Geomextric.Canvas,
      x,
      y,
      Map.merge(%{"color" => socket.assigns.pen}, params)
    )

    {:noreply, socket}
  end

  def handle_event(
        "create",
        %{"start" => %{"x" => x1, "y" => y1}, "end" => %{"x" => x2, "y" => y2}} = params,
        socket
      ) do
    Geomextric.Canvas.put(
      Geomextric.Canvas,
      {x1, y1},
      {x2, y2},
      Map.merge(%{"color" => socket.assigns.pen}, params)
    )

    {:noreply, socket}
  end

  def handle_event("clear", %{}, socket) do
    Geomextric.Canvas.clear(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_event("change_pen", %{"color" => color}, socket) do
    {:noreply, socket}
    {:noreply, socket |> assign(:pen, color)}
  end

  def handle_info({:inserted, id, new}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(:dots, &[{id, new} | &1])}
  end

  def handle_info({:moved, id, new_coords}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :dots,
       &Enum.map(&1, fn
         {^id, %{} = old} -> {id, %{old | pos: new_coords}}
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

  def handle_info(:reload, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(:dots, Geomextric.Canvas.get_all(Geomextric.Canvas) |> Enum.sort_by(&elem(&1, 0)))}
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
      border-radius: 1ex;
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

      border-radius: 1ex;
      }

      [draggable="true"]{
        cursor: grab;
      }

      input[type=color] {
      border: none;
      display: block;
      width: 100%;
      height: 100%;
      appearance: none;
      	-webkit-appearance: none;
      width: 3ex;
      height: 3ex;
      margin: 0;
      padding: 0;
      }
      .color-border {
      display: grid;
      border-radius: 100vw;
      width: 3ex;
      height: 3ex;
      overflow: hidden;
      padding: 0;
      outline: 2px solid white;
      }

      .pallette {
      border-right: 2px solid #0005;
      display: inherit;
      gap: inherit;
      padding-right: 1ex;
      margin-right: 1ex;
      }

      form.ghost {
        display: contents;
      }
      label {
      display: flex;
      align-items: center;
      flex-direction: row;
      gap: 1ex;
      background: #0005;
      padding: 0.8ex;
      border-radius: 0.5ex;
      }

      .connection-status {
        display: flex;
        flex-direction: row;
        margin-left: auto;
        margin-right: 1em;
      }

      .phx-connected .disconnected {
        display: none;
      }

      .phx-loading .connected {
        display: none;
      }
    </style>
    <nav>
      <div class="pallette">
        <%= for c <- ["magenta", "cyan", "lightblue"] do %>
          <div id={"drag-circle-#{c}"} phx-hook=".Draggable" draggable="true">
            <svg data-type="circle" viewBox="-10 -10 20 20" fill={c} width="32" height="32">
              <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
            </svg>
          </div>
        <% end %>
        <%= for c <- ["magenta", "cyan", "lightblue"] do %>
          <div id={"drag-rect-#{c}"} phx-hook=".Draggable" draggable="true">
            <svg data-type="rect" viewBox="-10 -10 20 20" fill={c} width="32" height="32">
              <rect x="-8" y="-8" width="16" height="16" stroke="white" stroke-width="2" />
            </svg>
          </div>
        <% end %>
      </div>

      <form class="ghost" phx-change="change_pen">
        <label>
          <div class="color-border">
            <input type="color" name="color" value={@pen} />
          </div>
          <span style={"text-shadow: 0 0 5px #{@pen}"}>
            {@pen}
          </span>
        </label>
      </form>

      <button phx-click="clear">Clear</button>
      <div class="connection-status connected">Connected 🟢</div>
      <div class="connection-status disconnected">Reconnecting... 🔴</div>
    </nav>
    <.canvas box={@box}>
      <g opacity="0.4">
        <line
          x1={@box.x}
          y1="0"
          x2={@box.x + @box.width}
          y2="0"
          vector-effect="non-scaling-stroke"
          stroke="black"
        />
        <line
          y1={@box.y}
          x1="0"
          y2={@box.y + @box.height}
          x2="0"
          vector-effect="non-scaling-stroke"
          stroke="black"
        />
        <path
          d={"M  #{@box.x + @box.width} 0 l -10 -10 v 20"}
          data-non-scaling
          style=" transform-origin: 100% 50%; "
        />

        <path
          d={"M 0 #{@box.y} l -10 10 h 20"}
          data-non-scaling
          style=" transform-origin: 50% 0%; "
        />
      </g>
      <circle class="origin" cx={0} cy={0} r={3} fill="#666" data-non-scaling />
      <.circle
        :for={
          {id, %{pos: {x, y}, attrs: %{color: col, radius: r}}} when is_float(x) and is_float(y) <-
            @dots
        }
        id={"d-#{id}"}
        x={x}
        y={y}
        r={r}
        fill={col}
      />
      <.rect
        :for={{id, %{pos: {x, y, w, h}, attrs: %{color: col, radius: r}}} <- @dots}
        id={"d-#{id}"}
        x={x}
        y={y}
        width={w}
        height={h}
        fill={col}
      />
      <line
        :for={
          {id, %{pos: {{x1, y1}, {x2, y2}}, attrs: %{color: col}}} <-
            @dots
        }
        id={"d-#{id}"}
        stroke="black"
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        fill={col}
      />
    </.canvas>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Draggable">
      export default {
        mounted() {
          function dragstartHandler(evt) {
            // Add different types of drag data
            var svg = evt.currentTarget.firstElementChild;
            evt.dataTransfer.setDragImage(svg, 0, 0);
            evt.dataTransfer.setData(
              "text",
              JSON.stringify({
                type: svg.getAttribute("data-type"),
                color: svg.getAttribute("fill"),
              }),
            );
          }
          this.el.addEventListener("dragstart", dragstartHandler);
        },
      };
    </script>
    """
  end
end
