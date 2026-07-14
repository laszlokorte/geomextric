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
     |> assign(:axis, true)
     |> assign(:grid, true)
     |> assign(:bounds, true)
     |> assign(:extra_pen, "#0077ff")
     |> assign(:selection, [])
     |> assign(:tips, to_form(%{"target" => false, "source" => false}))
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )}
  end

  def handle_event("move", %{"id" => <<id::binary>>, "x" => x, "y" => y}, socket) do
    Geomextric.Canvas.move(Geomextric.Canvas, id, x, y)
    {:noreply, socket}
  end

  def handle_event("move", %{"dx" => dx, "dy" => dy}, socket) do
    Geomextric.Canvas.move_by(Geomextric.Canvas, socket.assigns.selection, dx, dy)
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => <<id::binary>>}, socket) do
    Geomextric.Canvas.delete(Geomextric.Canvas, id)
    {:noreply, socket}
  end

  def handle_event("delete", %{"value" => "selected"}, socket) do
    Geomextric.Canvas.delete_all(Geomextric.Canvas, socket.assigns.selection)
    {:noreply, socket}
  end

  def handle_event("recent", %{"value" => _v}, socket) do
    {:noreply, socket}
  end

  def handle_event("undo", %{}, socket) do
    Geomextric.Canvas.undo(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_event("redo", %{}, socket) do
    Geomextric.Canvas.redo(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_event("lasso", %{"width" => w, "height" => h, "x" => x, "y" => y}, socket) do
    {:noreply,
     socket
     |> update(
       :selection,
       fn _ ->
         Geomextric.Canvas.select_box(Geomextric.Canvas, %{width: w, height: h, x: x, y: y})
       end
     )}
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
    Geomextric.Canvas.reset(Geomextric.Canvas)
    {:noreply, socket}
  end

  def handle_event("change_pen", %{"value" => color}, socket) do
    {:noreply,
     socket
     |> assign(:pen, color)
     |> update(:extra_pen, fn p -> if(Enum.member?(@colors, color), do: p, else: color) end)}
  end

  def handle_event("set_grid", %{"value" => "true"}, socket) do
    {:noreply, socket |> assign(:grid, true)}
  end

  def handle_event("set_grid", %{"value" => "false"}, socket) do
    {:noreply, socket |> assign(:grid, false)}
  end

  def handle_event("set_axis", %{"value" => "true"}, socket) do
    {:noreply, socket |> assign(:axis, true)}
  end

  def handle_event("set_axis", %{"value" => "false"}, socket) do
    {:noreply, socket |> assign(:axis, false)}
  end

  def handle_event("set_bounds", %{"value" => "true"}, socket) do
    {:noreply, socket |> assign(:bounds, true)}
  end

  def handle_event("set_bounds", %{"value" => "false"}, socket) do
    {:noreply, socket |> assign(:bounds, false)}
  end

  def handle_event("select", %{"value" => ""}, socket) do
    {:noreply, socket |> assign(:selection, [])}
  end

  def handle_event("select", %{"value" => "all"}, socket) do
    {:noreply, socket |> assign(:selection, socket.assigns.layers |> Enum.map(& &1.id))}
  end

  def handle_event("select", %{"value" => id, "op" => "union"}, socket) do
    {:noreply, socket |> assign(:selection, [id | socket.assigns.selection] |> Enum.uniq())}
  end

  def handle_event("select", %{"value" => id, "op" => "toggle"}, socket) do
    {:noreply,
     socket
     |> assign(
       :selection,
       MapSet.new(socket.assigns.selection)
       |> MapSet.symmetric_difference(MapSet.new([id]))
       |> Enum.to_list()
     )}
  end

  def handle_event("select", %{"value" => id, "op" => "replace"}, socket) do
    {:noreply, socket |> assign(:selection, [id])}
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

  def handle_info({:inserted, new}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> update(:layers, &[new | &1])}
  end

  def handle_info({:moved, id, new_coords}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> update(
       :layers,
       &Enum.map(&1, fn
         %{id: ^id} = old -> %{old | pos: new_coords}
         e -> e
       end)
     )}
  end

  def handle_info({:delete, id}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> update(
       :layers,
       &Enum.filter(&1, fn
         %{id: ^id} -> false
         _ -> true
       end)
     )
     |> update(
       :selection,
       &Enum.filter(&1, fn
         ^id -> false
         _ -> true
       end)
     )}
  end

  def handle_info(:reload, socket) do
    {:noreply,
     socket
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def handle_info(:clear, socket) do
    {:noreply,
     socket
     |> assign(:layers, [])
     |> assign(:selection, [])
     |> assign(
       :history,
       Geomextric.Canvas.get_history(Geomextric.Canvas)
     )
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
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
        [data-zoomed=out] [data-non-scaling-max] {
                scale: var(--cam-scale-max);
                transform-box: fill-box;
                transform-origin: 50% 50%;
                stroke-width: 1;
                }
         [data-non-scaling-full] {
                 scale: var(--cam-scale);
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
         background: none;
         padding: 0;
         border: none;
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
         color: black;
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
      filter: saturate(0%) brightness(500%) ;
      }
      label:has(input[type=checkbox]:checked) {

      color: #fff;
      background: #000a;
      filter:  saturate(100%);

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
        <%= for {c,ci} <- [@extra_pen| colors()] |> Enum.with_index do %>
          <button
            name="color"
            phx-click="change_pen"
            value={c}
            id={"drag-circle-#{ci}"}
            phx-hook=".Draggable"
            draggable="true"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              data-type="circle"
              viewBox="-10 -10 20 20"
              fill={c}
              width="32"
              height="32"
            >
              <circle cx="0" cy="0" r={8} stroke="white" stroke-width="2" />
            </svg>
          </button>
        <% end %>
        <%= for {c, ci} <- [@extra_pen| colors()] |> Enum.with_index do %>
          <button
            name="color"
            phx-click="change_pen"
            value={c}
            id={"drag-rect-#{ci}"}
            phx-hook=".Draggable"
            draggable="true"
          >
            <svg
              data-type="rect"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="-10 -10 20 20"
              fill={c}
              width="32"
              height="32"
            >
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
          </button>
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
      </div>

      <div class="ghost">
        <form class="ghost" phx-change="change_tips">
          <.input_plain
            phx-hook=".Draggable"
            draggable="true"
            label="Source"
            type="checkbox"
            field={@tips[:source]}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              data-type="line"
              color={@pen}
              target-tip
              viewBox="-15 -15 30 30"
              fill="currentColor"
              width="28"
              height="28"
            >
              <path
                d={"M #{-10} #{0} h #{20} z"}
                stroke={@pen}
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="5"
              />
              <path
                d={"M #{-15} #{0} l #{15} #{10} v #{-20} z"}
                fill={@pen}
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </.input_plain>

          <.input_plain
            label="Target"
            type="checkbox"
            field={@tips[:target]}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              data-type="line"
              color={@pen}
              source-tip
              viewBox="-15 -15 30 30"
              fill="currentColor"
              width="28"
              height="28"
            >
              <path
                d={"M #{10} #{0} h #{-20} z"}
                stroke={@pen}
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="5"
              />
              <path
                d={"M #{15} #{0} l #{-15} #{10} v #{-20} z"}
                fill={@pen}
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
            %{label: "Clear", send: "clear", shortcut: [key: "x", ctrl: true]},
            %{
              label: "Recent",
              items:
                for(
                  n <- 1..5,
                  do: %{
                    label: "File #{n}",
                    send: "recent",
                    value: n,
                    shortcut: [key: "#{n}", ctrl: true]
                  }
                )
            }
          ]
        },
        %{
          label: "Edit",
          items:
            with(
              {u, r} <- @history,
              do: [
                %{label: "Undo", send: "undo", active: u > 0, shortcut: [key: "z", ctrl: true]},
                %{label: "Redo", send: "redo", active: r > 0, shortcut: [key: "y", ctrl: true]},
                %{
                  label: "Delete",
                  shortcut: [key: "Delete"],
                  active: not Enum.empty?(@selection),
                  send: "delete",
                  value: "selected"
                }
              ]
            )
        },
        %{
          label: "Selection",
          items: [
            %{
              label: "Select All",
              shortcut: [key: "a", ctrl: true],
              send: "select",
              value: :all
            },
            %{label: "Unselect", shortcut: [key: "Escape"], send: "select", value: ""}
          ]
        },
        %{
          label: "View",
          items: [
            %{
              label: if(@grid, do: "Hide Grid", else: "Show Grid"),
              shortcut: [key: "g", alt: true],
              send: "set_grid",
              value: if(@grid, do: "false", else: "true")
            },
            %{
              label: if(@axis, do: "Hide Axis", else: "Show Axis"),
              shortcut: [key: "a", alt: true],
              send: "set_axis",
              value: if(@axis, do: "false", else: "true")
            },
            %{
              label: if(@bounds, do: "Hide Bounds", else: "Show Bounds"),
              shortcut: [key: "b", alt: true],
              send: "set_bounds",
              value: if(@bounds, do: "false", else: "true")
            }
          ]
        },
        %{
          label: "Help",
          items: [
            %{
              label: "www.laszlokorte.de",
              shortcut: [key: "h", ctrl: true],
              link: "https://www.laszlokorte.de"
            }
          ]
        }
      ]}>
        <div class="segment">
          <div class="connection-status connected">Connected 🟢</div>
          <div class="connection-status disconnected">Reconnecting... 🔴</div>
        </div>
      </.menu>
    </div>
    <div style={"--auto-stroke: #{@pen}; --auto-fill: #{@pen}"}>
      <.canvas grid={@grid} bounds={@bounds} box={@box}>
        <g :if={@axis} shape-rendering="geometricPrecision">
          <line
            x1={@box.x + @box.width * 0.01}
            y1="0"
            x2={@box.x + @box.width * 0.98}
            y2="0"
            stroke-width="6"
            shape-rendering="geometricPrecision"
            vector-effect="non-scaling-stroke"
            stroke="#fff"
          />
          <line
            y1={@box.y + @box.height * 0.01}
            x1="0"
            y2={@box.y + @box.height * 0.98}
            x2="0"
            stroke-width="6"
            shape-rendering="geometricPrecision"
            vector-effect="non-scaling-stroke"
            stroke="#fff"
          />
          <line
            x1={@box.x + @box.width * 0.01}
            y1="0"
            x2={@box.x + @box.width * 0.98}
            y2="0"
            stroke-width="1"
            shape-rendering="geometricPrecision"
            vector-effect="non-scaling-stroke"
            stroke="#333"
          />
          <line
            y1={@box.y + @box.height * 0.01}
            x1="0"
            y2={@box.y + @box.height * 0.98}
            x2="0"
            stroke-width="1"
            shape-rendering="geometricPrecision"
            vector-effect="non-scaling-stroke"
            stroke="#333"
          />

          <path
            d={"M  #{@box.x + @box.width * 0.98} 0 l -16 -10 l 5 10 l -5 10 z"}
            data-non-scaling
            stroke="white"
            stroke-width="4"
            stroke-linecap="round"
            stroke-linejoin="round"
            style=" transform-origin: 100% 50%; "
            fill="white"
          />

          <path
            d={"M 0 #{@box.y + @box.height * 0.01} l -10 16 l 10 -5 l 10 5 z"}
            data-non-scaling
            stroke="white"
            stroke-width="4"
            stroke-linecap="round"
            stroke-linejoin="round"
            style=" transform-origin: 50% 0%; "
            fill="white"
          />

          <path
            d={"M  #{@box.x + @box.width * 0.98} 0 l -16 -10 l 5 10 l -5 10 z"}
            data-non-scaling
            style=" transform-origin: 100% 50%; "
            fill="#777"
          />

          <path
            d={"M 0 #{@box.y + @box.height * 0.01} l -10 16 l 10 -5 l 10 5 z"}
            style=" transform-origin: 50% 0%; "
            data-non-scaling
            fill="#777"
          />

          <circle class="origin" cx={0} cy={0} r={2} fill="#666" data-non-scaling />
        </g>

        <g id="layers">
          <%= for %{id: id} = l <- @layers |> Enum.reverse() do %>
            <%= case l do %>
              <% %{pos: {x, y}, attrs: %{color: col, radius: r}} -> %>
                <.circle
                  id={"#{id}"}
                  x={x}
                  y={y}
                  r={r}
                  fill={col}
                />
              <% %{pos: {x, y, w, h}, attrs: %{color: col, radius: r}} -> %>
                <.rect
                  id={"#{id}"}
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
                  id={"#{id}"}
                  stroke_width={w}
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke={col}
                />
            <% end %>
          <% end %>
        </g>
        <g id="layers-selection" multi-drag-root>
          <%= for %{id: id} = l <- @layers |> Enum.reverse(), Enum.member?(@selection, id) do %>
            <%= case l do %>
              <% %{pos: {x, y}, attrs: %{color: col, radius: r}} -> %>
                <.circle
                  handles={true}
                  prefix="sel-"
                  id={"#{id}"}
                  x={x}
                  y={y}
                  r={r}
                  fill={col}
                />
              <% %{pos: {x, y, w, h}, attrs: %{color: col, radius: r}} -> %>
                <.rect
                  handles={true}
                  prefix="sel-"
                  id={"#{id}"}
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
                  handles={true}
                  source_tip={source_tip}
                  target_tip={target_tip}
                  prefix="sel-"
                  id={"#{id}"}
                  stroke_width={w}
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke={col}
                />
            <% end %>
          <% end %>
        </g>
      </.canvas>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Draggable">
      export default {
        mounted() {
          const canvas = document.createElement("canvas");
          canvas.width = 24;
          canvas.height = 24;
          const ctx = canvas.getContext("2d");
          const blob = new Blob([this.el.querySelector("svg").outerHTML], {
            type: "image/svg+xml",
          });
          const url = URL.createObjectURL(blob);
          const img = new Image();

          img.width = 24;
          img.height = 24;
          img.onload = function () {
            ctx.clearRect(0, 0, 24, 24);
            ctx.drawImage(img, 0, 0, 24, 24);
            URL.revokeObjectURL(url);
          };
          img.onerror = (e) => console.error(e);
          img.src = url;

          function dragstartHandler(evt) {
            var svg = evt.currentTarget.querySelector("svg");

            evt.dataTransfer.setDragImage(svg, 0, 0);
            evt.dataTransfer.setData(
              "text",
              JSON.stringify({
                type: svg.getAttribute("data-type"),
                color: svg.getAttribute("fill"),
                source_tip: svg.hasAttribute("source-tip"),
                target_tip: svg.hasAttribute("target-tip"),
              }),
            );
          }
          this.el.addEventListener("dragstart", dragstartHandler);
        },
      };
    </script>
    """
  end

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
    <label id={@name} draggable="true" phx-hook=".Draggable">
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
