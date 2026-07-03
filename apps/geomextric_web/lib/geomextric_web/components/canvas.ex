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
        background: #58b;
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
            preserveAspectRatio="xMidYMid meet"
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
                  vector-effect="non-scaling-stroke"
                  shape-rendering="geometricPrecision"
                  d="M 0 0 L 10 0 M 20 0 L 10 0 M 0 0 L 0 10 M 0 20 L 0 10"
                  stroke-dasharray="2 2"
                  fill="none"
                  stroke="#abc8"
                  stroke-width="1"
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
                  vector-effect="non-scaling-stroke"
                  shape-rendering="geometricPrecision"
                  d="M 0 0 L 20 0 M 40 0 L 20 0 M 0 0 L 0 20 M 0 40 L 0 20"
                  fill="none"
                  stroke-dasharray="2 2"
                  stroke="#cdea"
                  stroke-width="2"
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
            />
            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="url(#grid)"
              opacity="0.8"
            />

            <rect
              x={@box.x}
              y={@box.y}
              width={@box.width}
              height={@box.height}
              fill="url(#grid-sec)"
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
      let skipScroll = false
      function updateViewBox(e, r, cam, scroller) {
      if(r) {
        r.setAttribute("transform", `rotate(${cam.angle} ${cam.x} ${cam.y})`)
      }
        e.setAttribute("viewBox", `${cam.x-cam.screen.width/2 * Math.exp(-cam.zoom)} ${cam.y-cam.screen.height/2 * Math.exp(-cam.zoom)}
          ${cam.screen.width * Math.exp(-cam.zoom)} ${cam.screen.height * Math.exp(-cam.zoom)}
          `)

        r.style.setProperty('--cam-scale', Math.exp( -cam.zoom))
        r.style.setProperty('--cam-scale-clamped', Math.exp(Math.max(-2,Math.min(2, -cam.zoom))))
        r.style.setProperty('--cam-scale-max', Math.exp(Math.max(-2, -cam.zoom)))
        r.style.setProperty('--cam-scale-min', Math.exp(Math.min(2, -cam.zoom)))
        const logScale = Math.pow(2, Math.round((-cam.zoom)/Math.log(2)) + 2)
        scroller.querySelectorAll('pattern').forEach(g => g.setAttribute("patternTransform", `scale(${logScale})`))

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

               const scrollWidth  = boundingX * Math.exp(cam.zoom) + scroller.clientWidth * 2
               const scrollHeight = boundingY * Math.exp(cam.zoom) + scroller.clientHeight * 2
               if(!isNaN(scrollWidth) && !isNaN(scrollHeight)) {

                 scroller.style.setProperty('--scroll-width',  scrollWidth + 'px')
                 scroller.style.setProperty('--scroll-height',  scrollHeight + 'px')
        }
        const newScrollLeft = (0.5 * scroller.clientWidth +
                (boundingX )  * Math.exp(cam.zoom) / 2
                + ((cam.x-cX) * cos - (cam.y-cY) * sin) *  Math.exp(cam.zoom))
        const newScrollTop = (0.5 * scroller.clientHeight
                   + (boundingY ) * Math.exp(cam.zoom) / 2
                   + ((cam.y-cY) * cos + (cam.x-cX) * sin) *  Math.exp(cam.zoom))

        skipScroll = true
        scroller.scrollTo({
                 left: newScrollLeft,
                 top: newScrollTop,
                 behavior: "instant",
               });
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
          const onScroll = (evt) => {

            if(skipScroll) {

            skipScroll = false
            return
          }

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

            }
            this.scroller.addEventListener('scroll', onScroll, {passive: true})
            const evtToSvg = (evt) => {
              point.x = evt.clientX;
              point.y = evt.clientY;
              const svgGlobal = point.matrixTransform(this.world.getScreenCTM().inverse());
              return{
                  x: svgGlobal.x,
                  y: svgGlobal.y,
                }
          }

          const wr = this.world.viewBox.baseVal.width / window.innerWidth * 1
          const hr = this.world.viewBox.baseVal.height / window.innerHeight * 1
          cam.zoom = -Math.log(Math.max(wr, hr))
          cam.x = this.el.viewBox.baseVal.width / 2 + this.el.viewBox.baseVal.x
          cam.y = this.el.viewBox.baseVal.height / 2 + this.el.viewBox.baseVal.y

          const resize = () => {
            cam.screen= {width: window.innerWidth, height: window.innerHeight}

            updateViewBox(this.el, this.world, cam, this.scroller)
          }
          resize()

          updateViewBox(this.el, this.world, cam, this.scroller)
          const onWheel =  (evt) => {
            const piv = evtToSvg(evt)

            if(evt.altKey) {
            evt.preventDefault()
                  const {x: nx, y: ny} = rotate(cam, piv, -Math.PI/180*evt.deltaY/10)
              cam.angle += evt.deltaY/10
              cam.x = nx
              cam.y = ny

              updateViewBox(this.el, this.world, cam, this.scroller)
            } else if(evt.ctrlKey) {
              evt.preventDefault()
            const oldZoom = Math.exp(cam.zoom)
              cam.zoom -=  evt.deltaY/1000

              cam.zoom = Math.max(-8, Math.min(8, cam.zoom))
              const newZoom = Math.exp(cam.zoom)
                const factor = oldZoom / newZoom;

              cam.x = piv.x - (piv.x - cam.x) * factor;
              cam.y = piv.y - (piv.y - cam.y) * factor;

              updateViewBox(this.el, this.world, cam, this.scroller)
            }
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
          const onDrop = (evt) => {
                    this.pushEvent("create", evtToSvg(evt))
                  }
          const svg = this.el;
          const point = svg.createSVGPoint();

          const offset = {x:0,y:0}
          this.el.addEventListener('pointerdown', onPointerDown);
          this.el.addEventListener('pointermove', onPointerMove);
          this.el.addEventListener('wheel', onWheel)
          this.el.addEventListener('click', onDblClick )
          this.el.addEventListener('drop', onDrop )

          window.addEventListener('resize', resize)

          this.listeners = {
            pointerdown: onPointerDown,
            pointermove: onPointerMove,
            wheel: onWheel,
            click: onDblClick,
            scroll: onScroll,
            drop: onDrop,
            resize
          }

          updateViewBox(this.el, this.world, cam, this.scroller)
        },
        destroyed() {
          this.el.removeEventListener('pointerdown', this.listeners.pointerdown);
          this.el.removeEventListener('pointermove', this.listeners.pointermove);
          this.el.removeEventListener('wheel', this.listeners.wheel)
          this.el.removeEventListener('click', this.listeners.dblclick)
          this.el.removeEventListener('drop', this.listeners.drop)

          this.scroller.removeEventListener('scroll', this.listeners.scroll, {passive: true})

          window.removeEventListener('resize', resize)
        },
        updated()  {
          updateViewBox(this.el, this.world, cam, this.scroller)
        }
      }
    </script>
    """
  end
end
