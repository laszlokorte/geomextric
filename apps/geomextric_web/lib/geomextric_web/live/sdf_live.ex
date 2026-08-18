defmodule GeomextricWeb.SDFLive do
  use GeomextricWeb, :live_view

  import GeomextricWeb.Menu
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

  def handle_event("close", %{}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/")}
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

      :scope .scene {
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
      :scope .scene [data-shader] {
        display: none;
      }
      :scope.page {
        display: grid;
        grid-template-rows: [bar-start] auto [bar-end main-start] 1fr [main-end];
        grid-template-columns: [bar-start main-start] 1fr [bar-end main-end];
        position: absolute;
        inset: 0;
      }
    </style>

    <div class="page">
      <div class="menu-bar">
        <.menu items={[
          %{
            label: "File",
            items: [
              %{
                label: "close",
                send: "close"
              }
            ]
          }
        ]}>
          <:head>
            <.link navigate={~p"/scene"}>
              3D
            </.link>
          </:head>
        </.menu>
      </div>
      <div
        class="scene"
        width="100"
        height="100"
        id="canvas"
        phx-hook=".Canvas"
        data-bounds-x={@box.x}
        data-bounds-y={@box.y}
        data-bounds-w={@box.width}
        data-bounds-h={@box.height}
      >
        <%= with {code, uniforms} <- SDFCompiler.compile(@layers, @box) do %>
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
                          uniform vec3 focus;

                          ${el.textContent}

                          void main() {
                            float c = length((pos)*screen - vec2(cursor.x, screen.y - cursor.y)) > 6.0 ? 1.0: 0.0;
                            gl_FragColor = vec4(
                              scene(
                                vec2(pos.x-0.5, 0.5 -pos.y)*focus.z*screen + focus.xy,
                                pos
                              ), c);
                          }
                        `,
          uniforms: {
            cursor: regl.prop("cursor"),
            focus: regl.prop("focus"),
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

          const boundsX = parseFloat(this.el.dataset.boundsX);
          const boundsY = parseFloat(this.el.dataset.boundsY);
          const boundsW = parseFloat(this.el.dataset.boundsW);
          const boundsH = parseFloat(this.el.dataset.boundsH);

          const cursor = { x: -1000, y: -1000 };
          const cam = {
            x: boundsX + boundsW / 2 || 0,
            y: boundsY + boundsH / 2 || 0,
            zoom:
              Math.log(Math.min(this.el.clientWidth, this.el.clientHeight)) -
                Math.log(Math.max(boundsW, boundsH)) -
                0.1 || 0,
          };

          window.addEventListener(
            "pointermove",
            (this.onpointermoveWindow = (evt) => {
              cursor.x = evt.clientX;
              cursor.y = evt.clientY;
            }),
          );
          this.el.addEventListener(
            "pointermove",
            (this.onpointermove = (evt) => {
              if (evt.currentTarget.hasPointerCapture(evt.pointerId)) {
                cam.x -= (evt.clientX - cam.bx) * Math.exp(-cam.zoom);
                cam.y -= (evt.clientY - cam.by) * Math.exp(-cam.zoom);
                cam.bx = evt.clientX;
                cam.by = evt.clientY;
              }
            }),
          );
          const zoomBy = ({ dz, px, py }) => {
            const oldZoom = Math.exp(cam.zoom);
            cam.zoom = cam.zoom + dz;
            const newZoom = Math.exp(cam.zoom);
            const factor = oldZoom / newZoom;
            cam.x = px - (px - cam.x) * factor;
            cam.y = py - (py - cam.y) * factor;
          };
          this.el.addEventListener(
            "pointerdown",
            (this.onpointerdown = (evt) => {
              evt.currentTarget.setPointerCapture(evt.pointerId);
              cam.bx = evt.clientX;
              cam.by = evt.clientY;
            }),
          );

          window.addEventListener(
            "wheel",
            (this.onwheel = (evt) => {
              evt.preventDefault();
              const x = evt.clientX - window.innerWidth / 2;
              const y = evt.clientY - window.innerHeight / 2;

              const worldX = cam.x + x * Math.exp(-cam.zoom);
              const worldY = cam.y + y * Math.exp(-cam.zoom);
              zoomBy({ dz: -evt.deltaY / 1000, px: worldX, py: worldY });
            }),
            { passive: false },
          );
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
                  focus: [cam.x, cam.y, Math.exp(-cam.zoom)],
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

          window.removeEventListener("pointermove", this.onpointermoveWindow);
          this.el.removeEventListener("pointermove", this.onpointermove);
          this.el.removeEventListener("pointerdown", this.onpointerdown);
          window.removeEventListener("wheel", this.onwheel);
        },
      };
    </script>
    """
  end
end
