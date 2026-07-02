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
    <div class="scroller" data-scrollbars>
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
              fill="#fffa"
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
          height: 0
        }
      }
      function updateViewBox(e, r, cam, scroller) {
      if(r) {
        r.setAttribute("transform", `rotate(${cam.angle} ${cam.x} ${cam.y})`)
      }
        e.setAttribute("viewBox", `${cam.x-cam.screen.width/2 * Math.exp(-cam.zoom)} ${cam.y-cam.screen.height/2 * Math.exp(-cam.zoom)}
          ${cam.screen.width * Math.exp(-cam.zoom)} ${cam.screen.height * Math.exp(-cam.zoom)}
          `)

        if(scroller) {
          const cos = Math.cos(cam.angle / 180 * Math.PI)
          const sin = Math.sin(cam.angle / 180 * Math.PI)

          const cosAbs = Math.abs(cos);
          const sinAbs = Math.abs(sin);
          const boundingX = r.width.baseVal.value * cosAbs + r.height.baseVal.value* sinAbs
          const boundingY = r.width.baseVal.value * sinAbs + r.height.baseVal.value* cosAbs
          const cX =r.width.baseVal.value/2 + r.x.baseVal.value
               const cY =r.height.baseVal.value/2 + r.y.baseVal.value
               const cXr = cX * cos + cY * sin
               const cYr = cY * cos - cX * sin

          scroller.style.setProperty('--scroll-width',  boundingX * Math.exp(cam.zoom) + scroller.clientWidth * 2 + 'px')
          scroller.style.setProperty('--scroll-height',  boundingY * Math.exp(cam.zoom) + scroller.clientHeight * 2+ 'px')
        scroller.scrollLeft = 0.5 * scroller.clientWidth +
        (boundingX )  * Math.exp(cam.zoom) / 2
        + ((cam.x-cX) * cos - (cam.y-cY) * sin) *  Math.exp(cam.zoom)
           scroller.scrollTop = 0.5 * scroller.clientHeight
           + (boundingY ) * Math.exp(cam.zoom) / 2
           + ((cam.y-cY) * cos + (cam.x-cX) * sin) *  Math.exp(cam.zoom)
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
        mounted(){
          if(this.el.firstElementChild && this.el.firstElementChild.dataset.hasOwnProperty("world")) {
            this.world = this.el.firstElementChild
          }
          this.scroller  = this.el.closest('[data-scrollbars]')
          this.scrollerBody = this.scroller.firstElementChild
          this.scroller.addEventListener('scroll', (evt) => {

            const angle = cam.angle * Math.PI / 180;
            const cos = Math.cos(angle);
            const sin = Math.sin(angle);
            const cosabs = Math.abs(cos)
            const sinabs = Math.abs(sin)
            const boundingX = this.world.width.baseVal.value * cosabs + this.world.height.baseVal.value* sinabs
            const boundingY = this.world.width.baseVal.value * sinabs + this.world.height.baseVal.value* cosabs

            const s = Math.exp(cam.zoom);

                      const cX =this.world.width.baseVal.value/2 + this.world.x.baseVal.value
                      const cY =this.world.height.baseVal.value/2 + this.world.y.baseVal.value
            const cXr = cX * cos + cY * sin
              const cYr = cY * cos - cX * sin

            const dx =
                this.scroller.scrollLeft -
                0.5 * this.scroller.clientWidth -
                boundingX * s / 2

            const dy =
                this.scroller.scrollTop -
                0.5 * this.scroller.clientHeight -
                boundingY * s / 2
          cam.x = (dx * cos + dy * sin) / s + cX;
            cam.y = (-dx * sin + dy * cos) / s + cY;
            updateViewBox(this.el, this.world, cam, this.scroller)

          })
          const evtToSvg = (evt) => {
            point.x = evt.clientX;
            point.y = evt.clientY;
            const svgGlobal = point.matrixTransform(this.world.getScreenCTM().inverse());
            return{
                x: svgGlobal.x,
                y: svgGlobal.y,
              }
          }

          const wr = this.el.viewBox.baseVal.width / window.innerWidth
          const hr = this.el.viewBox.baseVal.height / window.innerHeight
          cam.zoom = -Math.log(Math.max(wr, hr))
          cam.x = this.el.viewBox.baseVal.width / 2 + this.el.viewBox.baseVal.x
          cam.y = this.el.viewBox.baseVal.height / 2 + this.el.viewBox.baseVal.y
          cam.screen= {width: window.innerWidth, height: window.innerHeight}

          updateViewBox(this.el, this.world, cam, this.scroller)
          const onWheel =  (evt) => {
            const piv = evtToSvg(evt)

            if(evt.altKey) {
            evt.preventDefault()
                  const {x: nx, y: ny} = rotate(cam, piv, -Math.PI/180*evt.deltaY/10)
              cam.angle += evt.deltaY/10
              cam.x = nx
              cam.y = ny
            } else if(evt.ctrlKey) {
              evt.preventDefault()
            const oldZoom = Math.exp(cam.zoom)
              cam.zoom -= evt.deltaY/1000
              const newZoom = Math.exp(cam.zoom)
                const factor = oldZoom / newZoom;

              cam.x = piv.x - (piv.x - cam.x) * factor;
              cam.y = piv.y - (piv.y - cam.y) * factor;
            }
            updateViewBox(this.el, this.world, cam, this.scroller)
          }
          const onPointerMove = (evt) => {
                              if(evt.currentTarget.hasPointerCapture(evt.pointerId)) {
                                evt.stopPropagation()
                                {
                                  const {x: x,y: y} = evtToSvg(evt);

                                  cam.x -= x -offset.x;
                                  cam.y -= y -offset.y;
                                }
                                updateViewBox(this.el, this.world, cam, this.scroller)
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

          updateViewBox(this.el, this.world, cam, this.scroller)
        },
        destroyed() {
          this.el.removeEventListener('pointerdown', this.listeners.pointerdown);
          this.el.removeEventListener('pointermove', this.listeners.pointermove);
          this.el.removeEventListener('wheel', this.listeners.wheel)
          this.el.removeEventListener('dblclick', this.listeners.dblclick)
        },
        updated()  {
          updateViewBox(this.el, this.world, cam, this.scroller)
        }
      }
    </script>
    """
  end
end
