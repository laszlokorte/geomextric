defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
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

  def handle_event("create", %{"pos" => %{"x" => x, "y" => y}} = params, socket) do
    Geomextric.Canvas.put(
      Geomextric.Canvas,
      x,
      y,
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

        input[type="color"]::-webkit-color-swatch-wrapper
         {
      padding: 0;
        }
        input[type="color"]::-webkit-color-swatch {
      border: none;
        }
    </style>
    <nav>
      <div class="pallette">
        <%= for c <- ["magenta", "cyan", "lightblue"] do %>
          <div id={"drag-circle-#{c}"} phx-hook=".Draggable" draggable="true">
            <svg viewBox="-10 -10 20 20" fill={c} width="32" height="32">
              <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
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

      <button style="margin-left: auto;" phx-click="clear">Clear</button>
    </nav>
    <.canvas box={@box}>
      <circle class="origin" cx={0} cy={0} r={3} fill="#666" data-non-scaling />
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
          evt.dataTransfer.setDragImage(svg, 0,0)
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
