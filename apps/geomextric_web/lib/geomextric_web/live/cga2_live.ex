defmodule GeomextricWeb.CGA2Live do
  alias Galixir.Algebras.CGA2
  use GeomextricWeb, :live_view
  import GeomextricWeb.CoreComponents
  import GeomextricWeb.Canvas
  import GeomextricWeb.Menu
  @colors ["#ff00ff", "#00ffff", "#00ff00", "#ffaa00"]

  def colors, do: @colors

  def mount(%{}, _, socket) do
    {:ok,
     socket
     |> assign(:pen, "#0077ff")
     |> assign(:points, %{
       "p6" => CGA2.point(600, 100),
       "p0" => CGA2.point(100, 40),
       "p1" => CGA2.point(100, 150),
       "p2" => CGA2.point(0, 100),
       "p4" => CGA2.point(504.14453125, 68.11901092529297),
       "p5" => CGA2.point(430, 200)
     })
     |> assign(:axis, true)
     |> assign(:grid, true)
     |> assign(:bounds, true)
     |> assign(:extra_pen, "#0077ff")
     |> assign(:box, %{
       x: -800,
       y: -500,
       width: 1600,
       height: 1000
     })}
  end

  def normalize_point(p) do
    w = CGA2.dot(p, CGA2.e_o())

    if abs(w) < 1.0e-5 do
      dbg(p)
      raise ArgumentError, "cannot normalize point with zero weight"
    end

    CGA2.scale(p, 1.0 / w)
  end

  def point?(p) do
    CGA2.grades(p) == [1] and
      null?(p) and
      abs(CGA2.dot(p, CGA2.e_inf())) > 1.0e-10
  end

  defp null?(p) do
    n2 = abs(CGA2.dot(p, p))

    scale =
      p.data
      |> Tuple.to_list()
      |> Enum.map(&abs/1)
      |> Enum.sum()

    n2 < 1.0e-12 * max(scale * scale, 1.0)
  end

  def circle?(c) do
    CGA2.grades(c) == [3]
  end

  def line?(l) do
    CGA2.grades(l) == [3] and
      CGA2.coefficient(l, :e12pm) == 0
  end

  def point_pair?(x) do
    CGA2.grades(x) == [2]
  end

  def circle_parameters(c) do
    v = CGA2.gp(c, CGA2.inverse(CGA2.pseudoscalar()))

    e1 = CGA2.coefficient(v, :e1) || 0.0
    e2 = CGA2.coefficient(v, :e2) || 0.0

    ep = CGA2.coefficient(v, :ep) || 0.0
    em = CGA2.coefficient(v, :em) || 0.0

    w = em - ep

    if abs(w) < 1.0e-10 do
      {:line,
       {
         e1,
         e2,
         (em + ep) / 2
       }}
    else
      x = e1 / w
      y = e2 / w

      k = (em + ep) / (2 * w)

      r =
        :math.sqrt(
          x * x +
            y * y -
            2 * k
        )

      {:circle, {{x, y}, r}}
    end
  end

  def split(o) do
    import Galixir.Algebras.CGA2

    ei = e_inf()
    eo = e_o()

    nix = wedge(o, ei)

    nix2 = scalar_part(inner(nix, nix))

    if abs(nix2) < 1.0e-12 do
      :invalid
      # raise ArgumentError, "invalid point pair"
    else
      r2 =
        scalar_part(inner(o, o)) / nix2

      r = :math.sqrt(abs(r2))

      pos =
        o
        |> gp(inverse(nix))

      attitude =
        wedge(ei, eo)
        |> inner(nix)
        |> normalize()
        |> scale(r)

      kind =
        cond do
          r2 >= 0 ->
            :real

          true ->
            :imag
        end

      {
        kind,
        normalize_point(add(pos, attitude)),
        normalize_point(sub(pos, attitude))
      }
    end
  end

  def classify(x) do
    cond do
      point?(x) ->
        {:point, CGA2.point_coordinates(x)}

      circle?(x) ->
        {:circle, circle_parameters(x)}

      line?(x) ->
        {:line, line_parameters(x)}

      point_pair?(x) ->
        split(x)
        |> case do
          {kind, p1, p2} ->
            {
              :point_pair,
              kind,
              {CGA2.point_coordinates(p1), CGA2.point_coordinates(p2)}
            }

          :invalid ->
            {:unknown, x}
        end

      true ->
        {:unknown, x}
    end
  end

  def line_parameters(l) do
    {
      CGA2.coefficient(l, :e12p),
      CGA2.coefficient(l, :e12m),
      CGA2.coefficient(l, :e1pm)
    }
  end

  def parse_number(n) when is_number(n), do: n

  def parse_number(str) do
    with :error <- Float.parse(str),
         :error <- Integer.parse(str) do
      :error
    else
      {num, ""} ->
        num

      _ ->
        :error
    end
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

  def handle_event(
        "move_point",
        %{"id" => p, "pos" => %{"x" => x, "y" => y}},
        socket
      ) do
    {:noreply,
     socket
     |> update(:points, fn ps ->
       np = CGA2.point(parse_number(x), parse_number(y))
       Map.replace(ps, p, np)
     end)}
  end

  def render(assigns) do
    c1 = CGA2.circle(assigns.points |> Map.get("p0"), 150)
    c2 = CGA2.circle(assigns.points |> Map.get("p2"), 100)
    c3 = CGA2.circle(assigns.points |> Map.get("p1"), 250)

    cc =
      CGA2.wedge(assigns.points |> Map.get("p4"), assigns.points |> Map.get("p5"))
      |> CGA2.wedge(assigns.points |> Map.get("p6"))

    assigns =
      assigns
      |> assign(:elements, [
        {"C1", :blue, c1},
        {"C2", :green, c2},
        {"C3", :hotpink, cc},
        {"C4", :orange, c3},
        {"P1", :green, assigns.points |> Map.get("p2")},
        {"P2", :orange, assigns.points |> Map.get("p1")},
        {"P3", :blue, assigns.points |> Map.get("p0")},
        {"P4", :purple, assigns.points |> Map.get("p4")},
        {"P5", :purple, assigns.points |> Map.get("p5")},
        {"P6", :purple, assigns.points |> Map.get("p6")},
        {"x", {:green, :orange}, CGA2.meet(c2, c3)},
        {"x", {:blue, :green}, CGA2.meet(c1, c2)},
        {"x", {:blue, :orange}, CGA2.meet(c1, c3)}
      ])

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
    <nav class="toolbar"></nav>

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
        <:head>
          CGA2
        </:head>
        <div class="segment">
          <div class="connection-status connected">Connected 🟢</div>
          <div class="connection-status disconnected">Reconnecting... 🔴</div>
        </div>
      </.menu>
    </div>
    <div style={"--auto-stroke: #{@pen}; --auto-fill: #{@pen}"}>
      <.canvas tools={false} grid={@grid} bounds={@bounds} box={@box}>
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
            stroke-width="4"
            shape-rendering="geometricPrecision"
            vector-effect="non-scaling-stroke"
            stroke="#333"
          />
          <line
            y1={@box.y + @box.height * 0.01}
            x1="0"
            y2={@box.y + @box.height * 0.98}
            x2="0"
            stroke-width="4"
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

        <g id="elements">
          <%= for {label, color, s} <-@elements do %>
            <%= classify(s) |> case do %>
              <% {:circle, {:circle, {{cx, cy}, r}}} -> %>
                <circle
                  cx={cx}
                  cy={-cy}
                  r={r}
                  fill="none"
                  stroke={color}
                  vector-effect="non-scaling-stroke"
                  stroke-width="3"
                />
                <text pointer-events="none" x={cx + r * 0.9} y={-cy}>{label}</text>
              <% {:point, {cx, cy}} -> %>
                <circle
                  cx={cx}
                  cy={-cy}
                  r="5"
                  fill={color}
                  data-non-scaling-full
                  stroke="none"
                  stroke-width="4"
                />
                <text pointer-events="none" x={cx + 10} y={-cy}>{label}</text>
              <% {:point_pair, :real, {{cx1, cy1}, {cx2, cy2}}} -> %>
                <% {col1, col2} =
                  case color do
                    {c1, c2} -> {c1, c2}
                    c -> {c, c}
                  end %>
                <circle
                  cx={cx1}
                  cy={-cy1}
                  r="6"
                  fill={col1}
                  stroke={col2}
                  data-non-scaling-full
                  stroke-width="5"
                />
                <circle
                  cx={cx2}
                  cy={-cy2}
                  r="6"
                  fill={col1}
                  stroke={col2}
                  data-non-scaling-full
                  stroke-width="5"
                />

                <text pointer-events="none" x={cx1 + 5} y={-cy1}>{label}/1</text>
                <text pointer-events="none" x={cx2 + 5} y={-cy2}>{label}/2</text>
              <% {:point_pair, :imag, {{cx1, cy1}, {cx2, cy2}}} -> %>
                <% {col1, col2} =
                  case color do
                    {c1, c2} -> {c1, c2}
                    c -> {c, c}
                  end %>
                <g>
                  <circle
                    cx={cx1}
                    cy={-cy1}
                    r="5"
                    stroke={col1}
                    data-non-scaling-full
                    fill="none"
                    stroke-dasharray="5 5"
                    stroke-width="5"
                  />
                  <circle
                    cx={cx1}
                    cy={-cy1}
                    r="5"
                    stroke={col2}
                    data-non-scaling-full
                    fill="none"
                    stroke-dasharray="5 5"
                    stroke-dashoffset="5"
                    stroke-width="5"
                  />
                </g>
                <g>
                  <circle
                    cx={cx2}
                    cy={-cy2}
                    r="5"
                    fill="none"
                    stroke-dasharray="5 5"
                    stroke={col1}
                    stroke-width="5"
                    data-non-scaling-full
                  />

                  <circle
                    cx={cx2}
                    cy={-cy2}
                    r="5"
                    fill="none"
                    stroke-dasharray="5 5"
                    stroke-dashoffset="5"
                    stroke={col2}
                    stroke-width="5"
                    data-non-scaling-full
                  />

                  <text pointer-events="none" x={cx1 + 5} y={-cy1}>{label}/1</text>
                  <text pointer-events="none" x={cx2 + 5} y={-cy2}>{label}/2</text>
                </g>
              <% _ -> %>
            <% end %>
          <% end %>
        </g>
        <%= for {id, s} <-@points do %>
          <%= classify(s) |> case do %>
            <% {:point, {cx, cy}} -> %>
              <circle
                cx={cx}
                cy={-cy}
                r={20}
                fill-opacity="0.2"
                fill="red"
                vector-effect="non-scaling-stroke"
                stroke-width="3"
                data-non-scaling
                id={id}
                phx-hook=".PointDragger"
              />
            <% _ -> %>
          <% end %>
        <% end %>
        <g id="layers"></g>
        <g id="layers-selection" multi-drag-root></g>
      </.canvas>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PointDragger">
      export default {
        mounted() {
          function throttle(fun, delay, fallback) {
            let lastTime = 0;
            return function (...args) {
              let now = Date.now();
              if (now - lastTime >= delay) {
                fun(...args);
                lastTime = now;
              } else if (fallback) {
                fallback(...args);
              }
            };
          }
          const move = throttle(
            (pos) => this.pushEvent("move_point", { id: this.el.id, pos }),
            30,
          );
          const svg = this.el.ownerSVGElement;
          const point = svg.createSVGPoint();

          const evtToSvg = (evt, rel, offset) => {
            point.x = evt.clientX;
            point.y = evt.clientY;
            const svgGlobal = point.matrixTransform(
              (rel || svg).getScreenCTM().inverse(),
            );
            return {
              x: svgGlobal.x - (offset?.x ?? 0),
              y: -(svgGlobal.y - (offset?.y ?? 0)),
            };
          };

          const offset = { x: 0, y: 0 };
          this.el.addEventListener("pointerdown", (evt) => {
            if (evt.isPrimary) {
              evt.preventDefault();
              evt.currentTarget.setPointerCapture(evt.pointerId);
              const pos = evtToSvg(evt);
              offset.x = pos.x - evt.currentTarget.getAttribute("cx");
              offset.y = -pos.y - evt.currentTarget.getAttribute("cy");
            }
          });
          this.el.addEventListener("pointermove", (evt) => {
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.preventDefault();
              move(evtToSvg(evt, null, offset));
            }
          });
        },
      };
    </script>
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
