defmodule SDF3DCompiler do
  def compile(shapes, bounding) do
    {parts, {_, uniforms}} =
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
      |> Enum.map_reduce(
        {%{
           rect: 0,
           dot: 0,
           line: 0
         }, []},
        fn
          {%{pos: {x, y, w, h}, attrs: attrs}, _}, {kinds, uniforms} ->
            kind = "rect"
            i = Map.get(kinds, :rect, 0)

            {r, g, b} = hex_to_rgb(attrs.color)

            radius = Map.get(attrs, :radius, 0.0)
            height = Map.get(attrs, :height, 50.0)

            code = """
            {
                vec3 q = p - vec3(
                    u_#{kind}_x[#{i}] + u_#{kind}_w[#{i}] * 0.5,
                    u_#{kind}_y[#{i}] + u_#{kind}_h[#{i}] * 0.5,
                    u_#{kind}_height[#{i}] * 0.5
                );

                float d = sdf_rounded_box(
                    q,
                    vec3(
                        u_#{kind}_w[#{i}] * 0.5,
                        u_#{kind}_h[#{i}] * 0.5,
                        u_#{kind}_height[#{i}] * 0.5
                    ),
                    u_#{kind}_radius[#{i}]
                );

                if (d < result.d) {
                    result.d = d;
                    result.color = vec3(
                        u_#{kind}_r[#{i}],
                        u_#{kind}_g[#{i}],
                        u_#{kind}_b[#{i}]
                    );
                }
            }
            """

            uniforms =
              uniforms ++
                [
                  {"u_#{kind}_x", i, x},
                  {"u_#{kind}_y", i, y},
                  {"u_#{kind}_w", i, w},
                  {"u_#{kind}_h", i, h},
                  {"u_#{kind}_radius", i, radius},
                  {"u_#{kind}_height", i, height},
                  {"u_#{kind}_r", i, r},
                  {"u_#{kind}_g", i, g},
                  {"u_#{kind}_b", i, b}
                ]

            {code, {Map.update(kinds, :rect, 0, &(&1 + 1)), uniforms}}

          {%{pos: {x, y}, attrs: attrs}, _}, {kinds, uniforms}
          when is_number(x) ->
            kind = "dot"

            i = Map.get(kinds, :dot, 0)

            radius = Map.get(attrs, :radius, 1.0)
            height = Map.get(attrs, :height, radius * 2.0)

            {r, g, b} = hex_to_rgb(attrs.color)

            code = """
            {
                vec3 q = p - vec3(
                    u_#{kind}_x[#{i}],
                    u_#{kind}_y[#{i}],
                    u_#{kind}_height[#{i}] * 0.5
                );

                float d = sdf_cylinder(
                    q,
                    u_#{kind}_radius[#{i}],
                    u_#{kind}_height[#{i}] * 0.5
                );

                if (d < result.d) {
                    result.d = d;
                    result.color = vec3(
                        u_#{kind}_r[#{i}],
                        u_#{kind}_g[#{i}],
                        u_#{kind}_b[#{i}]
                    );
                }
            }
            """

            uniforms =
              uniforms ++
                [
                  {"u_#{kind}_r", i, r},
                  {"u_#{kind}_g", i, g},
                  {"u_#{kind}_b", i, b},
                  {"u_#{kind}_x", i, x},
                  {"u_#{kind}_y", i, y},
                  {"u_#{kind}_radius", i, radius},
                  {"u_#{kind}_height", i, height},
                  {"u_#{kind}_r", i, r},
                  {"u_#{kind}_g", i, g},
                  {"u_#{kind}_b", i, b}
                ]

            {code, {Map.update(kinds, :dot, 0, &(&1 + 1)), uniforms}}

          {%{
             pos: {{x1, y1}, {x2, y2}},
             attrs: attrs
           }, _},
          {kinds, uniforms} ->
            kind = "line"

            i = Map.get(kinds, :line, 0)

            thickness = abs(Map.get(attrs, :thickness, 1.0))
            height = Map.get(attrs, :height, thickness)
            source_tip = Map.get(attrs, :source_tip, thickness)
            target_tip = Map.get(attrs, :target_tip, thickness)

            {r, g, b} = hex_to_rgb(attrs.color)

            code = """
            {
                vec2 a = vec2(
                    u_#{kind}_x1[#{i}],
                    u_#{kind}_y1[#{i}]
                );

                vec2 b = vec2(
                    u_#{kind}_x2[#{i}],
                    u_#{kind}_y2[#{i}]
                );

                float d = sdf_segment_cylinder(
                    p,
                    a,
                    b,
                    u_#{kind}_radius[#{i}],
                    u_#{kind}_height[#{i}] * 0.5
                );
                vec2 dir2 = normalize(b - a);

                   vec3 axis = vec3(
                       dir2,
                       0.0
                   );
                   float arrow_d = min(
                   sdf_cone(
                        p,
                        vec3(a + -dir2 * 3.0 * u_#{kind}_radius[#{i}]* u_#{kind}_st[#{i}], 0.0),
                        vec3(-dir2, 0.0),
                        u_#{kind}_radius[#{i}] * 6.0* u_#{kind}_st[#{i}],
                        u_#{kind}_radius[#{i}] * 3.0* u_#{kind}_st[#{i}]
                    ),
                    sdf_cone(
                        p,
                        vec3(b + dir2 * 3.0 * u_#{kind}_radius[#{i}]* u_#{kind}_tt[#{i}], 0.0),
                        vec3(dir2, 0.0),
                        u_#{kind}_radius[#{i}] * 6.0* u_#{kind}_tt[#{i}],
                        u_#{kind}_radius[#{i}] * 3.0* u_#{kind}_tt[#{i}]
                    )
                   );

                   d = min(d, arrow_d);

                if (d < result.d) {
                    result.d = d;
                    result.color = vec3(
                        u_#{kind}_r[#{i}],
                        u_#{kind}_g[#{i}],
                        u_#{kind}_b[#{i}]
                    );
                }
            }
            """

            uniforms =
              uniforms ++
                [
                  {"u_#{kind}_x1", i, x1},
                  {"u_#{kind}_y1", i, y1},
                  {"u_#{kind}_x2", i, x2},
                  {"u_#{kind}_y2", i, y2},
                  {"u_#{kind}_radius", i, thickness * 0.5},
                  {"u_#{kind}_height", i, height},
                  {"u_#{kind}_st", i, if(source_tip, do: 1.0, else: 0.0)},
                  {"u_#{kind}_tt", i, if(target_tip, do: 1.0, else: 0.0)},
                  {"u_#{kind}_r", i, r},
                  {"u_#{kind}_g", i, g},
                  {"u_#{kind}_b", i, b}
                ]

            {code, {Map.update(kinds, :line, 0, &(&1 + 1)), uniforms}}

          _, {kinds, uniforms} ->
            {nil, {kinds, uniforms}}
        end
      )

    shader = """

    SDFResult scene(vec3 p) {
        SDFResult result;

        result.d = 1e20;
        result.color = vec3(1.0);

        #{Enum.join(parts, "\n\n#pragma split\n")}

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
