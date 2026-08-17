defmodule GeomextricWeb.SDFLive do
  use GeomextricWeb, :live_view

  @topic "canvas"

  def mount(%{}, _, socket) do
    GeomextricWeb.Endpoint.subscribe(@topic)

    {:ok,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:alpha, 0.5)}
  end

  def handle_info({:inserted, new}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(:layers, &[new | &1])}
  end

  def handle_info({:moved, id, new_coords}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :layers,
       &Enum.map(&1, fn
         %{id: ^id} = old -> %{old | pos: new_coords}
         e -> e
       end)
     )}
  end

  def handle_info({:delete, id}, socket) do
    {:noreply,
     socket
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))
     |> update(
       :layers,
       &Enum.filter(&1, fn
         %{id: ^id} -> false
         _ -> true
       end)
     )
     |> update(
       :selection,
       &Enum.filter(&1, fn
         ^id -> false
         _ -> true
       end)
     )}
  end

  def handle_info(:reload, socket) do
    {:noreply,
     socket
     |> assign(
       :layers,
       Geomextric.Canvas.get_all(Geomextric.Canvas)
     )
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def handle_info(:clear, socket) do
    {:noreply,
     socket
     |> assign(:layers, [])
     |> assign(:box, Geomextric.Canvas.get_box(Geomextric.Canvas))}
  end

  def render(assigns) do
    ~H"""
    <style :type={GeomextricWeb.ColocatedScopedCSS}>
      :scope .viewport {
        display: block;
        border: 1px solid royalblue;
        width: 100%;
        box-sizing: border-box;
        height: 100%;
      }

      :scope {
        position: absolute;
        background: royalblue;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        padding: 0;
        margin: 0;
        width: 100%;
        height: 100%;
        display: grid;
        grid-template-columns: 100%;
        grid-template-rows: 100%;
        box-sizing: border-box;
        place-content: stretch;
        place-items: stretch;
      }

      :scope .full {
        margin: 0;
      }
      :scope [data-shader] {
        display: none;
      }
    </style>
    <div width="100" height="100" id="canvas" phx-hook=".Canvas">
      <%= with {code, uniforms} <- SDFCompiler.compile(@layers) do %>
        <span
          data-shader
          uniform-alpha={Float.round(@alpha, 3)}
          {uniforms |> Enum.map(fn {k,v} -> { "uniform-#{k}", v } end)}
        >{"
          #{uniforms |> Enum.map(&elem(&1, 0)) |> Enum.map(&"uniform float #{&1};") |> Enum.join("\n")}
          #{code}
           "}</span>
      <% end %>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Canvas">
      import createRegl from "@/vendor/regl.js";

      function makeDraw(regl, el, reglCanvas) {
        const shader = el.querySelector("[data-shader]");
        const uniforms = [];
        for (const attr of shader.attributes) {
          if (attr.name.startsWith("uniform-")) {
            const name = attr.name.slice("uniform-".length);
            uniforms.push(name);
          }
        }
        console.log("recompile shader");
        return regl({
          vert: `
                        precision mediump float;

                        attribute vec2 position;
                        varying vec2 pos;

                        void main() {
                          pos = (position + 1.0) / 2.0;
                          gl_Position = vec4(position, 0.0, 1.0);
                        }
                      `,

          frag: `
                        precision mediump float;
                        varying vec2 pos;
                        uniform vec2 cursor;
                        uniform vec2 screen;

                        ${el.textContent}

                        void main() {
                          float c = length((pos)*screen - vec2(cursor.x, screen.y - cursor.y)) > 6.0 ? 1.0: 0.0;
                          gl_FragColor = vec4(scene(vec2(pos.x-0.5, 0.5 -pos.y)*screen), c);
                        }
                      `,
          uniforms: {
            cursor: regl.prop("cursor"),
            screen: ({ viewport }) => [viewport.width, viewport.height],
            ...Object.fromEntries(uniforms.map((u) => [u, regl.prop(u)])),
          },

          attributes: {
            position: [
              [-1, -1],
              [1, -1],
              [1, 1],
              [-1, 1],
            ],
          },

          elements: [
            [0, 1, 2],
            [0, 2, 3],
          ],
        });
      }

      function collectUniforms(el) {
        const shader = el.querySelector("[data-shader]");
        const uniforms = [];
        for (const attr of shader.attributes) {
          if (attr.name.startsWith("uniform-")) {
            const name = attr.name.slice("uniform-".length);
            uniforms.push([name, parseFloat(attr.value)]);
          }
        }
        return Object.fromEntries(uniforms);
      }

      export default {
        mounted() {
          this.previousText = this.el.textContent;
          this.reglCanvas = document.createElement("canvas");
          this.el.appendChild(this.reglCanvas);
          this.reglCanvas.classList.add("viewport");
          const regl = (this.regl = createRegl({
            canvas: this.reglCanvas,
            attributes: {
              antialias: true,
              stencil: false,
              premultipliedAlpha: false,
            },
          }));
          this.draw = makeDraw(this.regl, this.el, this.reglCanvas);
          this.uniforms = collectUniforms(this.el);
          const reglCamera = regl({
            context: {
              viewport: () => ({
                x: 0,
                y: 0,
                width: this.reglCanvas.clientWidth,
                height: this.reglCanvas.clientHeight,
              }),
            },

            uniforms: {
              view: this.regl.context("view"),
              projection: this.regl.context("projection"),
              viewport: this.regl.context("viewport"),
              viewNormal: this.regl.context("viewNormal"),
            },
          });

          const cursor = { x: -1000, y: -1000 };
          window.addEventListener("pointermove", (evt) => {
            cursor.x = evt.clientX;
            cursor.y = evt.clientY;
          });

          this.tick = regl.frame(() => {
            const width = Math.round(
              this.reglCanvas.clientWidth * window.devicePixelRatio,
            );
            const height = Math.round(
              this.reglCanvas.clientHeight * window.devicePixelRatio,
            );

            if (
              this.reglCanvas.width !== width ||
              this.reglCanvas.height !== height
            ) {
              this.reglCanvas.width = width;
              this.reglCanvas.height = height;
              regl.poll();
            }

            regl.clear({
              color: [0.4, 0.4, 0.4, 1],
              stencil: 1,
              depth: 1.0,
            });
            try {
              reglCamera(() => {
                this.draw({
                  ...this.uniforms,
                  cursor: [cursor.x, cursor.y],
                });
              });
            } catch (e) {
              console.error(e);
              this.tick.cancel();
            }
          });
        },

        updated() {
          const oldDraw = this.draw;

          const text = this.el.textContent;
          if (text !== this.previousText) {
            this.draw = makeDraw(this.regl, this.el, this.reglCanvas);

            this.previousText = this.el.textContent;

            oldDraw.destroy();
          }

          this.uniforms = collectUniforms(this.el);

          this.el.appendChild(this.reglCanvas);
        },

        destroyed() {
          if (this.regl) {
            this.tick.cancel();
            this.draw.destroy();

            this.el.removeChild(this.reglCanvas);
            this.regl.destroy();
          }
        },
      };
    </script>
    """
  end
end
