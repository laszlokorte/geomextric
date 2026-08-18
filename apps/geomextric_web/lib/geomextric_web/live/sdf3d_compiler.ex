defmodule SDF3DCompiler do
  def compile(shapes, bounding) do
    {parts, uniforms} =
      shapes
      |> Enum.reverse()
      |> then(fn shapes ->
        [
          %{
            pos: {bounding.x, bounding.y, bounding.width, bounding.height},
            attrs: %{
              color: "#ffffff",
              radius: 0.0,
              height: 1
            }
          },
          %{
            pos: {{bounding.x, 0}, {bounding.x + bounding.width, 0}},
            attrs: %{color: "#000000", thickness: -15.5, source_tip: false, target_tip: true}
          },
          %{
            pos: {{0, bounding.y}, {0, bounding.y + bounding.height}},
            attrs: %{color: "#000000", thickness: -15.5, source_tip: true, target_tip: false}
          }
          | shapes
        ]
      end)
      |> Enum.with_index()
      |> Enum.map_reduce([], fn
        {%{pos: {x, y, w, h}, attrs: attrs}, i}, uniforms ->
          id = "rect_#{i}"

          {r, g, b} = hex_to_rgb(attrs.color)

          radius = Map.get(attrs, :radius, 0.0)
          height = Map.get(attrs, :height, 50.0)

          code = """
          {
              vec3 q = p - vec3(
                  u_#{id}_x + u_#{id}_w * 0.5,
                  u_#{id}_y + u_#{id}_h * 0.5,
                  u_#{id}_height * 0.5
              );

              float d = sdf_rounded_box(
                  q,
                  vec3(
                      u_#{id}_w * 0.5,
                      u_#{id}_h * 0.5,
                      u_#{id}_height * 0.5
                  ),
                  u_#{id}_radius
              );

              if (d < result.d) {
                  result.d = d;
                  result.color = vec3(
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
                {"u_#{id}_radius", radius},
                {"u_#{id}_height", height},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b}
              ]

          {code, uniforms}

        {%{pos: {x, y}, attrs: attrs}, i}, uniforms
        when is_number(x) ->
          id = "dot_#{i}"

          radius = Map.get(attrs, :radius, 1.0)
          height = Map.get(attrs, :height, radius * 2.0)

          {r, g, b} = hex_to_rgb(attrs.color)

          code = """
          {
              vec3 q = p - vec3(
                  u_#{id}_x,
                  u_#{id}_y,
                  u_#{id}_height * 0.5
              );

              float d = sdf_cylinder(
                  q,
                  u_#{id}_radius,
                  u_#{id}_height * 0.5
              );

              if (d < result.d) {
                  result.d = d;
                  result.color = vec3(
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
                {"u_#{id}_radius", radius},
                {"u_#{id}_height", height},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b}
              ]

          {code, uniforms}

        {%{
           pos: {{x1, y1}, {x2, y2}},
           attrs: attrs
         }, i},
        uniforms ->
          id = "line_#{i}"

          thickness = abs(Map.get(attrs, :thickness, 1.0))
          height = Map.get(attrs, :height, thickness)
          source_tip = Map.get(attrs, :source_tip, thickness)
          target_tip = Map.get(attrs, :target_tip, thickness)

          {r, g, b} = hex_to_rgb(attrs.color)

          code = """
          {
              vec2 a = vec2(
                  u_#{id}_x1,
                  u_#{id}_y1
              );

              vec2 b = vec2(
                  u_#{id}_x2,
                  u_#{id}_y2
              );

              float d = sdf_segment_cylinder(
                  p,
                  a,
                  b,
                  u_#{id}_radius,
                  u_#{id}_height * 0.5
              );
              vec2 dir2 = normalize(b - a);

                 vec3 axis = vec3(
                     dir2,
                     0.0
                 );
                 float arrow_d = min(
                 sdf_cone(
                      p,
                      vec3(a + -dir2 * 3.0 * u_#{id}_radius* u_#{id}_st, 0.0),
                      vec3(-dir2, 0.0),
                      u_#{id}_radius * 6.0* u_#{id}_st,
                      u_#{id}_radius * 3.0* u_#{id}_st
                  ),
                  sdf_cone(
                      p,
                      vec3(b + dir2 * 3.0 * u_#{id}_radius* u_#{id}_tt, 0.0),
                      vec3(dir2, 0.0),
                      u_#{id}_radius * 6.0* u_#{id}_tt,
                      u_#{id}_radius * 3.0* u_#{id}_tt
                  )
                 );

                 d = min(d, arrow_d);

              if (d < result.d) {
                  result.d = d;
                  result.color = vec3(
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
                {"u_#{id}_radius", thickness * 0.5},
                {"u_#{id}_height", height},
                {"u_#{id}_st", if(source_tip, do: 1.0, else: 0.0)},
                {"u_#{id}_tt", if(target_tip, do: 1.0, else: 0.0)},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b}
              ]

          {code, uniforms}

        _, uniforms ->
          {nil, uniforms}
      end)

    shader = """

    SDFResult scene(vec3 p) {
        SDFResult result;

        result.d = 1e20;
        result.color = vec3(1.0);

        #{Enum.join(parts, "\n")}

        return result;
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
