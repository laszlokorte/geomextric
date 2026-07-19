defmodule GeomextricWeb.TutLive do
  alias Geomextric.Bodies
  alias Galixir.Algebras.PGA3
  use GeomextricWeb, :live_view

  import GeomextricWeb.Geometry
  import GeomextricWeb.Menu

  def mount(%{}, _, socket) do
    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(:yy, 1)
     |> assign(:zz, 2)
     |> assign(:xx, 3)
     |> assign(:eye, {7, 5, 3})
     |> assign(:focus, {0, 0, 0})}
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

  def handle_event("rot", %{"v" => v, "h" => h}, socket) do
    v = parse_number(v) * 5
    h = parse_number(h)

    {:noreply,
     socket
     |> update(
       :eye,
       fn {x, y, z} ->
         len = :math.sqrt(x * x + y * y)
         new_x = x - y * h
         new_y = y + x * h

         new_len = :math.sqrt(new_x * new_x + new_y * new_y)
         {(x - y * h) * len / new_len, (y + x * h) * len / new_len, z + v}
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
      .vectors .line3d {
        marker-end: url("#vector-head");
        stroke-width: 2;
        }

        .scenes{
        background: #fff;
        width: 100%;
        height: 100%;
        display: block;
        grid-area: 1 / 1 / -1 / -1;
        touch-action: none;
        display: grid;
        grid-auto-columns: 1fr;
        align-items: stretch;
        grid-auto-flow: column;
        gap: 0.5ex;
        padding: 0.5ex;
        background: black;
        }
        .scene-sub{
              background: #fff;
              inset: 0;
              width: 100%;
              height: 100%;
              display: block;
              touch-action: none;
              display: grid;
              grid-auto-columns: 1fr;
              align-items: stretch;
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
          }
        ]}>
          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
        </.menu>
        <div class="toolbar">
          <div class="controls">
            <form phx-change="change_pos">
              <fieldset>
                <legend>Trace</legend>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="x"
                  type="range"
                  min="-5"
                  max="5"
                  value={@xx}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="y"
                  type="range"
                  min="-5"
                  max="5"
                  value={@yy}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="z"
                  type="range"
                  min="-5"
                  max="5"
                  value={@zz}
                /></label>
              </fieldset>
            </form>
          </div>
        </div>
      </div>
      <div class="scenes">
        <svg
          class="scene-sub"
          viewBox="-100 -100 200 200"
          width="100"
          height="50"
          phx-hook=".Orb"
          id="scene"
          preserveAspectRatio="xMidYMid slice"
        >
          <.geometry
            id="axis"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            id="coord-grid"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <g class="vectors">
            <.geometry
              id="vector"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@xx, @yy, @zz, name: "v")}
            />
            <.geometry
              id="vector-x"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@xx, 0, 0, color: "red", name: "v_x")}
            />
            <.geometry
              id="vector-y"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, @yy, 0, color: "green", name: "v_y")}
            />
            <.geometry
              id="vector-z"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, 0, @zz, color: "blue", name: "v_z")}
            />
          </g>
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
        <svg
          class="scene-sub"
          viewBox="-100 -100 200 200"
          width="100"
          height="50"
          phx-hook=".Orb"
          id="scene-2"
          preserveAspectRatio="xMidYMid slice"
        >
          <.geometry
            id="axis-2"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            id="coord-grid-2"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <g class="vectors">
            <.geometry
              id="vector-2"
              camera={@camera}
              geo={Geomextric.Bodies.gen_bivector(@xx, @yy, @zz, name: "v")}
            />
            <.geometry
              id="vector-x-2"
              camera={@camera}
              geo={Geomextric.Bodies.gen_bivector(@xx, 0, 0, color: "red", name: "v_x")}
            />
            <.geometry
              id="vector-y-2"
              camera={@camera}
              geo={Geomextric.Bodies.gen_bivector(0, @yy, 0, color: "green", name: "v_y")}
            />
            <.geometry
              id="vector-z-2"
              camera={@camera}
              geo={Geomextric.Bodies.gen_bivector(0, 0, @zz, color: "blue", name: "v_z")}
            />
          </g>
        </svg>
      </div>
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
