defmodule GeomextricWeb.SceneLive do
  alias Galixir.Algebras.PGA3
  use GeomextricWeb, :live_view

  import GeomextricWeb.Menu

  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    pyramid_tip = PGA3.point(0, 0, 3)

    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:points, [
       {"rebeccapurple", pyramid_tip},
       {"tomato", PGA3.point(1, 1, 1)},
       {"tomato", PGA3.point(1, -1, 1)},
       {"tomato", PGA3.point(-1, -1, 1)},
       {"tomato", PGA3.point(-1, 1, 1)},
       {"yellowgreen", PGA3.point(1, 0, 1)},
       {"yellowgreen", PGA3.point(-1, 0, 1)},
       {"yellowgreen", PGA3.point(0, -1, 1)},
       {"yellowgreen", PGA3.point(0, 1, 1)},
       {"teal", PGA3.point(1, 1, 0)},
       {"teal", PGA3.point(1, -1, 0)},
       {"teal", PGA3.point(-1, -1, 0)},
       {"teal", PGA3.point(-1, 1, 0)}
     ])
     |> assign(:edges, [
       {"royalblue", {PGA3.point(1, 1, 1), pyramid_tip}},
       {"royalblue", {PGA3.point(-1, 1, 1), pyramid_tip}},
       {"royalblue", {PGA3.point(-1, -1, 1), pyramid_tip}},
       {"royalblue", {PGA3.point(1, -1, 1), pyramid_tip}},
       {"royalblue", {PGA3.point(1, 1, 1), PGA3.point(-1, 1, 1)}},
       {"royalblue", {PGA3.point(1, -1, 1), PGA3.point(-1, -1, 1)}},
       {"royalblue", {PGA3.point(-1, 1, 1), PGA3.point(-1, -1, 1)}},
       {"royalblue", {PGA3.point(1, 1, 1), PGA3.point(1, -1, 1)}},
       {"teal", {PGA3.point(1, 1, 0), PGA3.point(-1, 1, 0)}},
       {"teal", {PGA3.point(1, -1, 0), PGA3.point(-1, -1, 0)}},
       {"teal", {PGA3.point(-1, 1, 0), PGA3.point(-1, -1, 0)}},
       {"teal", {PGA3.point(1, 1, 0), PGA3.point(1, -1, 0)}},
       {"black", {PGA3.point(-5, 0, 0), PGA3.point(5, 0, 0)}},
       {"black", {PGA3.point(0, -5, 0), PGA3.point(0, 5, 0)}},
       {"black", {PGA3.point(0, 0, -3), PGA3.point(0, 0, 4)}}
     ])
     |> assign(:faces, [
       {"#4444",
        [
          PGA3.point(1, 1, 0),
          PGA3.point(-1, 1, 0),
          PGA3.point(-1, -1, 0),
          PGA3.point(1, -1, 0)
        ]},
       {"#5554",
        [
          PGA3.point(1, 1, 1),
          PGA3.point(-1, 1, 1),
          PGA3.point(-1, -1, 1),
          PGA3.point(1, -1, 1)
        ]},
       {"#0504",
        [
          PGA3.point(1, 1, 1),
          PGA3.point(1, -1, 1),
          pyramid_tip
        ]},
       {"#5504",
        [
          PGA3.point(-1, 1, 1),
          PGA3.point(-1, -1, 1),
          pyramid_tip
        ]},
       {"#0554",
        [
          PGA3.point(-1, -1, 1),
          PGA3.point(1, -1, 1),
          pyramid_tip
        ]},
       {"#5054",
        [
          PGA3.point(1, 1, 1),
          PGA3.point(-1, 1, 1),
          pyramid_tip
        ]}
     ])
     |> assign(:labels, [
       {"black", PGA3.point(5, 0, 0), "X"},
       {"black", PGA3.point(0, 5, 0), "Y"},
       {"black", PGA3.point(0, 0, 4), "Z"}
     ])
     |> assign(:eye, {7, 5, 3})
     |> assign(:focus, {0, 0, 0})}
  end

  def handle_info(_, socket) do
    {:noreply,
     socket
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def align(ps, qs) do
    import PGA3
    # https://observablehq.com/@enkimute/glu-lookat-in-3d-pga
    initial_m = one = PGA3.new(scalar: 1)
    initial_q = PGA3.dual(PGA3.new(scalar: 1))

    Enum.zip_reduce(ps, qs, {initial_m, initial_q}, fn p, q, {m, prev_q} ->
      p = prev_q |> PGA3.join(PGA3.transform(m, p)) |> normalize()
      new_q = prev_q |> PGA3.join(q) |> normalize() |> PGA3.blade_inverse()
      new_m = new_q |> PGA3.gp(p) |> add(one) |> PGA3.gp(m)

      {new_m, new_q}
    end)
    |> elem(0)
  end

  def look_at(
        position \\ PGA3.point(0, 10, 0),
        target \\ PGA3.point(0, 0, 0),
        pole \\ PGA3.ideal_point(0, 0, 1)
      ) do
    import PGA3

    align(
      [position, target, pole],
      [point(0, 0, 0), point(0, 0, 1), ideal_point(0, 1, 0)]
    )
  end

  def project(cam, p) do
    if PGA3.zero?(cam) do
      nil
    else
      camera_point =
        PGA3.transform(cam, p)

      {x, y, z} = PGA3.point_coordinates(camera_point)

      if z < 0 do
        nil
      else
        screen_x = x * 100 / z
        screen_y = -y * 100 / z
        {screen_x, screen_y, z}
      end
    end
  end

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

  def handle_event("reset", %{}, socket) do
    {:noreply,
     socket
     |> assign(:eye, {7, 5, 3})
     |> assign(:focus, {0, 0, 0})}
  end

  def handle_event("rotz", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} ->
         len = :math.sqrt(x * x + y * y)
         new_x = x - y * v
         new_y = y + x * v

         new_len = :math.sqrt(new_x * new_x + new_y * new_y)
         {(x - y * v) * len / new_len, (y + x * v) * len / new_len, z}
       end
     )}
  end

  def handle_event("zoom", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} ->
         factor = :math.exp(v)

         new_dist = :math.sqrt(x * x + y * y + z * z) * factor

         if new_dist > 1 and new_dist < 100 do
           {x * factor, y * factor, z * factor}
         else
           {x, y, z}
         end
       end
     )}
  end

  def handle_event("movex", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} -> {x + v, y, z} end
     )}
  end

  def handle_event("movey", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} -> {x, y + v, z} end
     )}
  end

  def handle_event("movez", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} -> {x, y, z + v} end
     )}
  end

  def handle_event("turnx", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :focus,
       fn {x, y, z} -> {x + v, y, z} end
     )}
  end

  def handle_event("turny", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :focus,
       fn {x, y, z} -> {x, y + v, z} end
     )}
  end

  def handle_event("turnz", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :focus,
       fn {x, y, z} -> {x, y, z + v} end
     )}
  end

  def render(assigns) do
    {eye_x, eye_y, eye_z} = assigns.eye
    {fx, fy, fz} = assigns.focus
    eye = PGA3.point(eye_x, eye_y, eye_z)
    target = PGA3.point(fx, fy, fz)
    pole = PGA3.ideal_point(0, 0, 1)

    assigns = assign(assigns, :camera, look_at(eye, target, pole))

    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
        .scene{
        inset: 0;
        width: 100%;
        height: 100%;
        display: block;
        grid-area: 1 / 1 / -1 / -1;
        touch-action: none;
        }
        .screen {
        display: grid;
        position: absolute;
        inset: 0;
        }
        .line3d {
      vector-effect: non-scaling-stroke;
      stroke-linecap: round;
      stroke-linecap: round;
      }

      line[stroke="black"] {
      marker-end: url("#vector-head");
      stroke-width: 1;
      }

      text {
      transform: translate(0, -5px);
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
            legend {
            color: #000;
            padding: 0;
            font-size: 0.7em;
            text-align: center;
            border-bottom: 1px solid #000;
            margin-bottom: 2px;
            width: 100%;
            position: relative;
            margin-top: -0.5em;
            }
      .controls{
      display: flex;
      flex-direction: row;
      gap: 1em;
      }
      .bar {
        grid-row: 1;
        align-self: start;
        grid-column: 1 / -1;
        z-index: 100;
      }
    </style>
    <div class="screen">
      <div class="bar">
        <.menu items={[
          %{
            label: "Move",
            items: [
              %{
                label: "Reset",
                send: "reset",
                shortcut: [key: "Escape"]
              },
              %{
                label: "X",
                items: [
                  %{
                    label: "-",
                    send: "movex",
                    value: 0.9,
                    shortcut: [key: "e"]
                  },
                  %{
                    label: "+",
                    send: "movex",
                    value: -0.9,
                    shortcut: [key: "q"]
                  }
                ]
              },
              %{
                label: "Y",
                items: [
                  %{
                    label: "+",
                    send: "movey",
                    value: 0.9,
                    shortcut: [key: "e", alt: true]
                  },
                  %{
                    label: "-",
                    send: "movey",
                    value: -0.9,
                    shortcut: [key: "q", alt: true]
                  }
                ]
              },
              %{
                label: "Z",
                items: [
                  %{
                    label: "+",
                    send: "movez",
                    value: 0.9,
                    shortcut: [key: "w"]
                  },
                  %{
                    label: "-",
                    send: "movez",
                    value: -0.9,
                    shortcut: [key: "s"]
                  }
                ]
              }
            ]
          },
          %{
            label: "Spin",
            items: [
              %{
                label: "Left",
                send: "rotz",
                value: -0.1,
                shortcut: [key: "Q", shift: true]
              },
              %{
                label: "Right",
                send: "rotz",
                value: 0.1,
                shortcut: [key: "E", shift: true]
              }
            ]
          },
          %{
            label: "Turn",
            items: [
              %{
                label: "X",
                items: [
                  %{
                    label: "-",
                    send: "turnx",
                    value: 0.2,
                    shortcut: [key: "ArrowRight"]
                  },
                  %{
                    label: "+",
                    send: "turnx",
                    value: -0.2,
                    shortcut: [key: "ArrowLeft"]
                  }
                ]
              },
              %{
                label: "Y",
                items: [
                  %{
                    label: "+",
                    send: "turny",
                    value: 0.2,
                    shortcut: [key: "ArrowLeft", alt: true]
                  },
                  %{
                    label: "-",
                    send: "turny",
                    value: -0.2,
                    shortcut: [key: "ArrowRight", alt: true]
                  }
                ]
              },
              %{
                label: "Z",
                items: [
                  %{
                    label: "+",
                    send: "turnz",
                    value: 0.2,
                    shortcut: [key: "ArrowUp"]
                  },
                  %{
                    label: "-",
                    send: "turnz",
                    value: -0.2,
                    shortcut: [key: "ArrowDown"]
                  }
                ]
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
            <.link navigate={~p"/canvas"}>
              2D
            </.link>
          </:head>
          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
        </.menu>
        <div class="toolbar">
          <div class="controls">
            <fieldset>
              <legend>X</legend>
              <button phx-click="movex" value="-0.9">+</button>
              <button phx-click="movex" value="+0.9">-</button>
            </fieldset>
            <fieldset>
              <legend>Y</legend>
              <button phx-click="movey" value="+0.9">+</button>
              <button phx-click="movey" value="-0.9">-</button>
            </fieldset>
            <fieldset>
              <legend>Z</legend>
              <button phx-click="movez" value="-0.9">-</button>
              <button phx-click="movez" value="+0.9">+</button>
            </fieldset>
          </div>
        </div>
      </div>
      <svg
        class="scene"
        viewBox="-100 -100 200 200"
        width="100"
        height="50"
        phx-hook=".Orb"
        id="scene"
        preserveAspectRatio="xMidYMid slice"
      >
        <g id="layers">
          <%= for %{id: id} = l <- @layers |> Enum.reverse() do %>
            <%= case l do %>
              <% %{pos: {x, y}, attrs: %{color: col, radius: r}} -> %>
                <%= with {x, y, z} <- project(@camera, PGA3.point(x / 100, y / 100, 0)) do %>
                  <circle
                    id={"#{id}"}
                    cx={x}
                    cy={y}
                    r={r / z}
                    fill={col}
                  />
                  <% else _ -> %>
                <% end %>
              <% %{pos: {x, y, w, h}, attrs: %{color: col, radius: r}} -> %>
                <%= with {x1, y1, _z1} <- project(@camera, PGA3.point(x / 100, y / 100, 0)),
               {x2, y2, _z2} <- project(@camera, PGA3.point((x + w) / 100, y / 100, 0)),
               {x3, y3, _z3} <- project(@camera, PGA3.point((x + w) / 100, (y + h) / 100, 0)),
               {x4, y4, _z4} <- project(@camera, PGA3.point(x / 100, (y + h) / 100, 0))
                 do %>
                  <polygon
                    fill={col}
                    rx={r}
                    ry={r}
                    points={"#{x1} #{y1} #{x2} #{y2} #{x3} #{y3} #{x4} #{y4}"}
                  />
                  <% else _ -> %>
                <% end %>
              <% %{pos: {{x1, y1}, {x2, y2}}, attrs: %{color: col, thickness: t}} -> %>
                <%= with {x1, y1, z1} <- project(@camera, PGA3.point(x1 / 100, y1 / 100, 0)),
                 {x2, y2, z2}  <- project(@camera, PGA3.point(x2 / 100, y2 / 100, 0)) do %>
                  <line
                    class="line3d"
                    stroke-width={t / :math.sqrt(z1 + z2)}
                    x1={x1}
                    y1={y1}
                    x2={x2}
                    y2={y2}
                    stroke={col}
                  />
                  <% else _ -> %>
                <% end %>
            <% end %>
          <% end %>
        </g>

        <%= for {color, ps}<- @faces, path =
                (for p <- ps  do
                  with({screen_x, screen_y, _z} <- project(@camera, p), do:
                  "#{screen_x} #{screen_y}", else: (_e ->  ""))
                end
                |> Enum.join(" ")) do %>
          <polygon
            points={path}
            fill={color}
          />
        <% end %>

        <%= for {color, {p1, p2}} <- @edges  do %>
          <%= with {{x1, y1, _z1}, {x2,y2,_z2}} <- {project(@camera, p1), project(@camera, p2)} do %>
            <line
              class="line3d"
              stroke={color}
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
            />
            <% else _ -> %>
          <% end %>
        <% end %>
        <%= for {color, p} <- @points do %>
          <%= with {screen_x, screen_y, z} <- project(@camera, p) do %>
            <circle
              fill={color}
              r={10 / abs(z)}
              cx={screen_x}
              cy={screen_y}
            />
            <% else _ -> %>
          <% end %>
        <% end %>
        <%= for {color, p, l} <- @labels do %>
          <%= with {screen_x, screen_y, z} <- project(@camera, p)  do %>
            <text
              font-size={24 / z}
              fill={color}
              x={screen_x}
              y={screen_y}
              font-size={6}
            >
              {l}
            </text>
            <% else _ -> %>
          <% end %>
        <% end %>
        <defs>
          <marker
            id="vector-head"
            viewBox="0 0 10 10"
            refX="9"
            refY="5"
            markerWidth="10"
            markerHeight="10"
            fill="context-stroke"
            orient="auto-start-reverse"
          >
            <path d="M 10 5 l -10 5 l 3 -5 l -3 -5 z" />
          </marker>
        </defs>
      </svg>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Orb">
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

      export default {
        mounted() {
          const rot = throttle((r) => this.pushEvent("rotz", { value: "" + r }), 30);
          const zoom = throttle((r) => this.pushEvent("zoom", { value: "" + r }), 30);
          this.el.addEventListener("wheel", (evt) => {
            evt.preventDefault();
            zoom(evt.deltaY / 600);
          });
          this.el.addEventListener("pointerdown", (evt) => {
            console.log(evt.isPrimary);
            if (evt.isPrimary) {
              evt.preventDefault();
              evt.currentTarget.setPointerCapture(evt.pointerId);
            }
          });
          this.el.addEventListener("pointermove", (evt) => {
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.preventDefault();

              rot(evt.movementX / 200);
            }
          });
        },
      };
    </script>
    """
  end
end
