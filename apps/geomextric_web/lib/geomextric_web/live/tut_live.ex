defmodule GeomextricWeb.TutLive do
  alias Galixir.Algebras.PGA3
  use GeomextricWeb, :live_view

  import GeomextricWeb.Geometry
  import GeomextricWeb.Menu

  def mount(%{}, _, socket) do
    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(:y, 1)
     |> assign(:show_ellipse, false)
     |> assign(:z, 2)
     |> assign(:x, 3)
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
        "change_bivector",
        %{"xx" => xx, "yy" => yy, "zz" => zz, "ellipse" => e},
        socket
      ) do
    xx = parse_number(xx)
    yy = parse_number(yy)
    zz = parse_number(zz)

    {:noreply,
     socket
     |> assign(:xx, xx)
     |> assign(:show_ellipse, e == "1")
     |> assign(:yy, yy)
     |> assign(:zz, zz)}
  end

  def handle_event(
        "change_vector",
        %{"x" => x, "y" => y, "z" => z},
        socket
      ) do
    x = parse_number(x)
    y = parse_number(y)
    z = parse_number(z)

    {:noreply,
     socket
     |> assign(:x, x)
     |> assign(:y, y)
     |> assign(:z, z)}
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
        gap: 0.25ex;
        padding: 0.5ex;
        background: #aaa;
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
          <:head>
            <.link navigate={~p"/playground"}>
              Playground
            </.link>
          </:head>
          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
        </.menu>
        <div class="toolbar">
          <div class="controls">
            <form phx-change="change_vector">
              <fieldset>
                <legend>Vector</legend>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="x"
                  style="accent-color:red"
                  type="range"
                  min="-5"
                  max="5"
                  value={@x}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="y"
                  style="accent-color:green"
                  type="range"
                  min="-5"
                  max="5"
                  value={@y}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="z"
                  style="accent-color:blue"
                  type="range"
                  min="-5"
                  max="5"
                  value={@z}
                /></label>
              </fieldset>
            </form>
            <form phx-change="change_bivector">
              <fieldset>
                <legend>Bivector</legend>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="xx"
                  style="accent-color:red"
                  type="range"
                  min="-5"
                  max="5"
                  value={@xx}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="yy"
                  style="accent-color:green"
                  type="range"
                  min="-5"
                  max="5"
                  value={@yy}
                /></label>
                <label><input
                  phx-throttle="16"
                  step="0.1"
                  name="zz"
                  style="accent-color:blue"
                  type="range"
                  min="-5"
                  max="5"
                  value={@zz}
                /></label>
                <input
                  phx-throttle="16"
                  name="ellipse"
                  type="hidden"
                  value="0"
                />
                <label><input
                  phx-throttle="16"
                  name="ellipse"
                  type="checkbox"
                  checked={@show_ellipse}
                  value="1"
                /> Show as ellipse</label>
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
            labels={false}
            id="axis"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            labels={false}
            id="coord-grid"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <g class="vectors">
            <.geometry
              labels={false}
              id="vector"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@x, @y, @z, name: "v")}
            />
            <.geometry
              labels={false}
              id="vector-x"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@x, 0, 0, color: "#c00", name: "v_x")}
            />
            <.geometry
              labels={false}
              id="vector-y"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, @y, 0, color: "#0c0", name: "v_y")}
            />
            <.geometry
              labels={false}
              id="vector-z"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, 0, @z, color: "blue", name: "v_z")}
            />
          </g>
          <.geometry
            labels={true}
            faces={false}
            edges={false}
            id="axis-label"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            labels={true}
            faces={false}
            edges={false}
            id="coord-grid-label"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <g class="vectors">
            <.geometry
              labels={true}
              faces={false}
              edges={false}
              id="vector-label"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@x, @y, @z, name: "v")}
            />
            <.geometry
              labels={true}
              faces={false}
              edges={false}
              id="vector-x-label"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(@x, 0, 0, color: "#c00", name: "v_x")}
            />
            <.geometry
              labels={true}
              faces={false}
              edges={false}
              id="vector-y-label"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, @y, 0, color: "#0c0", name: "v_y")}
            />
            <.geometry
              labels={true}
              faces={false}
              edges={false}
              id="vector-z-label"
              camera={@camera}
              geo={Geomextric.Bodies.gen_vector(0, 0, @z, color: "blue", name: "v_z")}
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
            labels={false}
            id="axis-2"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            labels={false}
            id="coord-grid-2"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <g class="vectors">
            <.geometry
              labels={false}
              quad_ellipse={@show_ellipse}
              edges={not @show_ellipse}
              id="vector-2"
              camera={@camera}
              geo={
                Geomextric.Bodies.gen_bivector(@xx, @yy, @zz,
                  name: "bv",
                  stroke: "#000",
                  fill: "#0003",
                  text: "black",
                  offset: %{x: -1, y: 1, z: 1}
                )
              }
            />
            <.geometry
              labels={false}
              quad_ellipse={@show_ellipse}
              edges={not @show_ellipse}
              id="vector-x-2"
              camera={@camera}
              geo={
                Geomextric.Bodies.gen_bivector(@xx, 0, 0,
                  fill: "#c005",
                  stroke: "#c00",
                  text: "#c00",
                  name: "bv_yz",
                  offset: %{x: 0, y: 1, z: 1}
                )
              }
            />
            <.geometry
              labels={false}
              quad_ellipse={@show_ellipse}
              edges={not @show_ellipse}
              id="vector-y-2"
              camera={@camera}
              geo={
                Geomextric.Bodies.gen_bivector(0, @yy, 0,
                  stroke: "#0c0",
                  fill: "#0c05",
                  text: "#0c0",
                  name: "bv_xz",
                  offset: %{x: -1, y: 0, z: 1}
                )
              }
            />
            <.geometry
              labels={false}
              quad_ellipse={@show_ellipse}
              edges={not @show_ellipse}
              id="vector-z-2"
              camera={@camera}
              geo={
                Geomextric.Bodies.gen_bivector(0, 0, @zz,
                  fill: "#00c5",
                  stroke: "#00c",
                  text: "blue",
                  name: "bv_yx",
                  offset: %{x: -1, y: 1, z: 0}
                )
              }
            />
          </g>
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="axis-2-label"
            camera={@camera}
            geo={Geomextric.Bodies.gen_axis()}
          />
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="coord-grid-2-labels"
            camera={@camera}
            geo={Geomextric.Bodies.gen_grid(true, false)}
          />
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="vector-2-labels"
            camera={@camera}
            geo={
              Geomextric.Bodies.gen_bivector(@xx, @yy, @zz,
                name: "bv",
                stroke: "#000c",
                fill: "#0003",
                text: "black",
                offset: %{x: -1, y: 1, z: 1}
              )
            }
          />
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="vector-x-2-labels"
            camera={@camera}
            geo={
              Geomextric.Bodies.gen_bivector(@xx, 0, 0,
                fill: "#c005",
                stroke: "#c00c",
                text: "#c00",
                name: "bv_yz",
                offset: %{x: 0, y: 1, z: 1}
              )
            }
          />
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="vector-y-2-labels"
            camera={@camera}
            geo={
              Geomextric.Bodies.gen_bivector(0, @yy, 0,
                stroke: "#0c0a",
                fill: "#0c05",
                text: "#0c0",
                name: "bv_xz",
                offset: %{x: -1, y: 0, z: 1}
              )
            }
          />
          <.geometry
            labels={true}
            edges={false}
            faces={false}
            id="vector-z-2-labels"
            camera={@camera}
            geo={
              Geomextric.Bodies.gen_bivector(0, 0, @zz,
                fill: "#00c5",
                stroke: "#00ca",
                text: "#00c",
                name: "bv_yx",
                offset: %{x: -1, y: 1, z: 0}
              )
            }
          />
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
            100,
          );
          const zoom = throttle((r) => this.pushEvent("zoom", { value: "" + r }), 30);
          this.el.addEventListener("wheel", (evt) => {
            evt.preventDefault();
            zoom((evt.deltaY / window.screen.height) * 2);
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
