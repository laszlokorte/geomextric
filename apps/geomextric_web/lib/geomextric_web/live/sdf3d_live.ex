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
      :scope .scene [data-scene] {
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
        <div id="sdf3d-scene-data" hidden data-scene>
          <div
            :for={entry <- SDF3DCompiler.encode_entries(@layers, @box)}
            :key={entry.id}
            id={entry.id}
            data-shape={Jason.encode!(entry.data)}
          >
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Canvas">
      function compileShader(gl, type, source) {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);

        return shader;
      }

      function prepareDraw(gl, vertexShader, positionBuffer, extension) {
        const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource());
        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);
        gl.deleteShader(fragmentShader);
        return {
          ready: () => !extension || gl.getProgramParameter(program, extension.COMPLETION_STATUS_KHR),
          destroy: () => gl.deleteProgram(program),
          finish() {
            // Status and location queries can block, so defer them until completion.
            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
              const message = gl.getProgramInfoLog(program);
              gl.deleteProgram(program);
              throw new Error(`Shader linking failed: ${message}`);
            }

            const position = gl.getAttribLocation(program, "position");
            const locations = new Map();
            const location = (name) => {
              if (!locations.has(name)) locations.set(name, gl.getUniformLocation(program, name));
              return locations.get(name);
            };
            const draw = (scene, cameraPosition, cameraTarget) => {
              gl.useProgram(program);
              gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
              gl.enableVertexAttribArray(position);
              gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
              gl.uniform2f(location("screen"), gl.drawingBufferWidth, gl.drawingBufferHeight);
              gl.uniform3fv(location("camera_pos"), cameraPosition);
              gl.uniform3fv(location("camera_target"), cameraTarget);
              gl.activeTexture(gl.TEXTURE0);
              gl.bindTexture(gl.TEXTURE_2D, scene.texture);
              gl.uniform1i(location("shape_data"), 0);
              gl.uniform1i(location("shape_count"), scene.count);
              gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
            };
            draw.destroy = () => gl.deleteProgram(program);
            return draw;
          },
        };
      }

      const vertexSource = `#version 300 es

                                        precision mediump float;

                                        in vec2 position;

                                        void main() {

                                          gl_Position = vec4(position, 0.0, 1.0);
                                        }
                                      `;

      function fragmentSource() {
        return `#version 300 es
                        precision highp float;
                        precision highp int;
                        uniform highp sampler2D shape_data;
                        uniform int shape_count;
                        out vec4 fragment_color;
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

                           SDFResult scene(vec3 p) {
                               SDFResult result;
                               result.d = 1e20;
                               result.color = vec3(1.0);
                               for (int i = 0; i < shape_count; i++) {
                                 vec4 a = texelFetch(shape_data, ivec2(0, i), 0);
                                 vec4 b = texelFetch(shape_data, ivec2(1, i), 0);
                                 vec4 color = texelFetch(shape_data, ivec2(2, i), 0);
                                 float d;
                                 if (a.x < 0.5) {
                                   vec3 half_size = vec3(a.w, b.x, b.y) * 0.5;
                                   d = sdf_rounded_box(p - vec3(a.yz + half_size.xy, half_size.z), half_size, b.z);
                                 } else if (a.x < 1.5) {
                                   d = sdf_cylinder(p - vec3(a.yz, b.x * 0.5), a.w, b.x * 0.5);
                                 } else {
                                   vec2 start = a.yz;
                                   vec2 end = vec2(a.w, b.x);
                                   d = sdf_segment_cylinder(p, start, end, b.y, b.z * 0.5);
                                   vec2 direction = normalize(end - start);
                                   // Disabled tips must not evaluate a zero-height cone.
                                   if (b.w > 0.0) {
                                     d = min(d, sdf_cone(p, vec3(start - direction * 3.0 * b.y, 0.0),
                                       vec3(-direction, 0.0), b.y * 6.0, b.y * 3.0));
                                   }
                                   if (color.w > 0.0) {
                                     d = min(d, sdf_cone(p, vec3(end + direction * 3.0 * b.y, 0.0),
                                       vec3(direction, 0.0), b.y * 6.0, b.y * 3.0));
                                   }
                                 }
                                 if (d < result.d) {
                                   result.d = d;
                                   result.color = color.rgb;
                                 }
                               }
                               return result;
                             }

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
                                   fragment_color = vec4(
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

                               fragment_color = vec4(
                                   color,
                                   1.0
                               );
                           }
                                      `;
      }

      function uploadScene(gl, el, scene) {
        const records = Array.from(el.querySelectorAll("[data-scene] > [data-shape]"),
          (element) => JSON.parse(element.dataset.shape));
        const height = Math.max(1, records.length);
        if (height > scene.maxHeight) {
          throw new Error(`Scene exceeds this device's texture limit (${height} shapes)`);
        }
        const data = new Float32Array(height * 16);
        records.forEach((record, index) => data.set(record, index * 16));
        gl.bindTexture(gl.TEXTURE_2D, scene.texture);
        if (scene.height !== height) {
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, 4, height, 0, gl.RGBA, gl.FLOAT, data);
          scene.height = height;
        } else {
          gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 4, height, gl.RGBA, gl.FLOAT, data);
        }
        scene.count = records.length;
      }

      export default {
        mounted() {
          this.canvas = document.createElement("canvas");
          this.el.appendChild(this.canvas);
          this.canvas.classList.add("viewport");
          const gl = this.gl = this.canvas.getContext("webgl2", { antialias: true });
          if (!gl) {
            this.canvas.remove();
            this.el.append("WebGL 2 is required for the 3D scene.");
            return;
          }
          this.parallelCompile = gl.getExtension("KHR_parallel_shader_compile");
          this.vertexShader = compileShader(gl, gl.VERTEX_SHADER, vertexSource);
          this.positionBuffer = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, this.positionBuffer);
          gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, 1, 1, -1, 1]), gl.STATIC_DRAW);
          this.pendingDraw = prepareDraw(gl, this.vertexShader, this.positionBuffer, this.parallelCompile);
          this.scene = {
            texture: gl.createTexture(), count: 0, height: 0,
            maxHeight: gl.getParameter(gl.MAX_TEXTURE_SIZE),
          };
          gl.bindTexture(gl.TEXTURE_2D, this.scene.texture);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
          uploadScene(gl, this.el, this.scene);

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
          const frame = () => {
            if (this.pendingDraw?.ready()) {
              const pending = this.pendingDraw;
              this.pendingDraw = null;
              try {
                const draw = pending.finish();
                this.draw?.destroy();
                this.draw = draw;
              } catch (error) {
                console.error(error);
              }
            }
            const width = Math.round(this.canvas.clientWidth);
            const height = Math.round(this.canvas.clientHeight);

            if (
              this.canvas.width !== width ||
              this.canvas.height !== height
            ) {
              this.canvas.width = width;
              this.canvas.height = height;
              gl.viewport(0, 0, width, height);
            }

            gl.viewport(0, 0, width, height);
            gl.clearColor(0.4, 0.4, 0.4, 1);
            gl.clear(gl.COLOR_BUFFER_BIT);
            try {
              this.draw?.(
                this.scene,
                [cam.x, cam.y, 500 * Math.exp(-cam.zoom)],
                [cam.x * 0.7, cam.y * 0.7, 0],
              );
            } catch (e) {
              console.error(e);
              return;
            }
            this.tick = requestAnimationFrame(frame);
          };
          this.tick = requestAnimationFrame(frame);
        },

        updated() {
          if (!this.gl) return;
          try {
            uploadScene(this.gl, this.el, this.scene);
          } catch (error) {
            console.error(error);
          }

          this.el.appendChild(this.canvas);
        },

        destroyed() {
          cancelAnimationFrame(this.tick);
          if (this.gl) {
            this.pendingDraw?.destroy();
            this.draw?.destroy();
            this.gl.deleteTexture(this.scene.texture);
            this.gl.deleteBuffer(this.positionBuffer);
            this.gl.deleteShader(this.vertexShader);
          }
          this.canvas.remove();

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
