defmodule GeomextricWeb.SceneLive do
  alias Galixir.Algebras.PGA3

  import GeomextricWeb.CoreComponents
  import GeomextricWeb.Canvas
  import GeomextricWeb.Circle
  import GeomextricWeb.Menu
  use Phoenix.LiveView
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
    camera_point = PGA3.transform(cam, p)
    {x, y, z} = PGA3.point_coordinates(camera_point)

    if z == 0 do
      nil
    else
      screen_x = x * 100 / z
      screen_y = -y * 100 / z
      {screen_x, screen_y, z}
    end
  end

  def parse_number(str) do
    with :error <- Float.parse(str),
         :error <- Integer.parse(str) do
      :error
    else
      {num, ""} ->
        num

      e ->
        :error
    end
  end

  def handle_event("reset", %{}, socket) do
    {:noreply,
     socket
     |> assign(:eye, {7, 5, 3})
     |> assign(:focus, {0, 0, 0})}
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
        }
        .screen {
        display: grid;
        position: absolute;
        inset: 0;
        }
        line {
      vector-effect: non-scaling-stroke;
      }

      line[stroke="black"] {
      marker-end: url("#vector-head");
      stroke-width: 1;
      }

      text {
      transform: translate(0, -5px);
      }
      .panel{
      z-index: 100;
      padding: 1em;
      }
      .controls{
      display: flex;
      flex-direction: row;
      gap: 1em;
      }
      .bar {
        grid-row: 1;
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
                    value: 1,
                    shortcut: [key: "e"]
                  },
                  %{
                    label: "+",
                    send: "movex",
                    value: -1,
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
                    value: 1,
                    shortcut: [key: "e", alt: true]
                  },
                  %{
                    label: "-",
                    send: "movey",
                    value: -1,
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
                    value: 1,
                    shortcut: [key: "w"]
                  },
                  %{
                    label: "-",
                    send: "movez",
                    value: -1,
                    shortcut: [key: "s"]
                  }
                ]
              }
            ]
          },
          %{
            label: "Turn",
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
          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
        </.menu>
        <div class="panel">
          <div class="controls">
            <fieldset>
              <legend>X</legend>
              <button phx-click="movex" value="-1">+</button>
              <button phx-click="movex" value="+1">-</button>
            </fieldset>
            <fieldset>
              <legend>Y</legend>
              <button phx-click="movey" value="+1">+</button>
              <button phx-click="movey" value="-1">-</button>
            </fieldset>
            <fieldset>
              <legend>Z</legend>
              <button phx-click="movez" value="-1">-</button>
              <button phx-click="movez" value="+1">+</button>
            </fieldset>
          </div>
        </div>
      </div>
      <svg
        class="scene"
        viewBox="-100 -100 200 200"
        width="100"
        height="50"
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
              <% %{pos: {{x1, y1}, {x2, y2}}, attrs: %{color: col}} -> %>
                <%= with {x1, y1, _z1} <- project(@camera, PGA3.point(x1 / 100, y1 / 100, 0)),
                 {x2, y2, _z2}  <- project(@camera, PGA3.point(x2 / 100, y2 / 100, 0)) do %>
                  <line
                    stroke_width={2}
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
        <%= for {color, ps}<- @faces, path =
                (for p <- ps  do
                  with({screen_x, screen_y, z} <- project(@camera, p), do:
                  "#{screen_x} #{screen_y}", else: (e ->  ""))
                end
                |> Enum.join(" ")) do %>
          <polygon
            points={path}
            fill={color}
          />
        <% end %>
        <%= for {color, {p1, p2}} <- @edges  do %>
          <%= with {{x1, y1, z1}, {x2,y2,z2}} <- {project(@camera, p1), project(@camera, p2)} do %>
            <line
              stroke={color}
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
            />
            <% else _ -> %>
          <% end %>
        <% end %>
        <%= for {color, p, l} <- @labels do %>
          <%= with {screen_x, screen_y, z} <- project(@camera, p)  do %>
            <text
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
    """
  end
end
