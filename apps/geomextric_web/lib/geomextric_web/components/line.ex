defmodule GeomextricWeb.Line do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext
  defp hypot(x, y), do: :math.sqrt(x * x + y * y)

  attr :x1, :float, default: 0.0, doc: "x1"
  attr :y1, :float, default: 0.0, doc: "y1"
  attr :x2, :float, default: 0.0, doc: "x2"
  attr :y2, :float, default: 0.0, doc: "y2"
  attr :stroke, :string, default: "red", doc: "stroke color"
  attr :stroke_width, :float, default: 1.0, doc: "stroke width"
  attr :id, :string, default: "line", doc: "id"

  def line(assigns) do
    ~H"""
    <g id={"g-#{@id}"} overflow="visible">
      <line
        shape-rendering="geometricPrecision"
        x1={@x1}
        y1={@y1}
        x2={@x2}
        y2={@y2}
        stroke={@stroke}
        stroke-width={@stroke_width}
        stroke-linecap="round"
      />
      <g
        pointer-events="paint"
        stroke={@stroke}
        id={"h-#{@id}"}
        opacity="0"
        stroke-opacity="1"
        data-layer={@id}
        phx-hook=".Line"
      >
        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke-width={@stroke_width * 1.5}
          stroke-linecap="round"
        />

        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke-width={10}
          vector-effect="non-scaling-stroke"
          stroke-linecap="round"
        />
      </g>
    </g>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Line">
      import {
        throttle,
        debounce,
      } from "../../../../../apps/geomextric_web/assets/js/foo";

      const clonedEl = (t, reset) => {
        if (reset && t.clonedEl) {
          if (t.clonedEl.parentNode) {
            t.clonedEl.parentNode.removeChild(t.clonedEl);
          }
          t.clonedEl = null;
        }

        if (!t.clonedEl) {
          t.clonedEl = t.el.cloneNode(true);
          t.clonedEl.setAttribute("pointer-events", "none");
          t.clonedEl.setAttribute("opacity", "0.3");
          t.clonedEl.removeAttribute("id");
          t.clonedEl.removeAttribute("phx-hook");
          t.el.parentNode.appendChild(t.clonedEl);
        }

        return t.clonedEl;
      };

      export default {
        mounted() {
          const id = this.el.getAttribute("data-layer");
          const move = throttle(
            (x, y) => this.pushEvent("move", { id: id, x, y }),
            60,
            debounce((x, y) => this.pushEvent("move", { id: id, x, y }), 500),
          );
          const del = throttle(
            (x, y) => this.pushEvent("delete", { id: id }),
            60,
            debounce((x, y) => this.pushEvent("delete", { id: id }), 500),
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
          this.line = { x: 0, y: 0 };
          this.dragging = false;
          const onPointerDown = (evt) => {
            if (evt.isPrimary && evt.button === 0 && !evt.ctrlKey) {
              clonedEl(this).setAttribute("opacity", 0.2);

              evt.preventDefault();
              evt.stopPropagation();
              this.el.setPointerCapture(evt.pointerId);

              const { x, y } = evtToSvg(evt);
              console.log("x");

              clonedEl(this, true).setAttribute("transform", ``);
              offset.x = x;
              offset.y = y;
              this.line.x = this.el.firstElementChild.getAttribute("x1") * 1;
              this.line.y = this.el.firstElementChild.getAttribute("y1") * 1;
              this.dragging = true;
            }
          };
          let noClick = false;

          const onPointerMove = (evt) => {
            if (this.el.hasPointerCapture(evt.pointerId)) {
              const { x: px, y: py } = evtToSvg(evt);

              const x = px - offset.x;
              const y = py - offset.y;
              noClick = true;

              // move( x+ 1 * this.line.x
              //   ,y + 1 * this.line.y
              // )

              clonedEl(this).setAttribute("transform", `translate(${x}, ${y})`);
            }
          };

          const onPointerCancel = (evt) => {
            clonedEl(this).setAttribute("opacity", 0);
          };
          const onPointerUp = (evt) => {
            if (this.el.hasPointerCapture(evt.pointerId)) {
              evt.stopPropagation();

              clonedEl(this).setAttribute("opacity", 0);

              const { x: px, y: py } = evtToSvg(evt);

              const x = px - 1 * offset.x;
              const y = py - 1 * offset.y;

              move(x + 1 * this.line.x, y + 1 * this.line.y);

              this.dragging = false;
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
          this.el.addEventListener("pointercancel", onPointerCancel);
          this.listeners = {
            pointerdown: onPointerDown,
            pointermove: onPointerMove,
            pointerup: onPointerUp,
          };
        },
        destroyed() {
          if (this.clonedEl) {
            if (this.clonedEl.parentNode) {
              this.clonedEl.parentNode.removeChild(this.clonedEl);
            }
            this.clonedEl = null;
          }
          this.el.removeEventListener("pointerdown", this.listeners.pointerdown);
          this.el.removeEventListener("pointermove", this.listeners.pointermove);
          this.el.removeEventListener("pointerup", this.listeners.pointerup);
        },
        updated() {
          if (this.clonedEl) {
            this.el.parentNode.appendChild(this.clonedEl);
          }
        },
      };
    </script>
    """
  end
end
