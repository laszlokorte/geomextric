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
    <g id={"g-#{@id}"} pointer-events="paint" overflow="visible">
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
      <g id={"h-#{@id}"} opacity="0" stroke-opacity="1" data-layer={@id} phx-hook=".Line">
        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke={@stroke}
          pointer-events="all"
          stroke-width={@stroke_width}
          stroke-linecap="round"
        />

        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke={@stroke}
          pointer-events="all"
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
          const onPointerDown = (evt) => {
            if (evt.isPrimary && evt.button === 0) {
              evt.currentTarget.setAttribute("opacity", 0.2);

              evt.preventDefault();
              evt.stopPropagation();
              evt.currentTarget.setPointerCapture(evt.pointerId);

              const { x, y } = evtToSvg(evt);

              this.el.setAttribute("transform", ``);
              offset.x = x;
              offset.y = y;
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

              // move(x,y)
              // offset.x = x;
              // offset.y = y;

              this.el.setAttribute("transform", `translate(${x}, ${y})`);
            }
          };

          const onPointerCancel = (evt) => {
            evt.currentTarget.setAttribute("opacity", 0);
          };
          const onPointerUp = (evt) => {
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.stopPropagation();

              evt.currentTarget.setAttribute("opacity", 0);

              this.el.setAttribute("transform", ``);

              const { x: px, y: py } = evtToSvg(evt);

              const x =
                px - 1 * offset.x + 1 * this.el.firstElementChild.getAttribute("x1");
              const y =
                py - 1 * offset.y + 1 * this.el.firstElementChild.getAttribute("y1");
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
          this.el.addEventListener("pointercancel", onPointerCancel);
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
