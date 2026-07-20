defmodule GeomextricWeb.Geometry do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  alias Galixir.Algebras.PGA3

  attr :camera, :map, required: true
  attr :rotation, :float, default: 0.0
  attr :scale, :float, default: 1.0
  attr :id, :string, required: true
  attr :geo, :map, required: true
  attr :labels, :boolean, default: true
  attr :faces, :boolean, default: true
  attr :edges, :boolean, default: true
  attr :quad_ellipse, :boolean, default: false

  def geometry(assigns) do
    ~H"""
    <g id={"obj-#{@id}"}>
      <%= for {color, ps}<- @geo.faces, @faces, path =
                    (for p <- ps  do
                      with({screen_x, screen_y, _z} <- project(@camera, rot(@rotation, scale_point(p, @scale))), do:
                      "#{screen_x} #{screen_y}", else: (_e ->  ""))
                    end
                    |> Enum.join(" ")) do %>
        <%= if @quad_ellipse do %>
          <%= case ps |> Enum.map(&project(@camera, rot(@rotation, scale_point(&1, @scale))))   do %>
            <% [{ax, ay, _}, {bx, by, _}, {cx, cy, _}, {dx,dy, _}] -> %>
              <% ellipse = quad_to_ellipse({ax, ay}, {bx, by}, {cx, cy}, {dx, dy}) %>
              <ellipse
                :if={ellipse}
                rx={ellipse.radius_a}
                ry={ellipse.radius_b}
                cx={ellipse.center_x}
                fill={color}
                stroke={Enum.at(@geo.edges, 0) |> elem(0)}
                transform={"rotate(#{ellipse.angle * 180 / :math.pi()} #{ellipse.center_x} #{ellipse.center_y})"}
                r="2"
                cy={ellipse.center_y}
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
        <%= with {{x1, y1, _z1}, {x2,y2,_z2}} <- {project(@camera, rot(@rotation, scale_point(p1, @scale))), project(@camera, rot(@rotation, scale_point(p2, @scale)))} do %>
          <line
            class="line3d"
            stroke={color}
            x1={x1}
            y1={y1}
            x2={x2}
            y2={y2}
          />
          <% else _ -> %>
        <% end %>
      <% end %>
      <%= for {color, p} <- @geo.points do %>
        <%= with {screen_x, screen_y, z} <- project(@camera, rot(@rotation, scale_point(p, @scale))) do %>
          <circle
            fill={color}
            r={10 / abs(z)}
            cx={screen_x}
            cy={screen_y}
          />
          <% else _ -> %>
        <% end %>
      <% end %>
      <%= for {color, p, l} <- @geo.labels, @labels do %>
        <%= with {screen_x, screen_y, z} <- project(@camera, rot(@rotation, scale_point(p, @scale)))  do %>
          <text
            class="text-label"
            font-size={24 / z}
            fill={color}
            x={screen_x}
            y={screen_y}
            font-size={6}
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
            class="text-label"
            font-size={24 / z}
            fill={color}
            x={screen_x}
            y={screen_y}
            font-size={6}
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
      |> PGA3.normalize()

    PGA3.transform(t, o)
  end

  def scale_point(p, s) do
    PGA3.new(
      e123: PGA3.coefficient(p, :e123),
      e230: PGA3.coefficient(p, :e230) * s,
      e013: PGA3.coefficient(p, :e013) * s,
      e120: PGA3.coefficient(p, :e120) * s
    )
  end

  def project(cam, p) do
    if PGA3.zero?(cam) do
      nil
    else
      camera_point =
        PGA3.transform(cam, p)

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

    determinant =
      m00 * (m11 * m22 - m21 * m12) -
        m01 * (m10 * m22 - m12 * m20) +
        m02 * (m10 * m21 - m11 * m20)

    if determinant == 0 do
      nil
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

      center_x = (c * d - b * f) / denominator
      center_y = (a * f - b * d) / denominator

      common =
        2 * (a * f * f + c * d * d + g * b * b - 2 * b * d * f - a * c * g)

      root = :math.sqrt((a - c) * (a - c) + 4 * b * b)

      radius_a =
        :math.sqrt(
          common /
            (denominator * (root - (a + c)))
        )

      radius_b =
        :math.sqrt(
          common /
            (denominator * (-root - (a + c)))
        )

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

      %{
        center_x: center_x,
        center_y: center_y,
        radius_a: radius_a,
        radius_b: radius_b,
        angle: angle
      }
    end
  end
end
