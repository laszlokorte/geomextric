defmodule GeomextricWeb.Dragger do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :x, :float, default: 0.0, doc: "x"
  attr :y, :float, default: 0.0, doc: "y"
  attr :color, :string, default: nil
  attr :id, :string, default: "line", doc: "id"
  attr :prefix, :string, default: "dragger", doc: "id"
  slot :inner_block, required: true
  slot :pin, required: false
  slot :handle, required: true
  attr :show_handle, :boolean, default: false

  def dragger(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    <g>
      <g
        pointer-events="paint"
        id={"#{@prefix}-#{@id}"}
        base-x={@x}
        base-y={@y}
        color={@color}
        opacity={if(@show_handle, do: 0.3, else: 0)}
        data-layer={@id}
        phx-hook=".DragControl"
      >
        {render_slot(@handle)}
      </g>
    </g>
    <g pointer-events="none">
      <%= for {p, pi} <- @pin |> Enum.with_index() do %>
        <g fill="gold" stroke="white" id={"pin-#{@prefix}-#{@id}-#{pi}"} phx-hook=".Pin">
          {render_slot(p)}
        </g>
      <% end %>
    </g>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Pin">
      export default {
        mounted() {
          this.el.addEventListener("pointerdown", (evt) => {
            return;
            evt.currentTarget.setPointerCapture(evt.pointerId);
            evt.preventDefault();
            evt.stopPropagation();
          });
        },
      };
    </script>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".DragControl">
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
          t.clonedEl.setAttribute("id", "cloned" + t.id);
          t.clonedEl.removeAttribute("phx-hook");
          t.el.parentNode.appendChild(t.clonedEl);
        }

        return t.clonedEl;
      };

      export default {
        mounted() {
          this.multiDragRoot = this.el.closest("[multi-drag-root]");
          const id = this.el.getAttribute("data-layer");
          const moveSelected = throttle(
            (x, y) => this.pushEvent("move", { dx: x, dy: y }),
            60,
            debounce((x, y) => this.pushEvent("move", { dx: x, dy: y }), 500),
          );
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
          this.base = { x: 0, y: 0 };

          let movement = 0;
          const onPointerDown = (evt) => {
            noClick = false;
            if (evt.isPrimary && evt.button === 0 && !evt.ctrlKey) {
              clonedEl(this).setAttribute("opacity", 0.2);
              movement = 0;

              evt.preventDefault();
              evt.stopPropagation();
              this.el.setPointerCapture(evt.pointerId);

              const { x, y } = evtToSvg(evt);

              this.multiDragRoot?.setAttribute("transform", ``);
              clonedEl(this, true).setAttribute("transform", ``);
              offset.x = x;
              offset.y = y;
              this.base.x = 1 * this.el.getAttribute("base-x") * 1;
              this.base.y = 1 * this.el.getAttribute("base-y") * 1;
            }
          };
          let noClick = false;

          const onPointerMove = (evt) => {
            movement += Math.hypot(evt.movementX, evt.movementY);
            if (this.el.hasPointerCapture(evt.pointerId)) {
              const { x: px, y: py } = evtToSvg(evt);

              const x = px - offset.x;
              const y = py - offset.y;
              noClick ||= movement > 5;

              //  move(
              //    x + 1 * this.base.x,
              //    y + 1 * this.base.y,
              //  );

              (this.multiDragRoot || clonedEl(this)).setAttribute(
                "transform",
                `translate(${x}, ${y})`,
              );
            }
          };

          const onPointerCancel = (evt) => {
            clonedEl(this).setAttribute("opacity", 0);
          };
          const onPointerUp = (evt) => {
            if (this.el.hasPointerCapture(evt.pointerId) && movement > 0) {
              evt.stopPropagation();

              const { x: px, y: py } = evtToSvg(evt);

              const x = px - 1 * offset.x;
              const y = py - 1 * offset.y;

              if (this.multiDragRoot) {
                moveSelected(x, y);
              } else {
                move(x + 1 * this.base.x, y + 1 * this.base.y);
              }
            } else {
              this.pushEvent("select", {
                value: this.el.getAttribute("data-layer"),
                op: evt.shiftKey ? "toggle" : "replace",
              });
            }

            clonedEl(this).setAttribute("opacity", 0);
          };
          this.el.addEventListener("pointerdown", onPointerDown);
          this.el.addEventListener("click", (evt) => {
            evt.stopPropagation();
          });
          this.el.addEventListener("dblclick", (evt) => {
            if (evt.shiftKey) {
              if (this.el.hasAttribute("color")) {
                this.pushEvent("change_pen", {
                  value: this.el.getAttribute("color"),
                });
              }
              return;
            }
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
