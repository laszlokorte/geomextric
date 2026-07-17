defmodule GeomextricWeb.Geometry do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  alias Galixir.Algebras.PGA3

  attr :camera, :map, required: true
  attr :rotation, :float, default: 0.0
  attr :scale, :float, default: 1.0
  attr :id, :string, required: true
  attr :geo, :map, required: true

  def geometry(assigns) do
    ~H"""
    <g id={"obj-#{@id}"}>
      <%= for {color, ps}<- @geo.faces, path =
                    (for p <- ps  do
                      with({screen_x, screen_y, _z} <- project(@camera, rot(@rotation, scale_point(p, @scale))), do:
                      "#{screen_x} #{screen_y}", else: (_e ->  ""))
                    end
                    |> Enum.join(" ")) do %>
        <polygon
          points={path}
          fill={color}
        />
      <% end %>

      <%= for {color, {p1, p2}} <- @geo.edges  do %>
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
      <%= for {color, p, l} <- @geo.labels do %>
        <%= with {screen_x, screen_y, z} <- project(@camera, rot(@rotation, scale_point(p, @scale)))  do %>
          <text
            class="text-label"
            font-size={24 / z}
            fill={color}
            x={screen_x}
            y={screen_y}
            font-size={6}
            text-anchor="middle"
          >
            {l}
          </text>
          <% else _ -> %>
        <% end %>
      <% end %>
    </g>
    """
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
end
