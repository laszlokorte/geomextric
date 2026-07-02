defmodule GeomextricWeb.HomeLive do
  use Phoenix.LiveView
  @topic "circle"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:x, 150)
     |> assign(:y, 0)}
  end

  def handle_event("move", %{"x" => x, "y" => y}, socket) do
    GeomextricWeb.Endpoint.broadcast(@topic, "move", {x, y})

    {:noreply,
     socket
     |> assign(:x, x)
     |> assign(:y, y)}
  end

  def handle_info(%{event: "move", payload: {x, y}}, socket) do
    {:noreply,
     socket
     |> assign(:x, x)
     |> assign(:y, y)}
  end

  def render(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedScopedCSS}>
      svg:scope {
        position: absolute;
        inset: 0;
        background: #ffddff;
        display: block;
        width: 100%;
        height: 100%;
      }
    </style>
    <svg
      viewBox={"#{min(-500, @x)} #{min(-500, @y)} #{500 + max(500, abs(@x))} #{500 + max(500, abs(@y))}"}
      id="my-camera"
      phx-hook=".Camera"
    >
      <rect
        x={min(-500, @x)}
        y={min(-500, @y)}
        width={500 + max(500, abs(@x))}
        height={500 + max(500, abs(@y))}
        fill="#0001"
      />
      <circle id="my-circle" phx-hook=".Circle" cx={@x} cy={@y} r="100" fill="rebeccapurple"></circle>
    </svg>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Camera">
        const cam = {
          zoom: 0,
          viewBox: {
            x: 0,
            y: 0,
            width: 0,
            height: 0
          }
        }
        function updateViewBox(e, c) {
          e.setAttribute("viewBox", `${c.viewBox.x * Math.exp(c.zoom)} ${c.viewBox.y * Math.exp(c.zoom)}
      ${c.viewBox.width * Math.exp(c.zoom)} ${c.viewBox.height * Math.exp(c.zoom)}
            `)
        }
        export default {
          mounted(){

            const [x,y,w,h] = this.el.getAttribute("viewBox").split(" ").map((v) => parseInt(v, 10))
            cam.viewBox = {x, y, width: w, height: h}
            this.el.addEventListener('wheel', (evt) => {
              evt.preventDefault()
              cam.zoom += evt.deltaY/1000
              updateViewBox(this.el, cam)
            })
          },
          updated()  {
            updateViewBox(this.el, cam)
          }
        }
    </script>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Circle">
      function throttle(fun, delay, fallback) {
          let lastTime = 0;
          return function (...args) {
              let now = Date.now();
              if (now - lastTime >= delay) {
                  fun(...args);
                  lastTime = now;
              } else if (fallback) {
                fallback(...args)
              }
          };
      }
      const debounce = (callback, wait) => {
        let timeoutId = null;
        return (...args) => {
          window.clearTimeout(timeoutId);
          timeoutId = window.setTimeout(() => {
            callback(...args);
          }, wait);
        };
      }
      export default {
        mounted(){
          const move = throttle(
            (x,y) => this.pushEvent("move", {x,y}), 60,
            debounce((x,y) => this.pushEvent("move", {x,y}), 500)
          )

          const svg = this.el.ownerSVGElement;
          const point = svg.createSVGPoint();

          const evtToSvg = (evt) => {
             point.x = evt.clientX;
             point.y = evt.clientY;
             const svgGlobal = point.matrixTransform(svg.getScreenCTM().inverse());
             return {
               x: svgGlobal.x,
               y: svgGlobal.y,
             }
          }
          const offset = {x:0,y:0}
          this.el.addEventListener('pointerdown', (evt) => {
            if(evt.isPrimary) {
              evt.currentTarget.setPointerCapture(evt.pointerId)

              const {x,y} = evtToSvg(evt)
              offset.x = x - this.el.getAttribute("cx");
              offset.y = y - this.el.getAttribute("cy");
            }
          });
          this.el.addEventListener('pointermove', (evt) => {
            if(evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              const {x: px,y: py} = evtToSvg(evt);

              const x = px - offset.x
              const y = py - offset.y
              move(x,y)

              this.el.setAttribute('cx', x);
              this.el.setAttribute('cy', y );
            }
          });
        }
      }
    </script>
    """
  end
end
