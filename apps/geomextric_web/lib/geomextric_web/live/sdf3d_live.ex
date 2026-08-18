defmodule GeomextricWeb.SDF3DLive do
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
            <.link navigate={~p"/sdf2d"}>
              2D
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
        <%= with {code, uniforms} <- SDF2DCompiler.compile(@layers, @box) do %>
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
                          uniform vec4 camera;

                          uniform vec2 resolution;

                          float sdSphere(vec3 p, float r) {
                              return length(p) - r;
                          }

                          float sdPlane(vec3 p) {
                              return p.y;
                          }

                          float scene(vec3 p) {
                              float sphere = sdSphere(p - vec3(0.0, 1.0, 0.0), 1.0);
                              float plane  = sdPlane(p);

                              return min(sphere, plane);
                          }

                          vec3 calcNormal(vec3 p) {
                              vec2 e = vec2(0.001, 0.0);

                              return normalize(vec3(
                                  scene(p + e.xyy) - scene(p - e.xyy),
                                  scene(p + e.yxy) - scene(p - e.yxy),
                                  scene(p + e.yyx) - scene(p - e.yyx)
                              ));
                          }

                          float raymarch(vec3 ro, vec3 rd) {
                              float t = 0.0;

                              for (int i = 0; i < 500; i++) {
                                  vec3 p = ro + rd * t;
                                  float d = scene(p);

                                  if (d < 0.001)
                                      return t;

                                  t += d;

                                  if (t > 100.0)
                                      break;
                              }

                              return -1.0;
                          }

                          float shadow(vec3 p, vec3 lightPos) {
                              vec3 rd = normalize(lightPos - p);
                              float maxT = length(lightPos - p);

                              float t = 0.01;

                              for (int i = 0; i < 100; i++) {
                                  vec3 q = p + rd * t;
                                  float d = scene(q);

                                  if (d < 0.001)
                                      return 0.0;

                                  t += d;

                                  if (t >= maxT)
                                      break;
                              }

                              return 1.0;
                          }

                          void main() {
                              vec2 uv = (gl_FragCoord.xy * 2.0 - resolution) / resolution.y;

                              // Camera
                              vec3 ro = vec3(0.0, 2.5, 5.0);
                              vec3 target = vec3(camera.x/screen.x*5.0/ camera.z , -camera.y/screen.y*5.0/ camera.z , 0.0);

                              vec3 forward = normalize(target - ro);
                              vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
                              vec3 up = cross(right, forward);

                              vec3 rd = normalize(
                                  forward * camera.z +
                                  uv.x * right +
                                  uv.y * up
                              );

                              float t = raymarch(ro, rd);

                              if (t < 0.0) {
                                  gl_FragColor = vec4(0.45, 0.77, 1.0, 1.0);
                                  return;
                              }

                              vec3 p = ro + rd * t;
                              vec3 n = calcNormal(p);

                              vec3 lightPos = vec3(3.0, 5.0, 4.0);
                              vec3 l = normalize(lightPos - p);

                              float diffuse = max(dot(n, l), 0.0);
                              float sh = shadow(p + n * 0.002, lightPos) + 0.3;

                              vec3 color = vec3(0.5, 0.15, 0.95);

                              // Ground gets a different material
                              if (abs(p.y) < 0.002)
                                  color = vec3(0.35);

                              vec3 ambient = vec3(0.12);
                              vec3 lighting = ambient + color * diffuse * sh;

                              gl_FragColor = vec4(lighting, 1.0);
                          }
                        `,
          uniforms: {
            cursor: regl.prop("cursor"),
            camera: regl.prop("camera"),
            screen: ({ viewport }) => [viewport.width, viewport.height],
            resolution: ({ viewport }) => [viewport.width, viewport.height],
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
            angle: 0,
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
                const world = evtToWorld(evt)
                cam.x -= world.x - cam.base.x;
                cam.y -= world.y - cam.base.y;
              }
            }),
          );
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
          const zoomBy = ({ dz, px, py }) => {
            const oldZoom = Math.exp(cam.zoom);
            cam.zoom = Math.min(2, Math.max(-2, cam.zoom + dz));
            const newZoom = Math.exp(cam.zoom);
            const factor = oldZoom / newZoom;
            cam.x = px - (px - cam.x) * factor;
            cam.y = py - (py - cam.y) * factor;
          };
          const rotateBy = ({ dw, px, py }) => {
                        cam.angle += dw / 3;
                        const { x: nx, y: ny } = rotate(
                          cam,
                          { x: px, y: py },
                          - dw / 3,
                        );
                        cam.x = nx;
                        cam.y = ny;
                      }
          const evtToWorld = (evt) => {
            const x = evt.clientX - window.innerWidth / 2;
            const y = evt.clientY - window.innerHeight / 2;

            const cos = Math.cos(cam.angle)
            const sin = Math.sin(cam.angle)

            const worldX = cam.x + (x * cos - y * -sin) * Math.exp(-cam.zoom);
            const worldY = cam.y + (y * cos - x * sin) * Math.exp(-cam.zoom);

            return {
              x: worldX,
              y: worldY,
            }
          }

          this.el.addEventListener(
            "pointerdown",
            (this.onpointerdown = (evt) => {
              evt.currentTarget.setPointerCapture(evt.pointerId);
              cam.base = evtToWorld(evt)
            }),
          );

          window.addEventListener(
            "wheel",
            (this.onwheel = (evt) => {
              evt.preventDefault();
              const world = evtToWorld(evt)
              if(evt.altKey) {
              //  rotateBy({ dw: -evt.deltaY, px: world.x, py: world.y });
              } else {
                zoomBy({ dz: -evt.deltaY / 1000, px: cam.x, py: cam.y });
              }
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
                  camera: [cam.x, cam.y, Math.exp(-cam.zoom), cam.angle],
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
          window.removeEventListener("wheel", this.onwheel, { passive: false });
        },
      };
    </script>
    """
  end
end
