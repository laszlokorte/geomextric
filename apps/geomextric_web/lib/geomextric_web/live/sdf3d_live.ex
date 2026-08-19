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

          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
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
        <%= with {code, uniforms} <- SDF3DCompiler.compile(@layers, @box) do %>
          <div
            data-shader
            uniform-alpha={Float.round(@alpha, 3)}
            {uniforms |> Enum.map(fn {k,i,v} -> { "uniform-#{k}[#{i}]", v } end)}
          >
            <div
              :for={
                {{u, c}, i} <-
                  uniforms
                  |> Enum.group_by(fn {k, _, _} -> k end, fn {_, i, _} -> i end)
                  |> Enum.with_index()
              }
              id={"uniform-#{i}"}
            >
              uniform float {u}[{Enum.max(c) + 1}];
            </div>
            <div
              :for={{l, i} <- code |> String.split("pragma split") |> Enum.with_index()}
              id={"shader-line-#{i}"}
            >
              {l}
            </div>
          </div>
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
        const nr = regl({
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
                precision highp float;
                     uniform vec2 screen;

                     uniform vec3 camera_pos;
                     uniform vec3 camera_target;
                     struct SDFResult {
                                      float d;
                                      vec3 color;
                                  };

                     float sdf_box(vec3 p, vec3 b) {
                         vec3 q = abs(p) - b;

                         return length(max(q, 0.0)) +
                                min(max(q.x, max(q.y, q.z)), 0.0);
                     }

                     float sdf_rounded_box(
                         vec3 p,
                         vec3 b,
                         float r
                     ) {
                         vec3 q = abs(p) - b + r;

                         return length(max(q, 0.0))
                              + min(max(q.x, max(q.y, q.z)), 0.0)
                              - r;
                     }

                     float sdf_cylinder(
                         vec3 p,
                         float radius,
                         float half_height
                     ) {
                         vec2 d = abs(vec2(
                             length(p.xy),
                             p.z
                         )) - vec2(
                             radius,
                             half_height
                         );

                         return min(max(d.x, d.y), 0.0)
                              + length(max(d, 0.0));
                     }

                     float sdf_cone(
                         vec3 p,
                         vec3 apex,
                         vec3 axis,
                         float height,
                         float radius
                     ) {
                         vec3 q = p - apex;

                         float z = dot(q, axis);
                         float r = length(q - axis * z);

                         // Cone exists for -height <= z <= 0.
                         float k = radius / height;

                         // Distance to the conical surface in the axial/radial plane.
                         vec2 c = vec2(
                             r,
                             z
                         );

                         vec2 tip = vec2(0.0, 0.0);
                         vec2 base = vec2(radius, -height);

                         vec2 ba = base - tip;
                         vec2 pa = c - tip;

                         float h = clamp(
                             dot(pa, ba) / dot(ba, ba),
                             0.0,
                             1.0
                         );

                         float side = length(pa - ba * h);

                         // Sign: inside the cone.
                         float cone_r = r + k * z;

                         if (z <= 0.0 && z >= -height && cone_r < 0.0) {
                             side = -side;
                         }

                         // Base cap.
                         float cap = abs(r - radius);
                         if (z < -height) {
                             side = max(side, -z - height);
                         }

                         return side;
                     }

                     float sdf_segment_cylinder(
                         vec3 p,
                         vec2 a,
                         vec2 b,
                         float radius,
                         float half_height
                     ) {
                         vec2 ab = b - a;

                         float len = length(ab);

                         vec2 dir = ab / len;
                         vec2 normal = vec2(
                             -dir.y,
                             dir.x
                         );

                         vec2 rel = p.xy - a;

                         float along = dot(
                             rel,
                             dir
                         );

                         float side = dot(
                             rel,
                             normal
                         );

                         float radial =
                             length(vec2(
                                 side,
                                 p.z
                             )) - radius;

                         float axial = max(
                             -along,
                             along - len
                         );

                         return max(
                             radial,
                             axial
                         );
                     }

                   vec3 get_ray(vec2 uv) {
                       vec3 forward = normalize(
                         camera_target - camera_pos
                       );

                       vec3 up_hint = vec3(0.0, 1.0, 0.0);

                       vec3 right = normalize(
                           cross(forward, up_hint)
                       );

                       vec3 up = normalize(
                           cross(right, forward)
                       );

                       float aspect =
                           screen.x / screen.y;

                       return normalize(
                           forward +
                           right * uv.x * aspect +
                           up * -uv.y
                       );
                   }

                   ${shader.textContent}

                     vec3 estimate_normal(vec3 p) {
                       const float e = 0.001;

                       return normalize(vec3(
                           scene(p + vec3(e, 0.0, 0.0)).d -
                           scene(p - vec3(e, 0.0, 0.0)).d,

                           scene(p + vec3(0.0, e, 0.0)).d -
                           scene(p - vec3(0.0, e, 0.0)).d,

                           scene(p + vec3(0.0, 0.0, e)).d -
                           scene(p - vec3(0.0, 0.0, e)).d
                       ));
                   }
                   bool raymarch(
                       vec3 ro,
                       vec3 rd,
                       out vec3 hit
                   ) {
                       float t = 0.0;

                       for (int i = 0; i < 128; i++) {
                           vec3 p = ro + rd * t;

                           SDFResult result = scene(p);

                           if (result.d < 0.001) {
                               hit = p;
                               return true;
                           }

                           t += result.d;

                           if (t > 100000.0) {
                               break;
                           }
                       }

                       return false;
                   }

                          void main() {
                       vec2 uv =
                           gl_FragCoord.xy /
                           screen;

                       uv = uv * 2.0 - 1.0;

                       vec3 ro = camera_pos;
                       vec3 rd = get_ray(uv);

                       vec3 hit;

                       vec3 background = vec3(
                           uv / 2.0 + 0.5,
                           0.32
                       );

                       if (!raymarch(ro, rd, hit)) {
                           gl_FragColor = vec4(
                               background,
                               1.0
                           );

                           return;
                       }

                       SDFResult result = scene(hit);

                       vec3 normal = estimate_normal(hit);

                       vec3 light_dir = normalize(
                           vec3(-0.4, -0.5, 1.0)
                       );

                       float diffuse = max(
                           dot(normal, light_dir),
                           0.0
                       );

                       float ambient = 0.25;

                       vec3 color =
                           result.color *
                           (ambient + diffuse * 0.75);

                       gl_FragColor = vec4(
                           color,
                           1.0
                       );
                   }
                              `,
          uniforms: {
            cursor: regl.prop("cursor"),
            camera: regl.prop("camera"),

            camera_pos: regl.prop("camera_pos"),
            camera_target: regl.prop("camera_target"),
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

        return nr;
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
        const grouped = Object.groupBy(uniforms, ([name]) =>
          name.replace(/\[\d+\]$/, "")
        );

        const result = Object.fromEntries(
          Object.entries(grouped).map(([name, entries]) => [
            name,
            entries.map(([, value]) => value),
          ])
        );
        return result;
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
                const world = evtToWorld(evt);
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
            cam.zoom = Math.min(1, Math.max(-2, cam.zoom + dz));
            const newZoom = Math.exp(cam.zoom);
            const factor = oldZoom / newZoom;
            cam.x = px - (px - cam.x) * factor;
            cam.y = py - (py - cam.y) * factor;
          };
          const rotateBy = ({ dw, px, py }) => {
            cam.angle += dw / 3;
            const { x: nx, y: ny } = rotate(cam, { x: px, y: py }, -dw / 3);
            cam.x = nx;
            cam.y = ny;
          };
          const evtToWorld = (evt) => {
            const x = evt.clientX - window.innerWidth / 2;
            const y = evt.clientY - window.innerHeight / 2;

            const cos = Math.cos(cam.angle);
            const sin = Math.sin(cam.angle);

            const worldX = cam.x + (x * cos - y * -sin) * Math.exp(-cam.zoom);
            const worldY = cam.y + (y * cos - x * sin) * Math.exp(-cam.zoom);

            return {
              x: worldX,
              y: worldY,
            };
          };

          this.el.addEventListener(
            "pointerdown",
            (this.onpointerdown = (evt) => {
              if (evt.isPrimary && (evt.pointerType != "mouse" || evt.button == 0)) {
                evt.currentTarget.setPointerCapture(evt.pointerId);
                cam.base = evtToWorld(evt);
              }
            }),
          );

          window.addEventListener(
            "wheel",
            (this.onwheel = (evt) => {
              evt.preventDefault();
              const world = evtToWorld(evt);
              if (evt.altKey) {
                //  rotateBy({ dw: -evt.deltaY, px: world.x, py: world.y });
              } else {
                zoomBy({ dz: -evt.deltaY / 1000, px: world.x, py: world.y });
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
                  camera_pos: [cam.x, cam.y, 500 * Math.exp(-cam.zoom)],
                  camera_target: [cam.x * 0.7, cam.y * 0.7, 0],
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

            oldDraw.destroy();
            this.previousText = text;
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
