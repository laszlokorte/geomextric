defmodule GeomextricWeb.HomeLive do
  import GeomextricWeb.CoreComponents
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  import GeomextricWeb.Menu
  import GeomextricWeb.Rectangle
  import GeomextricWeb.Line
  use Phoenix.LiveView
  @topic "canvas"
  @colors ["#ff00ff", "#00ffff", "#00ff00", "#ffaa00"]

  def colors, do: @colors

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:pen, "#0077ff")
     |> assign(:tips, to_form(%{"target" => false, "source" => false}))
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas) |> Enum.sort_by(&elem(&1, 0))
     )}
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
      Map.merge(
        %{
          "color" => socket.assigns.pen,
          "source_tip" => socket.assigns.tips[:source].value,
          "target_tip" => socket.assigns.tips[:target].value
        },
        params
      )
    )

    {:noreply, socket}
  end

  def handle_event("clear", %{}, socket) do
    Geomextric.Canvas.clear(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_event("change_pen", %{"value" => color}, socket) do
    {:noreply, socket |> assign(:pen, color)}
  end

  def handle_event("change_tips", %{"source" => s, "target" => t}, socket) do
    {:noreply,
     socket
     |> assign(
       :tips,
       to_form(%{
         "target" => t == "true",
         "source" => s == "true"
       })
     )}
  end

  def handle_info({:inserted, id, new}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(:layers, &[{id, new} | &1])}
  end

  def handle_info({:moved, id, new_coords}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :layers,
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
       :layers,
       &Enum.filter(&1, fn
         {^id, _} -> false
         _ -> true
       end)
     )}
  end

  def handle_info(:clear, socket) do
    {:noreply,
     socket
     |> assign(:layers, [])
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def handle_info(:reload, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas) |> Enum.sort_by(&elem(&1, 0))
     )}
  end

  def render(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
      body {
      font-family: monospace, monospace;
      font-size: 1em;
      }
       @keyframes enter {
         from { transform: scale(0); }
         to   { transform: scale(1); }
       }
        .origin {
       scale: var(--cam-scale);
       transform-box: fill-box;
       transform-origin: 50% 50%;
       }

       svg[data-zoomed="out"] [data-non-zoom-stroke="yes"] {
       vector-effect: non-scaling-stroke;

            }

            svg[data-zoomed="out"] [data-non-zoom-stroke="min"] {
            vector-effect: non-scaling-stroke;
            stroke-width: 5;

                 }
       [data-non-scaling] {
         scale: var(--cam-scale-min);
         transform-box: fill-box;
         transform-origin: 50% 50%;
         }

        .auto-color {
        fill: var(--auto-fill, attr("fill"));
        stroke: var(--auto-stroke, attr("stroke"));
        }
       .toolbar {
       flex-wrap: wrap-reverse;
       border-radius: 1ex;
         position: fixed;
         height: auto;
         top: 2em;
         left: 0;
         right: 1em;
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
       padding: 0.5ex 1em;
       cursor: pointer;

       border-radius: 0.5ex;
       align-self: stretch;
       }

       [draggable="true"]{
         cursor: grab;
       }

       ::-moz-color-swatch {
       border: none;
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
       display: inherit;
       gap: inherit;
       flex-wrap: wrap;
       }

       .ghost {
         display: contents;
       }
       label {
       display: flex;
       align-items: center;
       flex-direction: row;
       gap: 1ex;
       margin-right: 1em;
       }

       .connection-status {
         display: flex;
         flex-direction: row;
         margin-left: auto;
         margin-right: 1em;
         white-space: nowrap;
       }
       .push-right {
       display: inherit;
       align-self: stretch;
       align-items: inherit;
       margin-left: auto;
       }

       .color-list {
       display: flex;
       background: #0005;
       padding: 0.8ex;
       border-radius: 0.5ex;
       }
       .connection-status {
       display: none;
       }

       .phx-loading .disconnected {
         display: block;
       }

       .phx-connected .connected {
         display: block;
       }

      .menu-bar {
      position: absolute;
      top: 0em;
      left: 0em;
      right: 0em;
      z-index: 1000;
      }
      input[type=checkbox] {
      display: none;
      }
      label:has(input[type=checkbox]) {
      color: #fff;
      align-self: stretch;
      display: flex;
      align-items: center;
      border-radius: 0.5ex;
      padding: 0.5ex;
      margin: 0;
      background: #0001;
      user-select: none;
      }
      label:has(input[type=checkbox]:checked) {

      color: #fff;
      background: #000a;

      }

      label:has(input[type=checkbox]) svg {

            opacity: 0.5;

            }
      label:has(input[type=checkbox]:checked) svg {

            opacity: 1;

            }
    </style>
    <nav class="toolbar">
      <div class="pallette">
        <%= for c <- colors() do %>
          <div id={"drag-circle-#{c}"} phx-hook=".Draggable" draggable="true">
            <svg data-type="circle" viewBox="-10 -10 20 20" fill={c} width="32" height="32">
              <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
            </svg>
          </div>
        <% end %>
        <%= for c <- colors() do %>
          <div id={"drag-rect-#{c}"} phx-hook=".Draggable" draggable="true">
            <svg data-type="rect" viewBox="-10 -10 20 20" fill={c} width="32" height="32">
              <rect
                rx="5"
                ry="5"
                x="-8"
                y="-8"
                width="16"
                height="16"
                stroke="white"
                stroke-width="2"
              />
            </svg>
          </div>
        <% end %>
      </div>

      <div class="color-list">
        <form class="ghost" phx-change="change_pen">
          <label>
            <div class="color-border">
              <input type="color" name="value" value={@pen} />
            </div>
            <span style={"text-shadow: 0 0 5px #{@pen}; font-family: monospace, monospace;"}>
              {@pen}
            </span>
          </label>
        </form>

        <button
          :for={c <- colors()}
          style="padding: 0; background: none;"
          name="color"
          phx-click="change_pen"
          value={c}
        >
          <svg data-type="rect" viewBox="-10 -10 20 20" fill={c} width="28" height="28">
            <rect
              rx="20"
              ry="20"
              x="-8"
              y="-8"
              width="16"
              height="16"
              stroke="#0005"
              stroke-width="1"
            />
          </svg>
        </button>
      </div>

      <div class="ghost">
        <form class="ghost" phx-change="change_tips">
          <.input_plain label="Source" type="checkbox" field={@tips[:source]}>
            <svg data-type="rect" viewBox="-15 -15 30 30" fill="currentColor" width="28" height="28">
              <path
                d={"M #{-10} #{0} h #{20} z"}
                stroke="currentColor"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="5"
              />
              <path
                d={"M #{-15} #{0} l #{15} #{10} v #{-20} z"}
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </.input_plain>

          <.input_plain label="Target" type="checkbox" field={@tips[:target]}>
            <svg data-type="rect" viewBox="-15 -15 30 30" fill="currentColor" width="28" height="28">
              <path
                d={"M #{10} #{0} h #{-20} z"}
                stroke="currentColor"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="5"
              />
              <path
                d={"M #{15} #{0} l #{-15} #{10} v #{-20} z"}
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </.input_plain>
        </form>
      </div>
      <div class="push-right">
        <button phx-click="clear">Clear</button>
      </div>
    </nav>

    <div class="menu-bar">
      <.menu items={[
        %{
          label: "File",
          items: [
            %{
              label: "Save"
            },
            %{label: "Clear", send: "clear"},
            %{
              label: "Recent",
              items: [
                %{label: "A"},
                %{label: "A"},
                %{label: "A"},
                %{label: "A"}
              ]
            }
          ]
        },
        %{
          label: "Edit",
          items: [
            %{label: "Undo"},
            %{label: "Redo"}
          ]
        },
        %{
          label: "Selection",
          items: [
            %{label: "Select All"},
            %{label: "Unselect"}
          ]
        },
        %{
          label: "Help"
        }
      ]}>
        <div class="segment">
          <div class="connection-status connected">Connected 🟢</div>
          <div class="connection-status disconnected">Reconnecting... 🔴</div>
        </div>
      </.menu>
    </div>
    <div style={"--auto-stroke: #{@pen}; --auto-fill: #{@pen}"}>
      <.canvas box={@box}>
        <g shape-rendering="optimizeSpeed">
          <line
            x1={@box.x}
            y1="0"
            x2={@box.x + @box.width}
            y2="0"
            stroke-width="2"
            vector-effect="non-scaling-stroke"
            stroke="#777"
          />
          <line
            y1={@box.y}
            x1="0"
            y2={@box.y + @box.height}
            x2="0"
            stroke-width="2"
            vector-effect="non-scaling-stroke"
            stroke="#777"
          />

          <path
            fill="white"
            d={"M  #{@box.x + @box.width} 0 v -10 h -10 v 20 h 10"}
            data-non-scaling
            style=" transform-origin: 100% 50%; "
          />
          <path
            d={"M  #{@box.x + @box.width} 0 l -10 -10 v 20"}
            data-non-scaling
            style=" transform-origin: 100% 50%; "
            fill="#777"
          />
          <path
            d={"M 0 #{@box.y} h 10 v 10 h -20 v -10"}
            data-non-scaling
            fill="white"
            style=" transform-origin: 50% 0%; "
          />
          <path
            d={"M 0 #{@box.y} l -10 10 h 20"}
            data-non-scaling
            style=" transform-origin: 50% 0%; "
            fill="#777"
          />
        </g>
        <circle class="origin" cx={0} cy={0} r={3} fill="#666" data-non-scaling />
        <%= for {id, l} <- @layers do %>
          <%= case l do %>
            <% %{pos: {x, y}, attrs: %{color: col, radius: r}} -> %>
              <.circle
                id={"d-#{id}"}
                x={x}
                y={y}
                r={r}
                fill={col}
              />
            <% %{pos: {x, y, w, h}, attrs: %{color: col, radius: r}} -> %>
              <.rect
                id={"d-#{id}"}
                x={x}
                y={y}
                rx={r}
                ry={r}
                width={w}
                height={h}
                fill={col}
              />
            <% %{pos: {{x1, y1}, {x2, y2}}, attrs: %{color: col, thickness: w, source_tip: source_tip, target_tip: target_tip}} -> %>
              <.line
                source_tip={source_tip}
                target_tip={target_tip}
                id={"d-#{id}"}
                stroke_width={w}
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke={col}
              />
          <% end %>
        <% end %>
      </.canvas>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Draggable">
      export default {
        mounted() {
          function dragstartHandler(evt) {
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

  slot :inner_block, required: false

  def input_plain(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input_plain()
  end

  def input_plain(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <label>
      <input
        type="hidden"
        name={@name}
        value="false"
      />
      <input
        type="checkbox"
        name={@name}
        value="true"
        checked={@checked}
      />
      {render_slot(@inner_block) || @label}
    </label>
    """
  end
end
