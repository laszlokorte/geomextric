defmodule GeomextricWeb.Geometry do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  alias Galixir.Algebras.PGA3

  @fr 1
  @near_clip 1.0e-3

  def fr(n), do: Float.round(n, @fr)

  attr :camera, :map, required: true
  attr :rotation, :float, default: 0.0
  attr :scale, :float, default: 1.0
  attr :id, :string, required: true
  attr :geo, :map, required: true
  attr :labels, :boolean, default: true
  attr :faces, :boolean, default: true
  attr :edges, :boolean, default: true
  attr :vertices, :boolean, default: true
  attr :quad_ellipse, :boolean, default: false
  attr :arrows, :boolean, default: false
  attr :motor, :map, default: PGA3.new(scalar: 1)

  def geometry(assigns) do
    assigns = assign(assigns, :projected_faces, project_faces(assigns))

    ~H"""
    <g id={"obj-#{@id}"}>
      <%= for {color, projected, path} <- @projected_faces do %>
        <%= if @quad_ellipse do %>
          <%= case projected do %>
            <% [{ax, ay, _}, {bx, by, _}, {cx, cy, _}, {dx,dy, _}] -> %>
              <% ellipse = quad_to_ellipse({ax, ay}, {bx, by}, {cx, cy}, {dx, dy}) %>
              <line
                :if={fr(ellipse.radius_b) <= 0.0}
                x1={fr(ellipse.center_x) - fr(ellipse.radius_a)}
                y1={fr(ellipse.center_y)}
                x2={fr(ellipse.center_x) + fr(ellipse.radius_a)}
                y2={fr(ellipse.center_y)}
                stroke={Enum.at(@geo.edges, 0) |> elem(0)}
                transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
              />
              <ellipse
                :if={fr(ellipse.radius_b) > 0.0}
                rx={fr(ellipse.radius_a)}
                ry={fr(ellipse.radius_b)}
                cx={fr(ellipse.center_x)}
                fill={color}
                stroke={Enum.at(@geo.edges, 0) |> elem(0)}
                transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
                r="2"
                cy={fr(ellipse.center_y)}
              />
            <% _ -> %>
              <polygon
                points={path}
                fill={color}
              />
          <% end %>
        <% else %>
          <polygon
            points={path}
            fill={color}
          />
        <% end %>
      <% end %>

      <%= for {color, {p1, p2}} <- @geo.edges, @edges  do %>
        <%= with {{x1, y1, _z1}, {x2, y2, _z2}} <- project_line(
          @camera,
          rot(@rotation, scale_point(p1, @scale)) |> PGA3.transform(@motor),
          rot(@rotation, scale_point(p2, @scale)) |> PGA3.transform(@motor)
        ) do %>
          <line
            class="line3d"
            stroke={color}
            stroke-width={if(@arrows, do: "3", else: if(color == "black", do: "1"))}
            stroke-linecap="round"
            vector-effect="non-scaling-stroke"
            marker-end={if(@arrows or color == "black", do: "url(#vector-head)")}
            x1={fr(x1)}
            y1={fr(y1)}
            x2={fr(x2)}
            y2={fr(y2)}
          />
          <% else _ -> %>
        <% end %>
      <% end %>
      <%= for {color, p} <- @geo.points, @vertices do %>
        <%= with {screen_x, screen_y, z} <- project(@camera, rot(@rotation, scale_point(p, @scale)) |> PGA3.transform(@motor)) do %>
          <circle
            fill={color}
            r={10 / abs(z)}
            cx={fr(screen_x)}
            cy={fr(screen_y)}
          />
          <% else _ -> %>
        <% end %>
      <% end %>
      <%= for {color, p, l} when is_binary(l) <- @geo.labels, @labels do %>
        <%= with {screen_x, screen_y, z} <- project(@camera, rot(@rotation, scale_point(p, @scale)) |> PGA3.transform(@motor))  do %>
          <text
            font-size={fr(24 / z)}
            fill={color}
            x={fr(screen_x)}
            y={fr(screen_y)}
            dy="-2"
            stroke="white"
            stroke-width="1"
            stroke-linejoin="round"
            text-anchor="middle"
            phx-no-format
          >
            <%= case parse_label(l) do %>
              <% {:text, text} -> %>
                <tspan>{text}</tspan>
              <% {:label, base, sub, sup} -> %>
              <tspan>{base}</tspan><%= if sup do %><tspan baseline-shift="super" font-size="smaller">{sup}</tspan><% end %><%= if sub do %><tspan baseline-shift="sub" font-size="smaller">{sub}</tspan><% end %>
            <% end %>
          </text>
          <text
            font-size={fr(24 / z)}
            fill={color}
            x={fr(screen_x)}
            y={fr(screen_y)}
            dy="-2"
            text-anchor="middle"
            phx-no-format
          >
            <%= case parse_label(l) do %>
              <% {:text, text} -> %>
                <tspan>{text}</tspan>
              <% {:label, base, sub, sup} -> %>
                <tspan>{base}</tspan><%= if sup do %><tspan baseline-shift="super" font-size="smaller">{sup}</tspan><% end %><%= if sub do %><tspan baseline-shift="sub" font-size="smaller">{sub}</tspan><% end %>
            <% end %>
            </text>
          <% else _ -> %>
        <% end %>
      <% end %>
    </g>
    """
  end

  def parse_label(str) do
    [_, base, rest] = Regex.run(~r/^([^^_]+)(.*)$/, str)

    parts =
      Regex.scan(~r/([_^])(?:\{([^}]*)\}|([^_^{}]+))/, rest)
      |> Enum.reduce(%{}, fn
        [_, "_", "", x], acc -> Map.put(acc, :sub, x)
        [_, "_", x, ""], acc -> Map.put(acc, :sub, x)
        [_, "^", "", x], acc -> Map.put(acc, :sup, x)
        [_, "^", x, ""], acc -> Map.put(acc, :sup, x)
      end)

    case parts do
      %{} = p when map_size(p) == 0 ->
        {:text, base}

      _ ->
        {:label, base, parts[:sub], parts[:sup]}
    end
  end

  def rot(a, o) do
    t =
      PGA3.gp(PGA3.new(e1: 1), PGA3.new(e2: 1))
      |> PGA3.add(PGA3.new(scalar: a / 100))
      |> PGA3.normalize!()

    PGA3.transform(o, t)
  end

  def scale_point(p, s) do
    PGA3.new(
      e123: PGA3.coefficient(p, :e123),
      e230: PGA3.coefficient(p, :e230) * s,
      e013: PGA3.coefficient(p, :e013) * s,
      e120: PGA3.coefficient(p, :e120) * s
    )
  end

  defp project_faces(%{faces: false}), do: []

  defp project_faces(assigns) do
    Enum.flat_map(assigns.geo.faces, fn {color, points} ->
      transformed_points =
        Enum.map(
          points,
          &(rot(assigns.rotation, scale_point(&1, assigns.scale))
            |> PGA3.transform(assigns.motor))
        )

      projected =
        if assigns.quad_ellipse and length(transformed_points) == 4 do
          project_quad_for_ellipse(assigns.camera, transformed_points)
        else
          project_polygon(assigns.camera, transformed_points)
        end

      if length(projected) >= 3 do
        path = Enum.map_join(projected, " ", fn {x, y, _z} -> "#{fr(x)} #{fr(y)}" end)
        [{color, projected, path}]
      else
        []
      end
    end)
  end

  def project_polygon(camera, points) do
    points
    |> Enum.map(&camera_coordinates(camera, &1))
    |> project_camera_polygon()
  end

  def project_quad_for_ellipse(camera, points) when length(points) == 4 do
    points
    |> Enum.map(&camera_coordinates(camera, &1))
    |> project_camera_quad_for_ellipse()
  end

  def project_camera_quad_for_ellipse(points) when length(points) == 4 do
    projected =
      Enum.map(points, fn {x, y, z} ->
        depth =
          if abs(z) < @near_clip do
            if z < 0, do: -@near_clip, else: @near_clip
          else
            z
          end

        {x * 100 / depth, -y * 100 / depth, depth}
      end)

    if Enum.all?(projected, fn {_x, _y, z} -> z >= @near_clip end) do
      projected
    else
      []
    end
  end

  def project_camera_polygon(points) do
    points
    |> clip_polygon()
    |> Enum.map(&project_camera_point/1)
  end

  defp clip_polygon(points) do
    constraints = [
      fn {_, _, z} -> z - @near_clip end,
      fn {x, _, z} -> z - x end,
      fn {x, _, z} -> z + x end,
      fn {_, y, z} -> z - y end,
      fn {_, y, z} -> z + y end
    ]

    Enum.reduce(constraints, points, &clip_polygon_against(&2, &1))
  end

  defp clip_polygon_against([], _constraint), do: []

  defp clip_polygon_against(points, constraint) do
    previous = List.last(points)

    Enum.zip([previous | points], points)
    |> Enum.flat_map(fn {first, second} ->
      first_value = constraint.(first)
      second_value = constraint.(second)
      first_inside = first_value >= 0
      second_inside = second_value >= 0

      cond do
        first_inside and second_inside ->
          [second]

        first_inside ->
          [intersect_plane(first, second, first_value, second_value)]

        second_inside ->
          [intersect_plane(first, second, first_value, second_value), second]

        true ->
          []
      end
    end)
  end

  defp intersect_plane(first, second, first_value, second_value) do
    interpolate_point(first, second, first_value / (first_value - second_value))
  end

  def project_line(camera, first, second) do
    first = camera_coordinates(camera, first)
    second = camera_coordinates(camera, second)

    project_camera_line(first, second)
  end

  def project_camera_line(first, second) do
    case clip_to_frustum(first, second) do
      nil ->
        nil

      {clipped_first, clipped_second} ->
        {project_camera_point(clipped_first), project_camera_point(clipped_second)}
    end
  end

  defp camera_coordinates(camera, point) do
    point
    |> PGA3.transform(camera)
    |> PGA3.point_coordinates()
  end

  defp project_camera_point({x, y, z}), do: {x * 100 / z, -y * 100 / z, z}

  defp clip_to_frustum(first, second) do
    constraints = [
      fn {_, _, z} -> z - @near_clip end,
      fn {x, _, z} -> z - x end,
      fn {x, _, z} -> z + x end,
      fn {_, y, z} -> z - y end,
      fn {_, y, z} -> z + y end
    ]

    Enum.reduce_while(constraints, {0.0, 1.0}, fn constraint, {enter, exit} ->
      first_value = constraint.(first)
      second_value = constraint.(second)
      delta = second_value - first_value

      cond do
        delta == 0 and first_value < 0 ->
          {:halt, nil}

        delta == 0 ->
          {:cont, {enter, exit}}

        delta > 0 ->
          next_enter = max(enter, -first_value / delta)
          if next_enter > exit, do: {:halt, nil}, else: {:cont, {next_enter, exit}}

        true ->
          next_exit = min(exit, -first_value / delta)
          if next_exit < enter, do: {:halt, nil}, else: {:cont, {enter, next_exit}}
      end
    end)
    |> case do
      nil ->
        nil

      {enter, exit} ->
        {interpolate_point(first, second, enter), interpolate_point(first, second, exit)}
    end
  end

  defp interpolate_point({x1, y1, z1}, {x2, y2, z2}, t) do
    {x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z1 + (z2 - z1) * t}
  end

  def project(cam, p) do
    if PGA3.zero?(cam) do
      nil
    else
      camera_point =
        PGA3.transform(p, cam)

      {x, y, z} = PGA3.point_coordinates(camera_point)

      if z < 0 do
        nil
      else
        screen_x = x * 100 / z
        screen_y = -y * 100 / z
        {screen_x, screen_y, z}
      end
    end
  end

  def quad_to_ellipse(
        {wx, wy},
        {xx, xy},
        {yx, yy},
        {zx, zy}
      ) do
    m00 =
      xx * yx * zy - wx * yx * zy -
        xx * yy * zx + wx * yy * zx -
        wx * xy * zx + wy * xx * zx +
        wx * xy * yx - wy * xx * yx

    m01 =
      wx * yx * zy - wx * xx * zy -
        xx * yy * zx + xy * yx * zx -
        wy * yx * zx + wy * xx * zx +
        wx * xx * yy - wx * xy * yx

    m02 =
      xx * yx * zy - wx * xx * zy -
        wx * yy * zx - xy * yx * zx +
        wy * yx * zx + wx * xy * zx +
        wx * xx * yy - wy * xx * yx

    m10 =
      xy * yx * zy - wy * yx * zy -
        wx * xy * zy + wy * xx * zy -
        xy * yy * zx + wy * yy * zx +
        wx * xy * yy - wy * xx * yy

    m11 =
      -xx * yy * zy + wx * yy * zy +
        xy * yx * zy - wx * xy * zy -
        wy * yy * zx + wy * xy * zx +
        wy * xx * yy - wy * xy * yx

    m12 =
      xx * yy * zy - wx * yy * zy +
        wy * yx * zy - wy * xx * zy -
        xy * yy * zx + wy * xy * zx +
        wx * xy * yy - wy * xy * yx

    m20 =
      xx * zy - wx * zy -
        xy * zx + wy * zx -
        xx * yy + wx * yy +
        xy * yx - wy * yx

    m21 =
      yx * zy - xx * zy -
        yy * zx + xy * zx +
        wx * yy - wy * yx -
        wx * xy + wy * xx

    m22 =
      yx * zy - wx * zy -
        yy * zx + wy * zx +
        xx * yy - xy * yx +
        wx * xy - wy * xx

    points = [{wx, wy}, {xx, xy}, {yx, yy}, {zx, zy}]

    determinant =
      m00 * (m11 * m22 - m21 * m12) -
        m01 * (m10 * m22 - m12 * m20) +
        m02 * (m10 * m21 - m11 * m20)

    if determinant == 0.0 do
      degenerate_quad_to_ellipse(points)
    else
      invdet = 1 / determinant

      j = (m11 * m22 - m21 * m12) * invdet
      k = -(m01 * m22 - m02 * m21) * invdet
      l = (m01 * m12 - m02 * m11) * invdet

      m = -(m10 * m22 - m12 * m20) * invdet
      n = (m00 * m22 - m02 * m20) * invdet
      o = -(m00 * m12 - m10 * m02) * invdet

      p = (m10 * m21 - m20 * m11) * invdet
      q = -(m00 * m21 - m20 * m01) * invdet
      r = (m00 * m11 - m10 * m01) * invdet

      a = j * j + m * m - p * p
      b = j * k + m * n - p * q
      c = k * k + n * n - q * q
      d = j * l + m * o - p * r
      f = k * l + n * o - q * r
      g = l * l + o * o - r * r

      denominator = b * b - a * c

      if denominator == 0.0 do
        degenerate_quad_to_ellipse(points)
      else
        center_x = (c * d - b * f) / denominator
        center_y = (a * f - b * d) / denominator

        common =
          2 * (a * f * f + c * d * d + g * b * b - 2 * b * d * f - a * c * g)

        root = :math.sqrt((a - c) * (a - c) + 4 * b * b)

        a_den = denominator * (root - (a + c))
        b_den = denominator * (-root - (a + c))

        radius_a =
          if a_den != 0 do
            :math.sqrt(
              abs(
                common /
                  a_den
              )
            )
          else
            0.0
          end

        radius_b =
          if b_den != 0.0 do
            :math.sqrt(
              abs(
                common /
                  b_den
              )
            )
          else
            0.0
          end

        angle =
          cond do
            b == 0 and a <= c ->
              0

            b == 0 and a >= c ->
              :math.pi() / 2

            b != 0 ->
              :math.pi() / 2 +
                0.5 * (:math.pi() / 2 - :math.atan2(a - c, 2 * b))
          end

        ellipse = %{
          center_x: center_x,
          center_y: center_y,
          radius_a: radius_a,
          radius_b: radius_b,
          angle: angle
        }

        cond do
          Float.round(radius_a, @fr) == 0.0 and Float.round(radius_b, @fr) == 0.0 ->
            degenerate_quad_to_ellipse(points)

          Float.round(radius_a, @fr) == 0.0 ->
            %{ellipse | radius_a: radius_b, radius_b: radius_a, angle: angle + :math.pi() / 2}

          true ->
            ellipse
        end
      end
    end
  end

  defp degenerate_quad_to_ellipse([first, second, third, fourth] = points) do
    pairs =
      for {point, i} <- Enum.with_index(points),
          {other_point, j} <- Enum.with_index(points),
          i < j do
        {point, other_point}
      end

    {{x1, y1}, {x2, y2}} =
      Enum.max_by(pairs, fn {{x1, y1}, {x2, y2}} ->
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)
      end)

    edge_lengths_squared = [
      squared_distance(first, second),
      squared_distance(second, third),
      squared_distance(third, fourth),
      squared_distance(fourth, first)
    ]

    adjacent_edge_sums =
      for {edge, next_edge} <-
            Enum.zip(edge_lengths_squared, tl(edge_lengths_squared) ++ [hd(edge_lengths_squared)]) do
        edge + next_edge
      end

    dx = x2 - x1
    dy = y2 - y1

    %{
      center_x: (x1 + x2) / 2,
      center_y: (y1 + y2) / 2,
      radius_a: :math.sqrt(Enum.max(adjacent_edge_sums)) / 2,
      radius_b: 0.0,
      angle: :math.atan2(dy, dx)
    }
  end

  defp squared_distance({x1, y1}, {x2, y2}), do: (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)
end
