defmodule GeomextricWeb.SceneLive do
  alias Geomextric.Bodies
  alias Galixir.Algebras.PGA3
  use GeomextricWeb, :live_view

  import GeomextricWeb.Geometry
  import GeomextricWeb.Menu

  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:objects, %{
       "grid" => %{
         scale: 1,
         rotation: 0,
         geo: Bodies.gen_grid(true, false)
       },
       "axis" => %{
         scale: 1,
         rotation: 0,
         geo: Bodies.gen_axis()
       }
     })
     |> assign(:camera, %{
       yaw: 0.0,
       pitch: 0.3,
       radius: 10.0
     })
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

  def handle_event(
        "change_pos",
        %{"x" => x, "y" => y, "z" => z},
        socket
      ) do
    x = parse_number(x)
    y = parse_number(y)
    z = parse_number(z)

    {:noreply,
     socket
     |> assign(:xx, x)
     |> assign(:yy, y)
     |> assign(:zz, z)}
  end

  def handle_event(
        "change_obj",
        %{"rot" => rot, "objid" => obj_id, "scale" => new_scale},
        socket
      ) do
    new_rot = parse_number(rot)
    new_scale = parse_number(new_scale)

    {:noreply,
     socket
     |> update(:objects, &put_in(&1, [obj_id, :rotation], new_rot))
     |> update(:objects, &put_in(&1, [obj_id, :scale], new_scale))}
  end

  def handle_event("reset", %{}, socket) do
    {:noreply,
     socket
     |> assign(:camera, %{
       yaw: 0.0,
       pitch: 0.3,
       radius: 10.0
     })
     |> assign(:focus, {0, 0, 0})}
  end

  def handle_event("rotz", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :camera,
       fn c = %{yaw: y} ->
         %{c | yaw: y + v}
       end
     )}
  end

  def handle_event("rot", %{"v" => v, "h" => h}, socket) do
    dp = parse_number(v) * 0.5
    dy = parse_number(h) * 0.5

    {:noreply,
     update(socket, :camera, fn %{pitch: pitch, yaw: yaw} = c ->
       %{
         c
         | pitch: clamp(pitch + dp, -:math.pi() / 2.01, :math.pi() / 2.01),
           yaw: yaw + dy
       }
     end)}
  end

  defp clamp(x, min, max), do: max(min, min(max, x))

  def handle_event("zoom", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :camera,
       fn c = %{radius: r} -> %{c | radius: clamp(r + v, 1, 100)} end
     )}
  end

  def handle_event("movex", %{"value" => v}, socket) do
    v = parse_number(v) * 0.1

    {:noreply,
     socket
     |> update(
       :camera,
       fn c = %{pitch: p} -> %{c | pitch: clamp(p + v, -:math.pi() / 2.01, :math.pi() / 2.01)} end
     )}
  end

  def handle_event("movey", %{"value" => v}, socket) do
    v = parse_number(v) * 0.1

    {:noreply,
     socket
     |> update(
       :camera,
       fn c = %{yaw: y} -> %{c | yaw: y - v} end
     )}
  end

  def handle_event("movez", %{"value" => v}, socket) do
    v = parse_number(v)

    {:noreply,
     socket
     |> update(
       :camera,
       fn c = %{radius: r} -> %{c | radius: clamp(r - v, 1, 100)} end
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

  def eye_from_camera(%{yaw: yaw, pitch: pitch, radius: r}) do
    {
      r * :math.cos(pitch) * :math.cos(yaw),
      r * :math.cos(pitch) * :math.sin(yaw),
      r * :math.sin(pitch)
    }
  end

  def render(assigns) do
    {eye_x, eye_y, eye_z} = eye_from_camera(assigns.camera)
    {fx, fy, fz} = assigns.focus
    eye = PGA3.point(eye_x, eye_y, eye_z)
    target = PGA3.point(fx, fy, fz)
    pole = PGA3.ideal_point(0, 0, 1)

    assigns = assign(assigns, :camera, look_at(eye, target, pole))

    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
        .scene{
        background: #fff;
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

      .text-label {
        transform: translate(0, -2px);
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

            <%= for {objid, %{rotation: rot, scale: scl, editable: true}} <- @objects do %>
              <form phx-change="change_obj">
                <input type="hidden" name="objid" value={objid} />
                <fieldset>
                  <legend>{objid}</legend>
                  <label><input
                    phx-throttle="16"
                    name="rot"
                    type="range"
                    min="-100"
                    max="100"
                    value={rot}
                  /></label>
                  <label><input
                    phx-throttle="16"
                    name="scale"
                    type="range"
                    min="0.1"
                    max="4"
                    step="0.1"
                    value={scl}
                  /></label>
                </fieldset>
              </form>
            <% end %>
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
        <%= for {objid, %{geo: geo, rotation: rotation, scale: scale}} <- @objects do %>
          <.geometry camera={@camera} id={objid} geo={geo} rotation={rotation} scale={scale} />
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
          const rot = throttle(
            (h, v) => this.pushEvent("rot", { v: "" + v, h: "" + h }),
            30,
          );
          const zoom = throttle((r) => this.pushEvent("zoom", { value: "" + r }), 30);
          this.el.addEventListener("wheel", (evt) => {
            evt.preventDefault();
            zoom((evt.deltaY / window.screen.height) * 10);
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

              rot(
                (evt.movementX / window.screen.width) * 20,
                (evt.movementY / window.screen.height) * 20,
              );
            }
          });
        },
      };
    </script>
    """
  end
end
