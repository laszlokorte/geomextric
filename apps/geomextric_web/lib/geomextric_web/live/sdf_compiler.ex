defmodule SDFCompiler do
  def compile(rects) do
    {parts, uniforms} =
      rects
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map_reduce([], fn
        {%{pos: {x, y, w, h}} = rect, i}, uniforms ->
          id = "rect_#{i}"
          {r, g, b} = hex_to_rgb(rect.attrs.color)

          code = """
            {
              float d = sdf_rect(
                pos,
                u_#{id}_x,
                u_#{id}_y,
                u_#{id}_w,
                u_#{id}_h
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
                {"u_#{id}_x", x},
                {"u_#{id}_y", y},
                {"u_#{id}_w", w},
                {"u_#{id}_h", h},
                {"u_#{id}_r", r},
                {"u_#{id}_g", g},
                {"u_#{id}_b", b}
              ]

          {code, uniforms}

        _, uniforms ->
          {nil, uniforms}
      end)

    shader = """
    precision highp float;

    float sdf_rect(
      vec2 p,
      float x,
      float y,
      float w,
      float h
    ) {
      vec2 c = vec2(x + w * 0.5, y + h * 0.5);
      vec2 b = vec2(w, h) * 0.5;

      vec2 q = abs(p - c) - b;

      return length(max(q, 0.0)) +
             min(max(q.x, q.y), 0.0);
    }

    vec3 scene(vec2 pos) {
      vec3 color = vec3(1.0);

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
