defmodule GeomextricWeb.Canvas do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  slot :inner_block, required: true
  attr :box, :map, default: %{}, doc: "The viewBox"

  def canvas(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedScopedCSS}>
      svg {
        position: absolute;
        inset: 0;
        background: #23875daa;
        display: block;
        width: 100%;
        height: 100%;
        shaper-rendering: geometricPrecision;
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
      content: "";
      position: absolute;
      left: 0;
      top: 0;
      display: block;
      width: var(--scroll-width);
      height: var(--scroll-height);
      }

      :scope .scroller-body {
        position: sticky;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        z-index: 100;
      }

      :scope circle {
        cursor: move;
      }

      :scope {
      user-select: none;
      touch-action: none;
      }
    </style>
    <div class="scroller" data-scrollbars tabindex="-1">
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
            preserveAspectRatio="xMidYMid slice"
            x={@box.x}
            y={@box.y}
            width={@box.width}
            height={@box.height}
            viewBox={"#{@box.x} #{@box.y} #{@box.width} #{@box.height}"}
          >
            <defs>
              <pattern
                id="grid"
                width="20"
                height="20"
                patternTransform="scale(0)"
                patternUnits="userSpaceOnUse"
              >
                <path
                  shape-rendering="geometricPrecision"
                  d="M 0 0 L 10 0 M 20 0 L 10 0 M 0 0 L 0 10 M 0 20 L 0 10"
                  fill="none"
                  stroke="#abc8"
                  stroke-width="0.25px"
                />
              </pattern>
              <pattern
                id="grid-sec"
                width="40"
                height="40"
                patternTransform="scale(0)"
                patternUnits="userSpaceOnUse"
              >
                <path
                  shape-rendering="geometricPrecision"
                  d="M 0 0 L 20 0 M 40 0 L 20 0 M 0 0 L 0 20 M 0 40 L 0 20"
                  fill="none"
                  stroke="#cdea"
                  stroke-width="0.5px"
                />
              </pattern>
            </defs>
            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="#fff"
              stroke="#d0d0d0"
              vector-effect="non-scaling-stroke"
              stroke-width="2"
              rx="32"
              ry="32"
            />
            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="url(#grid)"
              opacity="0.8"
              rx="32"
              ry="32"
            />

            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="url(#grid-sec)"
              rx="32"
              ry="32"
            />

            {render_slot(@inner_block)}
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
          height: 0,
        },
      };
      let resumeScroll = null;
      function updateViewBox(e, r, cam, scroller) {
        if (r) {
          r.setAttribute("transform", `rotate(${cam.angle} ${cam.x} ${cam.y})`);
        }
        e.setAttribute(
          "viewBox",
          `${cam.x - (cam.screen.width / 2) * Math.exp(-cam.zoom)} ${cam.y - (cam.screen.height / 2) * Math.exp(-cam.zoom)}
                                      ${cam.screen.width * Math.exp(-cam.zoom)} ${cam.screen.height * Math.exp(-cam.zoom)}
                                      `,
        );

        r.setAttribute("data-zoomed", cam.zoom < 0 ? "out" : "in");
        r.style.setProperty("--cam-scale", Math.exp(-cam.zoom));
        r.style.setProperty(
          "--cam-scale-clamped",
          Math.exp(Math.max(-2, Math.min(2, -cam.zoom))),
        );
        r.style.setProperty("--cam-scale-max", Math.exp(Math.max(-2, -cam.zoom)));
        r.style.setProperty("--cam-scale-min", Math.exp(Math.min(2, -cam.zoom)));
        const logScale = Math.pow(2, Math.round(-cam.zoom / Math.log(2)) + 2);
        scroller
          .querySelectorAll("pattern")
          .forEach((g) => g.setAttribute("patternTransform", `scale(${logScale})`));

        if (scroller) {
          const cos = Math.cos((cam.angle / 180) * Math.PI);
          const sin = Math.sin((cam.angle / 180) * Math.PI);

          const cosAbs = Math.abs(cos);
          const sinAbs = Math.abs(sin);
          const boundingX =
            r.width.baseVal.value * cosAbs + r.height.baseVal.value * sinAbs;
          const boundingY =
            r.width.baseVal.value * sinAbs + r.height.baseVal.value * cosAbs;
          const cX = r.width.baseVal.value / 2 + r.x.baseVal.value;
          const cY = r.height.baseVal.value / 2 + r.y.baseVal.value;

          const scrollWidth =
            boundingX * Math.exp(cam.zoom) + scroller.clientWidth * 2;
          const scrollHeight =
            boundingY * Math.exp(cam.zoom) + scroller.clientHeight * 2;
          if (!isNaN(scrollWidth) && !isNaN(scrollHeight)) {
            if (scrollWidth > 2 << 20 || scrollHeight > 2 << 20) {
              return;
            }
            scroller.style.setProperty("--scroll-width", scrollWidth + "px");
            scroller.style.setProperty("--scroll-height", scrollHeight + "px");
          }
          const newScrollLeft =
            0.5 * scroller.clientWidth +
            (boundingX * Math.exp(cam.zoom)) / 2 +
            ((cam.x - cX) * cos - (cam.y - cY) * sin) * Math.exp(cam.zoom);
          const newScrollTop =
            0.5 * scroller.clientHeight +
            (boundingY * Math.exp(cam.zoom)) / 2 +
            ((cam.y - cY) * cos + (cam.x - cX) * sin) * Math.exp(cam.zoom);

          const eps = 10;

          if (
            Math.abs(scroller.scrollTop - newScrollTop) > eps ||
            Math.abs(scroller.scrollLeft - newScrollLeft) > eps
          ) {
            scroller.scrollTo({
              left: newScrollLeft,
              top: newScrollTop,
              behavior: "instant",
            });
          }
        }
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
        mounted() {
          if (
            this.el.firstElementChild &&
            this.el.firstElementChild.dataset.hasOwnProperty("world")
          ) {
            this.world = this.el.firstElementChild;
          }
          this.scroller = this.el.closest("[data-scrollbars]");
          this.scrollerBody = this.scroller.firstElementChild;
          const onScroll = (evt) => {
            const angle = (cam.angle * Math.PI) / 180;
            const cos = Math.cos(angle);
            const sin = Math.sin(angle);
            const cosabs = Math.abs(cos);
            const sinabs = Math.abs(sin);
            const boundingX =
              this.world.width.baseVal.value * cosabs +
              this.world.height.baseVal.value * sinabs;
            const boundingY =
              this.world.width.baseVal.value * sinabs +
              this.world.height.baseVal.value * cosabs;

            const s = Math.exp(cam.zoom);

            const cX =
              this.world.width.baseVal.value / 2 + this.world.x.baseVal.value;
            const cY =
              this.world.height.baseVal.value / 2 + this.world.y.baseVal.value;

            const dx =
              this.scroller.scrollLeft -
              0.5 * this.scroller.clientWidth -
              (boundingX * s) / 2;

            const dy =
              this.scroller.scrollTop -
              0.5 * this.scroller.clientHeight -
              (boundingY * s) / 2;
            cam.x = (dx * cos + dy * sin) / s + cX;
            cam.y = (-dx * sin + dy * cos) / s + cY;
            updateViewBox(this.el, this.world, cam, this.scroller);
          };
          this.scroller.addEventListener("scroll", onScroll, { passive: false });
          const evtToSvg = (evt) => {
            point.x = evt.clientX;
            point.y = evt.clientY;
            const svgGlobal = point.matrixTransform(
              this.world.getScreenCTM().inverse(),
            );

            return {
              x: svgGlobal.x,
              y: svgGlobal.y,
            };
          };

          const wr = (this.world.viewBox.baseVal.width / window.innerWidth) * 1;
          const hr = (this.world.viewBox.baseVal.height / window.innerHeight) * 1;
          cam.zoom = Math.max(-6, -Math.log(Math.max(wr, hr)));
          cam.x = this.el.viewBox.baseVal.width / 2 + this.el.viewBox.baseVal.x;
          cam.y = this.el.viewBox.baseVal.height / 2 + this.el.viewBox.baseVal.y;

          const resize = () => {
            cam.screen = { width: window.innerWidth, height: window.innerHeight };

            updateViewBox(this.el, this.world, cam, this.scroller);
          };
          resize();

          updateViewBox(this.el, this.world, cam, this.scroller);

          const clampZoom = (oldZoom, delta) => {
            const newZoom = Math.max(-6, oldZoom + delta);
            const newFactor = Math.exp(newZoom);
            if (this.scroller) {
              const r = this.world;

              const bounding = Math.max(
                r.height.baseVal.value,
                r.height.baseVal.value,
              );

              const scrollSize =
                bounding * newFactor +
                Math.max(this.scroller.clientWidth, this.scroller.clientHeight) * 2;

              return !isNaN(scrollSize) && scrollSize < 2 << 18 ? newZoom : oldZoom;
            }
          };
          let piv = null;
          const onWheel = (evt) => {
            if (!piv) {
              console.log("x");

              piv = evtToSvg(evt);
            }

            if (evt.altKey) {
              evt.preventDefault();
              const { x: nx, y: ny } = rotate(
                cam,
                piv,
                ((-Math.PI / 180) * evt.deltaY) / 10,
              );
              cam.angle += evt.deltaY / 10;
              cam.x = nx;
              cam.y = ny;

              updateViewBox(this.el, this.world, cam, this.scroller);
            } else if (evt.ctrlKey) {
              evt.preventDefault();
              const oldZoom = Math.exp(cam.zoom);
              console.log(cam.zoom);

              cam.zoom = clampZoom(cam.zoom, -evt.deltaY / 1000);
              const newZoom = Math.exp(cam.zoom);
              const factor = oldZoom / newZoom;

              cam.x = piv.x - (piv.x - cam.x) * factor;
              cam.y = piv.y - (piv.y - cam.y) * factor;

              updateViewBox(this.el, this.world, cam, this.scroller);
            }
          };
          let skipclick = false;
          const onPointerCancel = (evt) => {};
          const onPointerUp = (evt) => {
            const { x, y } = evtToSvg(evt);

            if (movement > 10) {
              if (evt.button === 2 && !evt.shiftKey) {
                this.pushEvent("lasso", {
                  x: Math.min(offset.x, x),
                  y: Math.min(offset.y, y),
                  width: Math.abs(x - offset.x),
                  height: Math.abs(y - offset.y),
                });
              } else if (evt.button == 0 && selecting) {
                skipclick = true;
                this.pushEvent("create", {
                  pos: {
                    x: Math.min(offset.x, x),
                    y: Math.min(offset.y, y),
                    width: Math.abs(x - offset.x),
                    height: Math.abs(y - offset.y),
                  },

                  radius: 5 * Math.exp(-cam.zoom),
                });
              } else if (evt.button == 0 && pointing) {
                skipclick = true;

                this.pushEvent("create", {
                  start: {
                    x,
                    y,
                  },
                  end: {
                    x: offset.x,
                    y: offset.y,
                  },
                  thickness: Math.exp(-cam.zoom),
                });
              }

              selecting = false;
              pointing = false;
            }

            lasso.setAttribute("opacity", 0);
            arrow.setAttribute("opacity", 0);
          };
          let movement = 0;
          const onPointerMove = (evt) => {
            piv = null;
            if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
              evt.stopPropagation();
              if (selecting) {
                const { x, y } = evtToSvg(evt);
                movement += Math.hypot(evt.movementX, evt.movementY);

                skipclick ||= movement > 10;
                if (skipclick) {
                  lasso.setAttribute("opacity", 1);
                  lasso.setAttribute("x", Math.min(offset.x, x));
                  lasso.setAttribute("y", Math.min(offset.y, y));
                  lasso.setAttribute("width", Math.abs(x - offset.x));
                  lasso.setAttribute("height", Math.abs(y - offset.y));
                }
              } else if (pointing) {
                const { x, y } = evtToSvg(evt);

                movement += Math.hypot(evt.movementX, evt.movementY);
                arrow.setAttribute("opacity", 1);
                arrow.setAttribute("x1", x);
                arrow.setAttribute("y1", y);
                arrow.setAttribute("x2", offset.x);
                arrow.setAttribute("y2", offset.y);
              } else {
                {
                  const { x: x, y: y } = evtToSvg(evt);

                  cam.x -= x - offset.x;
                  cam.y -= y - offset.y;
                }
                updateViewBox(this.el, this.world, cam, this.scroller);
                {
                  const { x, y } = evtToSvg(evt);
                  offset.x = x;
                  offset.y = y;
                }
              }
            }
          };
          let selecting = false;
          let pointing = false;
          this.tools = document.createElementNS("http://www.w3.org/2000/svg", "g");
          const lasso = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "rect",
          );
          const arrow = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "line",
          );
          {
            lasso.classList.add("auto-color");
            lasso.setAttribute("x", "0");
            lasso.setAttribute("y", "0");
            lasso.setAttribute("opacity", 0);
            lasso.setAttribute("fill-opacity", 0.2);
            lasso.setAttribute("fill", "blue");
            lasso.setAttribute("stroke", "darkblue");
            lasso.setAttribute("stroke-width", 1);
            lasso.setAttribute("pointer-events", "none");
            lasso.setAttribute("stroke-dasharray", "5 5");
            lasso.setAttribute("vector-effect", "non-scaling-stroke");
            lasso.setAttribute("width", "0");
            lasso.setAttribute("height", "0");
            this.tools.appendChild(lasso);
          }
          {
            arrow.classList.add("auto-color");
            arrow.setAttribute("x1", "0");
            arrow.setAttribute("y1", "0");
            arrow.setAttribute("x2", "0");
            arrow.setAttribute("y2", "0");
            arrow.setAttribute("opacity", 0);
            arrow.setAttribute("fill-opacity", 0.2);
            arrow.setAttribute("fill", "blue");
            arrow.setAttribute("stroke", "darkblue");
            arrow.setAttribute("stroke-width", 1);
            arrow.setAttribute("pointer-events", "none");
            arrow.setAttribute("stroke-dasharray", "5 5");
            arrow.setAttribute("vector-effect", "non-scaling-stroke");
            this.tools.appendChild(arrow);
          }
          this.world.appendChild(this.tools);
          const onPointerDown = (evt) => {
            const { x, y } = evtToSvg(evt);
            if (evt.isPrimary && evt.button == 1 && evt.shiftKey) {
              evt.stopPropagation();
              evt.preventDefault();
              evt.currentTarget.setPointerCapture(evt.pointerId);
              offset.x = x;
              offset.y = y;
            } else if (!evt.shiftKey && evt.button != 1) {
              evt.stopPropagation();
              evt.preventDefault();
              movement = 0;
              evt.currentTarget.setPointerCapture(evt.pointerId);
              selecting = true;
              offset.x = x;
              offset.y = y;
              arrow.setAttribute("opacity", 1);
              arrow.setAttribute("x1", x);
              arrow.setAttribute("y1", y);
              arrow.setAttribute("x2", x);
              arrow.setAttribute("y2", y);
            } else if (evt.shiftKey && evt.button != 2) {
              evt.stopPropagation();
              evt.preventDefault();
              movement = 0;
              evt.currentTarget.setPointerCapture(evt.pointerId);
              pointing = true;
              offset.x = x;
              offset.y = y;
              lasso.setAttribute("opacity", 1);
              lasso.setAttribute("x", x);
              lasso.setAttribute("y", y);

              lasso.setAttribute("width", "0");
              lasso.setAttribute("height", "0");
            }
          };
          const onDblClick = (evt) => {
            if (skipclick) {
              skipclick = false;
              return;
            }
            evt.preventDefault();
            this.pushEvent("create", {
              pos: evtToSvg(evt),
              radius: 10 * Math.exp(-cam.zoom),
            });
          };

          const onDrop = (evt) => {
            try {
              const data = JSON.parse(evt.dataTransfer.getData("text/plain"));
              switch (data.type) {
                case "circle": {
                  this.pushEvent("create", {
                    pos: evtToSvg(evt),
                    color: data.color,
                    radius: 10 * Math.exp(-cam.zoom),
                  });
                  break;
                }

                case "rect": {
                  const p = evtToSvg(evt);
                  this.pushEvent("create", {
                    pos: {
                      x: p.x - 10 * Math.exp(-cam.zoom),
                      y: p.y - 10 * Math.exp(-cam.zoom),
                      width: 20 * Math.exp(-cam.zoom),
                      height: 20 * Math.exp(-cam.zoom),
                    },
                    radius: 5 * Math.exp(-cam.zoom),
                    color: data.color,
                  });
                  break;
                }
              }
            } catch (e) {}
          };
          const svg = this.el;
          const point = svg.createSVGPoint();

          const offset = { x: 0, y: 0 };
          this.el.addEventListener("pointerdown", onPointerDown);
          this.el.addEventListener("pointerup", onPointerUp);
          this.el.addEventListener("pointercancel", onPointerCancel);
          this.el.addEventListener("pointermove", onPointerMove);
          this.el.addEventListener("wheel", onWheel);
          this.el.addEventListener("click", onDblClick);
          this.el.addEventListener("drop", onDrop);
          this.el.addEventListener("contextmenu", (evt) => evt.preventDefault());

          window.addEventListener("resize", resize);

          this.listeners = {
            pointerdown: onPointerDown,
            pointerup: onPointerUp,
            pointermove: onPointerMove,
            wheel: onWheel,
            click: onDblClick,
            scroll: onScroll,
            drop: onDrop,
            resize,
          };

          updateViewBox(this.el, this.world, cam, this.scroller);
        },
        destroyed() {
          this.el.removeEventListener("pointerdown", this.listeners.pointerdown);
          this.el.removeEventListener("pointerup", this.listeners.pointerup);
          this.el.removeEventListener("pointermove", this.listeners.pointermove);
          this.el.removeEventListener("wheel", this.listeners.wheel);
          this.el.removeEventListener("click", this.listeners.dblclick);
          this.el.removeEventListener("drop", this.listeners.drop);

          this.scroller.removeEventListener("scroll", this.listeners.scroll, {
            passive: false,
          });

          this.world.removeChild(this.tools);
        },
        updated() {
          updateViewBox(this.el, this.world, cam, this.scroller);

          this.world.appendChild(this.tools);
        },
      };
    </script>
    """
  end
end
