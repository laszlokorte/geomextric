defmodule SDF2DCompiler do
  def compile(rects, bounding) do
    {parts, uniforms} =
      rects
      |> Enum.reverse()
      |> then(
        &[
          %{
            pos: {bounding.x, bounding.y, bounding.width, bounding.height},
            attrs: %{color: "#ffffff", radius: 0.0}
          },
          %{
            pos: {{bounding.x, 0}, {bounding.x + bounding.width, 0}},
            attrs: %{color: "#000000", thickness: -1.5, source_tip: false, target_tip: true}
          },
          %{
            pos: {{0, bounding.y}, {0, bounding.y + bounding.height}},
            attrs: %{color: "#000000", thickness: -1.5, source_tip: true, target_tip: false}
          }
          | &1
        ]
      )
      |> Enum.with_index()
      |> Enum.map_reduce([], fn
        {%{pos: {x, y, w, h}, attrs: %{radius: rad}} = rect, i}, uniforms ->
          id = "rect_#{i}"
          {r, g, b} = hex_to_rgb(rect.attrs.color)

          code = """
            {
              float d = sdf_rect(
                pos,
                u_#{id}_x + u_#{id}_rad,
                u_#{id}_y + u_#{id}_rad,
                u_#{id}_w - u_#{id}_rad*2.0,
                u_#{id}_h - u_#{id}_rad*2.0
              )- u_#{id}_rad;

              if (d < 0.0) {
                color = vec3(
                  u_#{id}_r,
                  u_#{id}_g,
                  u_#{id}_b
                );
              }
            }
          """

          uniforms =
            uniforms ++
              [
                {"u_#{id}_x", x},
                {"u_#{id}_y", y},
                {"u_#{id}_w", w},
                {"u_#{id}_h", h},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b},
                {"u_#{id}_rad", rad}
              ]

          {code, uniforms}

        {%{pos: {x, y}} = dot, i}, uniforms when is_number(x) ->
          id = "dot_#{i}"
          rad = dot.attrs.radius
          {r, g, b} = hex_to_rgb(dot.attrs.color)

          code = """
            {
              float d = sdf_rect(
                pos,
                u_#{id}_x,
                u_#{id}_y,
                0.0,
                0.0
              )- u_#{id}_rad;

              if (d < 0.0) {
                color = vec3(
                  u_#{id}_r,
                  u_#{id}_g,
                  u_#{id}_b
                );
              }
            }
          """

          uniforms =
            uniforms ++
              [
                {"u_#{id}_x", x},
                {"u_#{id}_y", y},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b},
                {"u_#{id}_rad", rad}
              ]

          {code, uniforms}

        {%{pos: {{x1, y1}, {x2, y2}}, attrs: %{source_tip: source_tip, target_tip: target_tip}} =
             line, i},
        uniforms ->
          id = "dot_#{i}"

          thickness = line.attrs.thickness
          {r, g, b} = hex_to_rgb(line.attrs.color)

          code = """
            {
            float st = u_#{id}_st;
            float tt = u_#{id}_tt;
            vec2 a = vec2(u_#{id}_x1, u_#{id}_y1);
            vec2 b = vec2(u_#{id}_x2, u_#{id}_y2);
            float thick = #{if(thickness < 0, do: "u_#{id}_thickness * 0.5 * camera.z", else: "u_#{id}_thickness * 0.5")};
              float d = sdf_segment(
                pos,
               a,
                b
              ) - thick;
            float tip_thick = #{if(thickness < 0, do: "2.0 * thick", else: "thick")};

              vec2 dir = normalize(b - a);

              d = min(
                  d,
                  sdf_arrowhead(pos, a, dir, tip_thick *6.0*st, tip_thick  * 4.0)
              );
              d = min(
                  d,
                  sdf_arrowhead(pos, b, -dir, tip_thick *6.0*tt, tip_thick  * 4.0)
              );

              if (d < 0.0) {
                color = vec3(
                  u_#{id}_r,
                  u_#{id}_g,
                  u_#{id}_b
                );
              }
            }
          """

          uniforms =
            uniforms ++
              [
                {"u_#{id}_x1", x1},
                {"u_#{id}_y1", y1},
                {"u_#{id}_x2", x2},
                {"u_#{id}_y2", y2},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b},
                {"u_#{id}_st", if(source_tip, do: 1.0, else: 0.0)},
                {"u_#{id}_tt", if(target_tip, do: 1.0, else: 0.0)},
                {"u_#{id}_thickness", abs(thickness)}
              ]

          {code, uniforms}

        _, uniforms ->
          {nil, uniforms}
      end)

    shader = """
    precision highp float;



    vec3 scene(vec2 pos, vec3 background) {
      vec3 color = background;

      #{Enum.join(parts, "\n")}

      return color;
    }
    """

    {shader, uniforms}
  end

  defp hex_to_rgb("#" <> hex) do
    {
      String.to_integer(binary_part(hex, 0, 2), 16) / 255,
      String.to_integer(binary_part(hex, 2, 2), 16) / 255,
      String.to_integer(binary_part(hex, 4, 2), 16) / 255
    }
  end
end
