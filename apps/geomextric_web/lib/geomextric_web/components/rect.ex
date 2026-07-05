defmodule GeomextricWeb.Rectangle do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :x, :float, default: 0.0, doc: "x"
  attr :y, :float, default: 0.0, doc: "y"
  attr :width, :float, default: 0.0, doc: "width"
  attr :height, :float, default: 0.0, doc: "height"
  attr :fill, :string, default: "red", doc: "fill color"
  attr :id, :string, default: "circle", doc: "id"

  def rect(assigns) do
    ~H"""
    <g id={"g-#{@id}"} overflow="visible">
      <rect
        shape-rendering="geometricPrecision"
        x={@x}
        y={@y}
        width={@width}
        height={@height}
        fill={@fill}
      >
      </rect>
      <rect
        shape-rendering="geometricPrecision"
        id={@id}
        phx-hook=".Rect"
        x={@x}
        y={@y}
        width={@width}
        height={@height}
        fill={@fill}
        opacity="0.3"
      />
    </g>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Rect">
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
      const debounce = (callback, wait) => {
        let timeoutId = null;
        return (...args) => {
          window.clearTimeout(timeoutId);
          timeoutId = window.setTimeout(() => {
            callback(...args);
          }, wait);
        };
      };
      export default {
        mounted() {
          const move = throttle(
            (x, y) => this.pushEvent("move", { id: this.el.id, x, y }),
            60,
            debounce((x, y) => this.pushEvent("move", { id: this.el.id, x, y }), 500),
          );
          const del = throttle(
            (x, y) => this.pushEvent("delete", { id: this.el.id }),
            60,
            debounce((x, y) => this.pushEvent("delete", { id: this.el.id }), 500),
          );

          const svg = this.el.ownerSVGElement;
          const point = svg.createSVGPoint();

          const evtToSvg = (evt, rel) => {
            point.x = evt.clientX;
            point.y = evt.clientY;
            const svgGlobal = point.matrixTransform(
              (rel || svg).getScreenCTM().inverse(),
            );
            return {
              x: svgGlobal.x,
              y: svgGlobal.y,
            };
          };
          const offset = { x: 0, y: 0 };
          const onPointerDown = (evt) => {
            if (evt.isPrimary && evt.button === 0) {
              evt.stopPropagation();
              evt.currentTarget.setPointerCapture(evt.pointerId);

              const { x, y } = evtToSvg(evt);
              offset.x = x - this.el.getAttribute("x");
              offset.y = y - this.el.getAttribute("y");
            }
          };
          let noClick = false;

          const onPointerMove = (evt) => {
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.stopPropagation();
              const { x: px, y: py } = evtToSvg(evt);

              const x = px - offset.x;
              const y = py - offset.y;
              noClick = true;

              //  move(x,y)
              this.el.setAttribute("x", x);
              this.el.setAttribute("y", y);
            }
          };
          const onPointerUp = (evt) => {
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.stopPropagation();
              const { x: px, y: py } = evtToSvg(evt);

              const x = px - offset.x;
              const y = py - offset.y;
              move(x, y);
            }
          };
          this.el.addEventListener("pointerdown", onPointerDown);
          this.el.addEventListener("click", (evt) => evt.stopPropagation());
          this.el.addEventListener("dblclick", (evt) => {
            if (noClick) {
              noClick = false;
              return;
            }
            evt.preventDefault();

            del();
          });
          this.el.addEventListener("pointermove", onPointerMove);
          this.el.addEventListener("pointerup", onPointerUp);
          this.listeners = {
            pointerdown: onPointerDown,
            pointermove: onPointerMove,
            pointerup: onPointerUp,
          };
        },
        destroyed() {
          this.el.removeEventListener("pointerdown", this.listeners.pointerdown);
          this.el.removeEventListener("pointermove", this.listeners.pointermove);
          this.el.removeEventListener("pointerup", this.listeners.pointerup);
        },
      };
    </script>
    """
  end
end
