defmodule GeomextricWeb.Circle do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :x, :float, default: 0.0, doc: "center x"
  attr :y, :float, default: 0.0, doc: "center y"
  attr :r, :float, default: 0.0, doc: "radius"
  attr :fill, :string, default: "red", doc: "fill color"
  attr :id, :string, default: "circle", doc: "id"

  def circle(assigns) do
    ~H"""
    <circle cx={@x} cy={@y} r={@r} fill="rebeccapurple"></circle>
    <circle
      id={@id}
      phx-hook=".Circle"
      cx={@x}
      cy={@y}
      r={@r}
      fill={@fill}
      opacity="0.1"
    />
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
            (x,y) =>  this.pushEvent("move", {id: this.el.id, x,y}), 60,
            debounce((x,y) => this.pushEvent("move", {id: this.el.id, x,y}), 500)
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
                      if(evt.isPrimary && evt.button === 0) {

                        evt.stopPropagation()
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

                        this.el.setAttribute('cx', x);
                        this.el.setAttribute('cy', y );
                      }
                    }
                    const onPointerUp = (evt) => {
                                        if(evt.currentTarget.hasPointerCapture(evt.pointerId)) {
                                        evt.stopPropagation()
                                          const {x: px,y: py} = evtToSvg(evt);

                                          const x = px - offset.x
                                          const y = py - offset.y
                                          move(x,y)

                                        }
                                      }
          this.el.addEventListener('pointerdown', onPointerDown);
          this.el.addEventListener('click', evt => evt.stopPropagation());
          this.el.addEventListener('pointermove', onPointerMove);
          this.el.addEventListener('pointerup', onPointerUp);
          this.listeners = {
                  pointerdown: onPointerDown,
                  pointermove: onPointerMove,
                  pointerup: onPointerUp,
                }
        },
        destroyed() {
          this.el.removeEventListener('pointerdown', this.listeners.pointerdown);
          this.el.removeEventListener('pointermove', this.listeners.pointermove);
          this.el.removeEventListener('pointerup', this.listeners.pointerup);
        }
      }
    </script>
    """
  end
end
