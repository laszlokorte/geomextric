defmodule GeomextricWeb.HomeLive do
  use Phoenix.LiveView
  @topic "circle"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:dots, [])
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

  def handle_event("create", %{"x" => x, "y" => y}, socket) do
    GeomextricWeb.Endpoint.broadcast(@topic, "created", {x, y})

    {:noreply, socket}
  end

  def handle_info(%{event: "move", payload: {x, y}}, socket) do
    {:noreply,
     socket
     |> assign(:x, x)
     |> assign(:y, y)}
  end

  def handle_info(%{event: "created", payload: {x, y}}, socket) do
    {:noreply,
     socket
     |> update(:dots, &[{x, y} | &1])}
  end

  def render(assigns) do
    minX =
      assigns.dots
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.min(fn -> 0 end)
      |> min(assigns.x)
      |> then(&(&1 - 500))

    minY =
      assigns.dots
      |> Enum.map(fn {_, y} -> y end)
      |> Enum.min(fn -> 0 end)
      |> min(assigns.y)
      |> then(&(&1 - 500))

    maxX =
      assigns.dots
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.max(fn -> 0 end)
      |> max(assigns.x)
      |> then(&(&1 + 500))

    maxY =
      assigns.dots
      |> Enum.map(fn {_, y} -> y end)
      |> Enum.max(fn -> 0 end)
      |> max(assigns.y)
      |> then(&(&1 + 500))

    assigns =
      assign(assigns, :box, %{
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY
      })

    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedScopedCSS}>
      svg {
        position: absolute;
        inset: 0;
        background: #ffddff;
        display: block;
        width: 100%;
        height: 100%;
      }

      :scope.scroller {
        overflow: scroll;
         overflow-y: scroll;
         overflow-x: scroll;
        position: absolute;
        width: 100%;
        height: 100%;
        inset: 0;
      }
      :scope.scroller::after {
      content: "foo";
      position: absolute;
      left: 0;
      top: 0;
      display: block;
      width: 200vw;
      height: 200vh;
      }

      :scope .scroller-body {
        position: sticky;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        z-index: 100;
      }

      :scope {
      user-select: none;
      touch-action: none;
      }
    </style>
    <div class="scroller">
      <div class="scroller-body">
        <svg
          preserveAspectRatio="xMidYMid meet"
          viewBox={"#{@box.x} #{@box.y} #{@box.width} #{@box.height}"}
          id="my-camera"
          phx-hook=".Camera"
        >
          <svg
            data-world
            overflow="visible"
            x={@box.x}
            y={@box.y}
            width={@box.width}
            height={@box.height}
            viewBox={"#{@box.x} #{@box.y} #{@box.width} #{@box.height}"}
          >
            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="#0001"
            />
            <circle id="my-circle" phx-hook=".Circle" cx={@x} cy={@y} r="100" fill="rebeccapurple">
            </circle>
            <%= for {x,y} <- @dots do %>
              <circle cx={x} cy={y} r="50" fill="magenta"></circle>
            <% end %>
          </svg>
        </svg>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Camera">
      const cam = {
        zoom: 0,
        angle: 0,
        x: 0,
        y: 0,
        screen: {
          width: 0,
          height: 0,
        },
        viewBox: {
          x: 0,
          y: 0,
          width: 0,
          height: 0
        }
      }
      function updateViewBox(e, r, c) {
      if(r) {
        r.setAttribute("transform", `rotate(${c.angle} ${c.x} ${c.y})`)
      }
        e.setAttribute("viewBox", `${c.x-c.screen.width/2 * Math.exp(-c.zoom)} ${c.y-c.screen.height/2 * Math.exp(-c.zoom)}
          ${c.screen.width * Math.exp(-c.zoom)} ${c.screen.height * Math.exp(-c.zoom)}
          `)
      }
      function rotate({ x, y }, { x: px, y: py }, angle) {
          const dx = x - px;
          const dy = y - py;

          const c = Math.cos(angle);
          const s = Math.sin(angle);

          return {
              x: px + dx * c - dy * s,
              y: py + dx * s + dy * c,
          };
      }
      export default {
        mounted(){
          if(this.el.firstElementChild && this.el.firstElementChild.dataset.hasOwnProperty("world")) {
            this.world = this.el.firstElementChild
          }
          const evtToSvg = (evt) => {
            point.x = evt.clientX;
            point.y = evt.clientY;
            const svgGlobal = point.matrixTransform(this.world.getScreenCTM().inverse());
            return{
                x: svgGlobal.x,
                y: svgGlobal.y,
              }
          }

          cam.screen= {width: window.innerWidth, height: window.innerHeight}
          const onWheel =  (evt) => {
            evt.preventDefault()
            const piv = evtToSvg(evt)

            if(evt.ctrlKey) {
                  const {x: nx, y: ny} = rotate(cam, piv, -Math.PI/180*evt.deltaY/10)
              cam.angle += evt.deltaY/10
              cam.x = nx
              cam.y = ny
            } else {
            const oldZoom = Math.exp(cam.zoom)
              cam.zoom -= evt.deltaY/1000
              const newZoom = Math.exp(cam.zoom)
                const factor = oldZoom / newZoom;

              cam.x = piv.x - (piv.x - cam.x) * factor;
              cam.y = piv.y - (piv.y - cam.y) * factor;
            }
            updateViewBox(this.el, this.world, cam)
          }
          const onPointerMove = (evt) => {
                              if(evt.currentTarget.hasPointerCapture(evt.pointerId)) {
                                evt.stopPropagation()
                                {
                                  const {x: x,y: y} = evtToSvg(evt);

                                  cam.x -= x -offset.x;
                                  cam.y -= y -offset.y;
                                }
                                updateViewBox(this.el, this.world, cam)
                                {
                                  const {x,y} = evtToSvg(evt)
                                  offset.x = x;
                                  offset.y = y;
                                }
                              }
                            }
          const onPointerDown = (evt) => {
                                evt.stopPropagation()
                                if(evt.isPrimary && evt.button == 1 && evt.shiftKey) {
                                  evt.currentTarget.setPointerCapture(evt.pointerId)
                                  const {x,y} = evtToSvg(evt)
                                  offset.x = x;
                                  offset.y = y;
                                }
                              }
          const onDblClick = (evt) => {
            this.pushEvent("create", evtToSvg(evt))
          }
          const svg = this.el;
          const point = svg.createSVGPoint();

          const offset = {x:0,y:0}
          this.el.addEventListener('pointerdown', onPointerDown);
          this.el.addEventListener('pointermove', onPointerMove);
          this.el.addEventListener('wheel', onWheel)
          this.el.addEventListener('dblclick', onDblClick )

          this.listeners = {
            pointerdown: onPointerDown,
            pointermove: onPointerMove,
            wheel: onWheel,
            dblclick: onDblClick,
          }

          updateViewBox(this.el, this.world, cam)
        },
        destroyed() {
          this.el.removeEventListener('pointerdown', this.listeners.pointerdown);
          this.el.removeEventListener('pointermove', this.listeners.pointermove);
          this.el.removeEventListener('wheel', this.listeners.wheel)
          this.el.removeEventListener('dblclick', this.listeners.dblclick)
        },
        updated()  {
          updateViewBox(this.el, this.world, cam)
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

          const evtToSvg = (evt, rel) => {
             point.x = evt.clientX;
             point.y = evt.clientY;
             const svgGlobal = point.matrixTransform((rel||svg).getScreenCTM().inverse());
             return {
               x: svgGlobal.x,
               y: svgGlobal.y,
             }
          }
          const offset = {x:0,y:0}
          const onPointerDown = (evt) => {
                      evt.stopPropagation()
                      if(evt.isPrimary && evt.button === 0) {
                        evt.currentTarget.setPointerCapture(evt.pointerId)

                        const {x,y} = evtToSvg(evt)
                        offset.x = x - this.el.getAttribute("cx");
                        offset.y = y - this.el.getAttribute("cy");
                      }
                    }

          const onPointerMove = (evt) => {
                      if(evt.currentTarget.hasPointerCapture(evt.pointerId)) {
                      evt.stopPropagation()
                        const {x: px,y: py} = evtToSvg(evt);

                        const x = px - offset.x
                        const y = py - offset.y
                        move(x,y)

                        this.el.setAttribute('cx', x);
                        this.el.setAttribute('cy', y );
                      }
                    }
          this.el.addEventListener('pointerdown', onPointerDown);
          this.el.addEventListener('pointermove', onPointerMove);
          this.listeners = {
                  pointerdown: onPointerDown,
                  pointermove: onPointerMove,
                }
        },
        destroyed() {

          this.el.removeEventListener('pointerdown', this.listeners.pointerdown);
          this.el.removeEventListener('pointermove', this.listeners.pointermove);
        }
      }
    </script>
    """
  end
end
