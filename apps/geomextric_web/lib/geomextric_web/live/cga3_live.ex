defmodule GeomextricWeb.CGA3Live do
  use GeomextricWeb, :live_view

  alias Galixir.Algebras.CGA3
  alias Galixir.Algebras.PGA3

  import GeomextricWeb.Geometry, only: [fr: 1, project: 2, quad_to_ellipse: 4]
  import GeomextricWeb.Menu

  @palette [
    "#b45309",
    "#2563eb",
    "#15803d",
    "#be185d",
    "#7c3aed",
    "#0f766e",
    "#c2410c",
    "#4f46e5",
    "#a21caf",
    "#047857",
    "#b91c1c",
    "#0369a1",
    "#ca8a04",
    "#6d28d9",
    "#0e7490",
    "#9f1239"
  ]
  @initial_plane CGA3.plane({0.25, 0.7, 1.0}, -0.5)

  def mount(%{}, _, socket) do
    {:ok,
     assign(socket,
       camera: %{yaw: 0.0, pitch: 0.3, radius: 10.0},
       focus: {0.0, 0.0, 0.0},
       elements: [{@initial_plane, hd(@palette)}],
       point_cloud: letter_point_cloud(),
       element_slots: [0],
       spheres_added: 0,
       planes_added: 0,
       available_colors:
         @palette
         |> Enum.with_index()
         |> Enum.drop(1)
         |> Enum.map(fn {color, slot} -> {slot, color} end)
     )}
  end

  defp scene_transform(elements) do
    Enum.reduce(elements, CGA3.new(scalar: 1), fn {element, _color}, transform ->
      CGA3.gp(transform, element)
    end)
  end

  defp project_point_cloud(points, camera) do
    Enum.flat_map(points, fn point ->
      {x, y, z} = CGA3.point_coordinates(point)

      case project(camera, PGA3.point(x, y, z)) do
        nil -> []
        projected -> [projected]
      end
    end)
  end

  defp letter_point_cloud do
    strokes = [
      {{-1.8, -2.0}, {-1.8, 2.0}, 12},
      {{-1.8, 2.0}, {1.8, 2.0}, 12},
      {{-1.8, 0.0}, {0.8, 0.0}, 9}
    ]

    Enum.flat_map(strokes, fn {{x1, y1}, {x2, y2}, count} ->
      for depth <- [0.25, 0.0, 0.25], step <- 0..(count - 1) do
        t = step / (count - 1)
        horizontal = x1 + (x2 - x1) * t
        vertical = y1 + (y2 - y1) * t
        CGA3.point(3.0 + depth, horizontal, vertical)
      end
    end)
  end

  def handle_event("add_sphere", %{}, socket) do
    case socket.assigns.available_colors do
      [] ->
        {:noreply, socket}

      _available ->
        centers = [{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {0, 0, 1}]
        center = Enum.at(centers, rem(socket.assigns.spheres_added, length(centers)))
        {x, y, z} = center

        socket
        |> update(:spheres_added, &(&1 + 1))
        |> add_element(CGA3.sphere(x, y, z, 2.5))
    end
  end

  def handle_event("add_line", %{}, socket) do
    line = CGA3.line(CGA3.point(0, 0, 0), CGA3.point(0, 2, 0))
    add_element(socket, line)
  end

  def handle_event("add_circle", %{}, socket) do
    add_element(socket, CGA3.circle({0, 0, 0}, 2.0, {0, 0, 1}))
  end

  def handle_event("add_point_pair", %{}, socket) do
    pair = CGA3.point_pair(CGA3.point(-1.5, 0, 0), CGA3.point(1.5, 0, 0))
    add_element(socket, pair)
  end

  def handle_event("add_plane", %{}, socket) do
    case socket.assigns.available_colors do
      [] ->
        {:noreply, socket}

      _available ->
        normals = [{1, 0, 0}, {0, 1, 0}, {0, 0, 1}]
        normal = Enum.at(normals, rem(socket.assigns.planes_added, length(normals)))
        plane = CGA3.plane(normal, 0)

        socket
        |> update(:planes_added, &(&1 + 1))
        |> add_element(plane)
    end
  end

  def handle_event("delete_element", %{"index" => index}, socket) do
    with {index, ""} <- Integer.parse(index),
         true <- index >= 0,
         {{_object, _color}, slot} <-
           {Enum.at(socket.assigns.elements, index), Enum.at(socket.assigns.element_slots, index)} do
      elements =
        socket.assigns.elements
        |> Enum.with_index()
        |> Enum.reject(fn {_element, current_index} -> current_index == index end)
        |> Enum.map(&elem(&1, 0))

      slots =
        socket.assigns.element_slots
        |> Enum.with_index()
        |> Enum.reject(fn {_slot, current_index} -> current_index == index end)
        |> Enum.map(&elem(&1, 0))

      restored_color = Enum.at(@palette, slot)

      available_colors =
        [{slot, restored_color} | socket.assigns.available_colors] |> Enum.sort_by(&elem(&1, 0))

      {:noreply,
       assign(socket,
         elements: elements,
         element_slots: slots,
         available_colors: available_colors
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("close", %{}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("reset", %{}, socket) do
    {:noreply,
     assign(socket, camera: %{yaw: 0.0, pitch: 0.3, radius: 10.0}, focus: {0.0, 0.0, 0.0})}
  end

  def handle_event("rot", %{"v" => v, "h" => h}, socket) do
    camera = socket.assigns.camera
    pitch = camera.pitch + parse_number(v) * 0.5
    yaw = camera.yaw + parse_number(h) * 0.5

    {:noreply,
     assign(socket, :camera, %{
       camera
       | pitch: clamp(pitch, -:math.pi() / 2.05, :math.pi() / 2.05),
         yaw: yaw
     })}
  end

  def handle_event("zoom", %{"value" => value}, socket) do
    radius = clamp(parse_number(value), 1, 100)
    {:noreply, update(socket, :camera, &%{&1 | radius: radius})}
  end

  def handle_event("zoom_by", %{"value" => value}, socket) do
    factor = :math.exp(parse_number(value))
    radius = clamp(socket.assigns.camera.radius * factor, 1, 100)
    {:noreply, update(socket, :camera, &%{&1 | radius: radius})}
  end

  def handle_event("change_element", %{"index" => index} = params, socket) do
    with {index, ""} <- Integer.parse(index),
         {object, old_color} <- Enum.at(socket.assigns.elements, index),
         color when is_binary(color) <- Map.get(params, "color", old_color),
         true <- Regex.match?(~r/^#[0-9a-fA-F]{6}$/, color) do
      object = update_element(object, params)

      elements =
        socket.assigns.elements
        |> Enum.with_index()
        |> Enum.map(fn
          {_old_element, ^index} -> {object, color}
          {element, _other_index} -> element
        end)

      {:noreply, assign(socket, :elements, elements)}
    else
      _ -> {:noreply, socket}
    end
  end

  defp add_element(socket, object) do
    case socket.assigns.available_colors do
      [{slot, color} | remaining] ->
        {:noreply,
         assign(socket,
           elements: socket.assigns.elements ++ [{object, color}],
           element_slots: socket.assigns.element_slots ++ [slot],
           available_colors: remaining
         )}

      [] ->
        {:noreply, socket}
    end
  end

  defp update_element(object, params) do
    cond do
      CGA3.sphere?(object) ->
        {:sphere, {:real, {x, y, z}, radius}} = CGA3.sphere_parameters(object)

        CGA3.sphere(
          number_param(params, "x", x),
          number_param(params, "y", y),
          number_param(params, "z", z),
          max(abs(number_param(params, "radius", radius)), 0.1)
        )

      CGA3.point_pair?(object) ->
        case CGA3.point_pair_parameters(object) do
          {:real, {ax, ay, az}, {bx, by, bz}} ->
            point_a =
              CGA3.point(
                number_param(params, "ax", ax),
                number_param(params, "ay", ay),
                number_param(params, "az", az)
              )

            point_b =
              CGA3.point(
                number_param(params, "bx", bx),
                number_param(params, "by", by),
                number_param(params, "bz", bz)
              )

            # The split order is opposite the arguments to point_pair/2.
            CGA3.point_pair(point_b, point_a)

          {:tangent, {x, y, z}} ->
            point =
              CGA3.point(
                number_param(params, "ax", x),
                number_param(params, "ay", y),
                number_param(params, "az", z)
              )

            CGA3.point_pair(point, point)
        end

      CGA3.circle?(object) ->
        {:circle, {:real, {x, y, z}, radius, {nx, ny, nz}}} = CGA3.circle_parameters(object)

        normal = {
          number_param(params, "nx", nx),
          number_param(params, "ny", ny),
          number_param(params, "nz", nz)
        }

        if vector_length(normal) > 1.0e-6 do
          CGA3.circle(
            {
              number_param(params, "x", x),
              number_param(params, "y", y),
              number_param(params, "z", z)
            },
            max(abs(number_param(params, "radius", radius)), 0.1),
            normal
          )
        else
          object
        end

      CGA3.line?(object) ->
        {{x, y, z}, {dx, dy, dz}} = CGA3.line_parameters(object)

        direction = {
          number_param(params, "dx", dx),
          number_param(params, "dy", dy),
          number_param(params, "dz", dz)
        }

        direction_length = vector_length(direction)

        if direction_length > 1.0e-6 do
          {dx, dy, dz} = {
            elem(direction, 0) / direction_length,
            elem(direction, 1) / direction_length,
            elem(direction, 2) / direction_length
          }

          offset = {
            number_param(params, "ox", x),
            number_param(params, "oy", y),
            number_param(params, "oz", z)
          }

          along = elem(offset, 0) * dx + elem(offset, 1) * dy + elem(offset, 2) * dz

          closest = {
            elem(offset, 0) - along * dx,
            elem(offset, 1) - along * dy,
            elem(offset, 2) - along * dz
          }

          {x, y, z} = closest
          CGA3.line(CGA3.point(x, y, z), CGA3.point(x + dx, y + dy, z + dz))
        else
          object
        end

      CGA3.plane?(object) ->
        {{nx, ny, nz}, distance} = CGA3.plane_parameters(object)

        normal = {
          number_param(params, "nx", nx),
          number_param(params, "ny", ny),
          number_param(params, "nz", nz)
        }

        if vector_length(normal) > 1.0e-6 do
          CGA3.plane(normal, number_param(params, "distance", distance))
        else
          object
        end

      true ->
        object
    end
  end

  defp number_param(params, key, fallback) do
    case Map.fetch(params, key) do
      {:ok, value} ->
        case Float.parse(value) do
          {number, ""} -> number
          _ -> fallback
        end

      :error ->
        fallback
    end
  end

  defp vector_length({x, y, z}), do: :math.sqrt(x * x + y * y + z * z)

  defp element_controls({object, _color}) do
    cond do
      CGA3.sphere?(object) ->
        {:sphere, {:real, {x, y, z}, radius}} = CGA3.sphere_parameters(object)

        [
          {"Center X", "x", x, -6, 6, 0.1},
          {"Center Y", "y", y, -6, 6, 0.1},
          {"Center Z", "z", z, -6, 6, 0.1},
          {"Radius", "radius", radius, 0.1, 5, 0.1}
        ]

      CGA3.point_pair?(object) ->
        case CGA3.point_pair_parameters(object) do
          {:real, {ax, ay, az}, {bx, by, bz}} ->
            [
              {"Point A X", "ax", ax, -6, 6, 0.1},
              {"Point A Y", "ay", ay, -6, 6, 0.1},
              {"Point A Z", "az", az, -6, 6, 0.1},
              {"Point B X", "bx", bx, -6, 6, 0.1},
              {"Point B Y", "by", by, -6, 6, 0.1},
              {"Point B Z", "bz", bz, -6, 6, 0.1}
            ]

          {:tangent, {x, y, z}} ->
            [
              {"Point X", "ax", x, -6, 6, 0.1},
              {"Point Y", "ay", y, -6, 6, 0.1},
              {"Point Z", "az", z, -6, 6, 0.1}
            ]
        end

      CGA3.circle?(object) ->
        {:circle, {:real, {x, y, z}, radius, {nx, ny, nz}}} = CGA3.circle_parameters(object)

        [
          {"Center X", "x", x, -6, 6, 0.1},
          {"Center Y", "y", y, -6, 6, 0.1},
          {"Center Z", "z", z, -6, 6, 0.1},
          {"Radius", "radius", radius, 0.1, 5, 0.1},
          {"Normal X", "nx", nx, -1, 1, 0.01},
          {"Normal Y", "ny", ny, -1, 1, 0.01},
          {"Normal Z", "nz", nz, -1, 1, 0.01}
        ]

      CGA3.line?(object) ->
        {{x, y, z}, {dx, dy, dz}} = CGA3.line_parameters(object)

        [
          {"Direction X", "dx", dx, -1, 1, 0.01},
          {"Direction Y", "dy", dy, -1, 1, 0.01},
          {"Direction Z", "dz", dz, -1, 1, 0.01},
          {"Origin distance X", "ox", x, -6, 6, 0.1},
          {"Origin distance Y", "oy", y, -6, 6, 0.1},
          {"Origin distance Z", "oz", z, -6, 6, 0.1}
        ]

      CGA3.plane?(object) ->
        {{nx, ny, nz}, distance} = CGA3.plane_parameters(object)

        [
          {"Normal X", "nx", nx, -1, 1, 0.01},
          {"Normal Y", "ny", ny, -1, 1, 0.01},
          {"Normal Z", "nz", nz, -1, 1, 0.01},
          {"Distance", "distance", distance, -6, 6, 0.1}
        ]

      true ->
        []
    end
  end

  defp element_expression({object, _color}), do: inspect(object, limit: :infinity)

  defp element_label({object, _color}, index) do
    type =
      cond do
        CGA3.sphere?(object) -> "Sphere"
        CGA3.circle?(object) -> "Circle"
        CGA3.point_pair?(object) -> "Point pair"
        CGA3.plane?(object) -> "Plane"
        CGA3.line?(object) -> "Line"
        true -> "Unknown"
      end

    "#{type} #{index + 1}"
  end

  defp parse_number(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  defp clamp(value, min, max), do: max(min, min(max, value))

  defp camera_transform(%{yaw: yaw, pitch: pitch, radius: radius}, {fx, fy, fz}) do
    eye = {
      fx + radius * :math.cos(pitch) * :math.cos(yaw),
      fy + radius * :math.cos(pitch) * :math.sin(yaw),
      fz + radius * :math.sin(pitch)
    }

    GeomextricWeb.PlaygroundLive.look_at(
      PGA3.point(elem(eye, 0), elem(eye, 1), elem(eye, 2)),
      PGA3.point(fx, fy, fz),
      PGA3.ideal_point(0, 0, 1)
    )
  end

  defp sphere_ellipses(camera, sphere) do
    {:sphere, {:real, {x, y, z}, radius}} = CGA3.sphere_parameters(sphere)

    center = project(camera, PGA3.point(x, y, z))

    fill = sphere_silhouette(camera, {x, y, z}, radius)

    diagonal = :math.sqrt(0.5)
    latitude_height = radius * 0.5
    latitude_radius = :math.sqrt(radius * radius - latitude_height * latitude_height)

    circles = [
      {{0, 0, 0}, radius, {1, 0, 0}, {0, 1, 0}, false},
      {{0, 0, 0}, radius, {0, 1, 0}, {0, 0, 1}, false},
      {{0, 0, 0}, radius, {0, 0, 1}, {1, 0, 0}, false},
      {{0, 0, 0}, radius, {diagonal, diagonal, 0}, {0, 0, 1}, true},
      {{0, 0, 0}, radius, {diagonal, -diagonal, 0}, {0, 0, 1}, true},
      {{0, 0, latitude_height}, latitude_radius, {1, 0, 0}, {0, 1, 0}, true},
      {{0, 0, -latitude_height}, latitude_radius, {1, 0, 0}, {0, 1, 0}, true}
    ]

    ellipses =
      Enum.map(circles, fn {{cx, cy, cz}, circle_radius, {ax, ay, az}, {bx, by, bz}, secondary} ->
        points = [
          {x + cx + circle_radius * (ax + bx), y + cy + circle_radius * (ay + by),
           z + cz + circle_radius * (az + bz)},
          {x + cx + circle_radius * (-ax + bx), y + cy + circle_radius * (-ay + by),
           z + cz + circle_radius * (-az + bz)},
          {x + cx + circle_radius * (-ax - bx), y + cy + circle_radius * (-ay - by),
           z + cz + circle_radius * (-az - bz)},
          {x + cx + circle_radius * (ax - bx), y + cy + circle_radius * (ay - by),
           z + cz + circle_radius * (az - bz)}
        ]

        projected =
          Enum.map(points, &project(camera, PGA3.point(elem(&1, 0), elem(&1, 1), elem(&1, 2))))

        case projected do
          [{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}] ->
            ellipse = quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})
            Map.put(ellipse, :secondary, secondary)

          _ ->
            nil
        end
      end)

    ellipses = Enum.reject(ellipses, &is_nil/1)

    case center do
      {_screen_x, _screen_y, depth} -> %{ellipses: ellipses, fill: fill, depth: depth}
      _ -> %{ellipses: ellipses, fill: fill, depth: 0}
    end
  end

  defp sphere_silhouette(camera, {x, y, z}, radius) do
    camera_center = PGA3.transform(PGA3.point(x, y, z), camera)
    {cx, cy, cz} = PGA3.point_coordinates(camera_center)
    distance_squared = cx * cx + cy * cy + cz * cz

    if not finite_number?(distance_squared) or distance_squared <= radius * radius do
      nil
    else
      distance = :math.sqrt(distance_squared)
      direction = {cx / distance, cy / distance, cz / distance}
      reference = if abs(elem(direction, 2)) < 0.9, do: {0.0, 0.0, 1.0}, else: {0.0, 1.0, 0.0}
      u = normalize(cross(direction, reference))
      v = normalize(cross(direction, u))
      tangent_distance = (distance_squared - radius * radius) / distance
      tangent_radius = radius * :math.sqrt(distance_squared - radius * radius) / distance
      tangent_center = Enum.map(Tuple.to_list(direction), &(&1 * tangent_distance))
      {tx, ty, tz} = List.to_tuple(tangent_center)
      {ux, uy, uz} = u
      {vx, vy, vz} = v

      camera_points = [
        {tx + tangent_radius * (ux + vx), ty + tangent_radius * (uy + vy),
         tz + tangent_radius * (uz + vz)},
        {tx + tangent_radius * (-ux + vx), ty + tangent_radius * (-uy + vy),
         tz + tangent_radius * (-uz + vz)},
        {tx + tangent_radius * (-ux - vx), ty + tangent_radius * (-uy - vy),
         tz + tangent_radius * (-uz - vz)},
        {tx + tangent_radius * (ux - vx), ty + tangent_radius * (uy - vy),
         tz + tangent_radius * (uz - vz)}
      ]

      projected = Enum.map(camera_points, &project_camera_point/1)

      case projected do
        [{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}] ->
          quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})

        _ ->
          nil
      end
    end
  rescue
    ArgumentError -> nil
  end

  defp project_camera_point({x, y, z}) do
    if finite_number?(x) and finite_number?(y) and finite_number?(z) and z > 1.0e-9 do
      screen_x = 100 * x / z
      screen_y = -100 * y / z

      if finite_number?(screen_x) and finite_number?(screen_y),
        do: {screen_x, screen_y, z},
        else: nil
    else
      nil
    end
  end

  defp finite_number?(number),
    do: is_number(number) and number == number and abs(number) < 1.0e300

  defp point_pair_geometry(camera, pair) do
    case CGA3.point_pair_parameters(pair) do
      {:real, a, b} ->
        projected =
          [a, b]
          |> Enum.map(fn {x, y, z} -> project(camera, PGA3.point(x, y, z)) end)

        case projected do
          [{ax, ay, ad}, {bx, by, bd}] ->
            %{a: {ax, ay, ad}, b: {bx, by, bd}, depth: (ad + bd) * 0.5}

          _ ->
            nil
        end

      {:tangent, {x, y, z}} ->
        case project(camera, PGA3.point(x, y, z)) do
          {px, py, depth} -> %{a: {px, py, depth}, b: {px, py, depth}, depth: depth}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp circle_geometry(camera, circle) do
    {:circle, {:real, center, radius, normal}} = CGA3.circle_parameters(circle)
    {nx, ny, nz} = normalize(normal)
    reference = if abs(nz) < 0.9, do: {0.0, 0.0, 1.0}, else: {0.0, 1.0, 0.0}
    u = normalize(cross({nx, ny, nz}, reference))
    v = normalize(cross({nx, ny, nz}, u))
    {x, y, z} = center

    projected =
      [
        point_on_plane(center, u, v, -radius, -radius),
        point_on_plane(center, u, v, radius, -radius),
        point_on_plane(center, u, v, radius, radius),
        point_on_plane(center, u, v, -radius, radius)
      ]
      |> Enum.map(fn {px, py, pz} -> project(camera, PGA3.point(px, py, pz)) end)

    case {projected, project(camera, PGA3.point(x, y, z))} do
      {[{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}], {_cx, _cy, depth}} ->
        ellipse = quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})
        %{ellipse: ellipse, depth: depth}

      _ ->
        nil
    end
  end

  defp line_geometry(camera, line) do
    {{x, y, z}, {dx, dy, dz}} = CGA3.line_parameters(line)
    point = PGA3.transform(PGA3.point(x, y, z), camera) |> PGA3.point_coordinates()

    second =
      PGA3.transform(PGA3.point(x + dx, y + dy, z + dz), camera) |> PGA3.point_coordinates()

    direction =
      {elem(second, 0) - elem(point, 0), elem(second, 1) - elem(point, 1),
       elem(second, 2) - elem(point, 2)}

    constraints = [
      {elem(point, 2) - 0.001, elem(direction, 2)},
      {elem(point, 2) - elem(point, 0), elem(direction, 2) - elem(direction, 0)},
      {elem(point, 2) + elem(point, 0), elem(direction, 2) + elem(direction, 0)},
      {elem(point, 2) - elem(point, 1), elem(direction, 2) - elem(direction, 1)},
      {elem(point, 2) + elem(point, 1), elem(direction, 2) + elem(direction, 1)}
    ]

    case clip_line(constraints, {-1.0e6, 1.0e6}) do
      {minimum, maximum} when minimum <= maximum ->
        {x1, y1, z1} = camera_line_point(point, direction, minimum)
        {x2, y2, z2} = camera_line_point(point, direction, maximum)

        %{
          x1: 100 * x1 / z1,
          y1: -100 * y1 / z1,
          x2: 100 * x2 / z2,
          y2: -100 * y2 / z2,
          depth: (z1 + z2) * 0.5
        }

      _ ->
        nil
    end
  end

  defp clip_line([], interval), do: interval

  defp clip_line([{value, slope} | rest], {minimum, maximum}) do
    cond do
      abs(slope) < 1.0e-9 and value < 0 ->
        nil

      abs(slope) < 1.0e-9 ->
        clip_line(rest, {minimum, maximum})

      slope > 0 ->
        clip_line(rest, {max(minimum, -value / slope), maximum})

      true ->
        clip_line(rest, {minimum, min(maximum, -value / slope)})
    end
  end

  defp camera_line_point({x, y, z}, {dx, dy, dz}, t),
    do: {x + dx * t, y + dy * t, z + dz * t}

  defp plane_grid(camera, plane) do
    {{nx, ny, nz}, distance} = CGA3.plane_parameters(plane)
    origin = {nx * distance, ny * distance, nz * distance}
    reference = if abs(nz) < 0.9, do: {0.0, 0.0, 1.0}, else: {0.0, 1.0, 0.0}
    u = normalize(cross({nx, ny, nz}, reference))
    v = normalize(cross({nx, ny, nz}, u))
    extent = 4.0
    step = extent / 2

    cells =
      for row <- 0..3, column <- 0..3 do
        u0 = -extent + column * step
        u1 = u0 + step
        v0 = -extent + row * step
        v1 = v0 + step

        [
          point_on_plane(origin, u, v, u0, v0),
          point_on_plane(origin, u, v, u1, v0),
          point_on_plane(origin, u, v, u1, v1),
          point_on_plane(origin, u, v, u0, v1)
        ]
        |> Enum.map(fn {x, y, z} -> project(camera, PGA3.point(x, y, z)) end)
      end
      |> Enum.reject(&Enum.any?(&1, fn point -> is_nil(point) end))

    fill =
      [
        point_on_plane(origin, u, v, -extent, -extent),
        point_on_plane(origin, u, v, extent, -extent),
        point_on_plane(origin, u, v, extent, extent),
        point_on_plane(origin, u, v, -extent, extent)
      ]
      |> Enum.map(fn {x, y, z} -> project(camera, PGA3.point(x, y, z)) end)

    center = project(camera, PGA3.point(elem(origin, 0), elem(origin, 1), elem(origin, 2)))
    fill = if Enum.any?(fill, &is_nil/1), do: nil, else: fill

    case center do
      {_x, _y, depth} -> %{cells: cells, fill: fill, depth: depth}
      _ -> %{cells: cells, fill: fill, depth: 0}
    end
  end

  defp point_on_plane({x, y, z}, {ux, uy, uz}, {vx, vy, vz}, a, b),
    do: {x + a * ux + b * vx, y + a * uy + b * vy, z + a * uz + b * vz}

  defp cross({ax, ay, az}, {bx, by, bz}),
    do: {ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx}

  defp normalize({x, y, z}) do
    length = :math.sqrt(x * x + y * y + z * z)
    {x / length, y / length, z / length}
  end

  defp classify_elements(elements, camera) do
    elements
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{element, color}, index} ->
        cond do
          CGA3.sphere?(element) ->
            geometry = sphere_ellipses(camera, element)
            [Map.merge(%{id: index, color: color, type: :sphere}, geometry)]

          CGA3.plane?(element) ->
            geometry = plane_grid(camera, element)
            [Map.merge(%{id: index, color: color, type: :plane}, geometry)]

          CGA3.point_pair?(element) ->
            case point_pair_geometry(camera, element) do
              nil -> []
              geometry -> [Map.merge(%{id: index, color: color, type: :point_pair}, geometry)]
            end

          CGA3.circle?(element) ->
            case circle_geometry(camera, element) do
              nil -> []
              geometry -> [Map.merge(%{id: index, color: color, type: :circle}, geometry)]
            end

          CGA3.line?(element) ->
            case line_geometry(camera, element) do
              nil -> []
              geometry -> [Map.merge(%{id: index, color: color, type: :line}, geometry)]
            end

          true ->
            []
        end
    end)
    |> Enum.sort_by(& &1.depth, :desc)
  end

  def render(assigns) do
    camera = camera_transform(assigns.camera, assigns.focus)
    elements = classify_elements(assigns.elements, camera)

    transform = scene_transform(assigns.elements)
    transformed_points = Enum.map(assigns.point_cloud, &CGA3.transform(&1, transform))

    assigns =
      assign(assigns,
        camera_transform: camera,
        scene_elements: elements,
        projected_point_cloud: project_point_cloud(assigns.point_cloud, camera),
        projected_transformed_point_cloud: project_point_cloud(transformed_points, camera)
      )

    ~H"""
    <style :type={GeomextricWeb.ColocatedScopedCSS}>
      .screen { position: absolute; inset: 0; }
      .scene { position: absolute; inset: 0; width: 100%; height: 100%; background: #fff; touch-action: none; }
      .bar { z-index: 2; }
      .toolbar {
              position: fixed;
              z-index: 1000;
              top: 2em;
              left: 0;
              right: 1em;
              margin: 1ex;
              padding: 1ex;
              display: flex;
              flex-direction: row;
              flex-wrap: wrap-reverse;
              align-items: center;
              gap: 1ex;
              color: #fff;
              background: #0003;
              border-radius: 1ex;
            }
      .grid-cell { stroke-width: .7; vector-effect: non-scaling-stroke; }
      .sphere-fill { stroke: none; opacity: .12; }
      .sphere-ring { fill: none; stroke-width: 2; vector-effect: non-scaling-stroke; }
      .sphere-ring-secondary { stroke-width: 1; opacity: .72; }
      .plane-fill { stroke: none; opacity: .1; }
      .scene-line { stroke-width: 2; vector-effect: non-scaling-stroke; }
      .scene-circle { fill-opacity: .12; stroke-width: 2; vector-effect: non-scaling-stroke; }
      .point-pair-link { stroke-width: 1.5; stroke-dasharray: 3 3; vector-effect: non-scaling-stroke; }
      .point-pair-point { stroke: #fff; stroke-width: 1.5; vector-effect: non-scaling-stroke; }
            .elements-panel {
              position: fixed;
              z-index: 1000;
              left: 1rem;
              bottom: 1rem;
              width: min(21rem, calc(100vw - 2rem));
              max-height: 50vh;
              overflow: auto;
              padding: .75rem;
              color: #222;
              background: #fffffff0;
              border: 1px solid #0002;
              border-radius: .75rem;
              box-shadow: 0 .5rem 1.5rem #0002;
            }
            .elements-panel h2 { margin: 0 0 .5rem; font-size: .95rem; }
            .element-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .3rem 0; }
            .element-actions { display: flex; flex-wrap: wrap; gap: .5rem; margin-top: .75rem; }
            .element-actions button, .delete-element { border: 1px solid #0002; border-radius: .4rem; padding: .25rem .5rem; cursor: pointer; }
            .element-actions button:disabled { opacity: .45; cursor: not-allowed; }
            .delete-element {
              grid-column: 2;
              justify-self: end;
              width: 1.5rem;
              height: 1.5rem;
              display: grid;
              place-items: center;
              margin: 0;
              padding: 0;
              color: #fff;
              background: #7f1d1d;
              border-color: #7f1d1d;
              font-size: 1rem;
              line-height: 1;
            }
            .delete-element:hover { background: #991b1b; }
            .element-editor {
              display: grid;
              grid-template-columns: minmax(0, 1fr) 1.5rem;
              align-items: start;
              gap: .5rem;
              margin: .25rem 0;
              accent-color: var(--element-color);
            }

            .element-disclosure { grid-column: 1; width: 100%; min-width: 0; }
            .element-editor summary { color: var(--element-color); cursor: pointer; }
            .element-expression { display: block; margin: .25rem 0 .5rem; color: #555; font: .68rem/1.35 ui-monospace, SFMono-Regular, monospace; overflow-wrap: anywhere; }
            .element-row + .element-row { border-top: 1px solid #0001; }
            .element-row input[type="color"] { width: 2.5rem; height: 2rem; padding: 0; border: 0; background: transparent; cursor: pointer; }
            .element-controls { display: grid; grid-template-columns: minmax(0, 1fr); width: calc(100% + 2rem); box-sizing: border-box; gap: .35rem; padding: .5rem 0; }
            .element-control { display: grid; grid-template-columns: 6rem minmax(0, 1fr); align-items: center; gap: .5rem; font-size: .8rem; }
            .element-control input { display: block; width: 100%; min-width: 0; box-sizing: border-box; margin: 0; }
    </style>
    <div class="screen">
      <div class="bar">
        <.menu items={[
          %{label: "File", items: [%{label: "close", send: "close"}]},
          %{label: "Camera", items: [%{label: "Reset", send: "reset"}]},
          %{
            label: "Help",
            items: [
              %{
                label: "www.laszlokorte.de",
                shortcut: [key: "h", ctrl: true],
                link: "https://www.laszlokorte.de"
              }
            ]
          }
        ]}>
          <:head>
            <.link navigate={~p"/cga"}>
              CGA3
            </.link>
          </:head>
          <div class="segment">
            <div class="connection-status connected">Connected 🟢</div>
            <div class="connection-status disconnected">Reconnecting... 🔴</div>
          </div>
        </.menu>
      </div>
      <div class="elements-panel" id="cga3-elements" phx-hook=".ElementPanels">
        <h2>Scene elements ({length(@elements)}/16)</h2>
        <div
          :for={{element, index} <- Enum.with_index(@elements)}
          class="element-editor"
          style={"--element-color: #{elem(element, 1)}"}
        >
          <details id={"cga3-element-panel-#{index}"} class="element-disclosure">
            <summary>{element_label(element, index)}</summary>
            <code id={"cga3-element-expression-#{index}"} class="element-expression">
              {element_expression(element)}
            </code>
            <form id={"cga3-element-#{index}"} class="element-controls" phx-change="change_element">
              <input type="hidden" name="index" value={index} />
              <label class="element-row" for={"cga3-element-color-#{index}"}>
                Color
                <input
                  id={"cga3-element-color-#{index}"}
                  type="color"
                  name="color"
                  value={elem(element, 1)}
                  aria-label={"Color for #{element_label(element, index)}"}
                />
              </label>
              <label
                :for={{label, name, value, min, max, step} <- element_controls(element)}
                class="element-control"
                for={"cga3-element-#{index}-#{name}"}
              >
                {label}
                <input
                  id={"cga3-element-#{index}-#{name}"}
                  type="range"
                  name={name}
                  min={min}
                  max={max}
                  step={step}
                  value={value}
                />
              </label>
            </form>
          </details>
          <button
            id={"delete-element-#{index}"}
            type="button"
            class="delete-element"
            phx-click="delete_element"
            phx-value-index={index}
            aria-label={"Remove #{element_label(element, index)}"}
            title="Remove element"
          >
            ×
          </button>
        </div>
        <div class="element-actions">
          <button
            id="add-sphere"
            type="button"
            phx-click="add_sphere"
            disabled={@available_colors == []}
          >Add sphere</button>
          <button
            id="add-plane"
            type="button"
            phx-click="add_plane"
            disabled={@available_colors == []}
          >Add plane</button>
          <button
            id="add-line"
            type="button"
            phx-click="add_line"
            disabled={@available_colors == []}
          >Add line</button>
          <button
            id="add-circle"
            type="button"
            phx-click="add_circle"
            disabled={@available_colors == []}
          >Add circle</button>
          <button
            id="add-point-pair"
            type="button"
            phx-click="add_point_pair"
            disabled={@available_colors == []}
          >Add point pair</button>
        </div>
      </div>
      <div class="toolbar">
        <fieldset>
          <legend>Zoom</legend>
          <input
            id="cga3-zoom"
            type="range"
            min="1"
            max="30"
            step="0.1"
            value={@camera.radius}
            phx-hook=".Zoom"
          />
        </fieldset>
      </div>
      <svg
        id="cga3-scene"
        class="scene"
        viewBox="-100 -100 200 200"
        preserveAspectRatio="xMidYMid slice"
        phx-hook=".Orb"
      >
        <g :for={object <- @scene_elements} id={"scene-object-#{object.id}"} stroke={object.color}>
          <%= cond do %>
            <% object.type == :plane -> %>
              <polygon
                :if={object.fill}
                points={
                  object.fill |> Enum.map(fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end) |> Enum.join(" ")
                }
                fill={object.color}
                class="plane-fill"
              />
              <polygon
                :for={points <- object.cells}
                points={points |> Enum.map(fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end) |> Enum.join(" ")}
                fill="none"
                class="grid-cell"
              />
            <% object.type == :sphere -> %>
              <ellipse
                :if={object.fill}
                cx={fr(object.fill.center_x)}
                cy={fr(object.fill.center_y)}
                rx={fr(object.fill.radius_a)}
                ry={fr(object.fill.radius_b)}
                transform={"rotate(#{fr(object.fill.angle * 180 / :math.pi())} #{fr(object.fill.center_x)} #{fr(object.fill.center_y)})"}
                fill={object.color}
                class="sphere-fill"
              />
              <line
                :for={ellipse <- object.ellipses}
                :if={fr(ellipse.radius_b) <= 0.0}
                x1={fr(ellipse.center_x - ellipse.radius_a)}
                y1={fr(ellipse.center_y)}
                x2={fr(ellipse.center_x + ellipse.radius_a)}
                y2={fr(ellipse.center_y)}
                transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
                class={["sphere-ring", ellipse.secondary && "sphere-ring-secondary"]}
              />
              <ellipse
                :for={ellipse <- object.ellipses}
                :if={fr(ellipse.radius_b) > 0.0}
                cx={fr(ellipse.center_x)}
                cy={fr(ellipse.center_y)}
                rx={fr(ellipse.radius_a)}
                ry={fr(ellipse.radius_b)}
                transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
                class={["sphere-ring", ellipse.secondary && "sphere-ring-secondary"]}
              />
            <% object.type == :circle -> %>
              <ellipse
                cx={fr(object.ellipse.center_x)}
                cy={fr(object.ellipse.center_y)}
                rx={fr(object.ellipse.radius_a)}
                ry={fr(object.ellipse.radius_b)}
                transform={"rotate(#{fr(object.ellipse.angle * 180 / :math.pi())} #{fr(object.ellipse.center_x)} #{fr(object.ellipse.center_y)})"}
                fill={object.color}
                class="scene-circle"
              />
            <% object.type == :point_pair -> %>
              <line
                x1={fr(elem(object.a, 0))}
                y1={fr(elem(object.a, 1))}
                x2={fr(elem(object.b, 0))}
                y2={fr(elem(object.b, 1))}
                opacity="0.65"
                class="point-pair-link"
              />
              <circle
                cx={fr(elem(object.a, 0))}
                cy={fr(elem(object.a, 1))}
                r={fr(2.5 / elem(object.a, 2))}
                fill={object.color}
                class="point-pair-point"
              />
              <circle
                cx={fr(elem(object.b, 0))}
                cy={fr(elem(object.b, 1))}
                r={fr(2.5 / elem(object.b, 2))}
                fill={object.color}
                class="point-pair-point"
              />
            <% object.type == :line -> %>
              <line
                x1={fr(object.x1)}
                y1={fr(object.y1)}
                x2={fr(object.x2)}
                y2={fr(object.y2)}
                class="scene-line"
              />
            <% true -> %>
          <% end %>
        </g>
        <g id="point-cloud" data-point-count={length(@projected_point_cloud)} opacity="0.65">
          <circle
            :for={{x, y, depth} <- @projected_point_cloud}
            cx={fr(x)}
            cy={fr(y)}
            r={fr(14 / depth)}
            fill="#f97316"
          />
        </g>
        <g
          id="transformed-point-cloud"
          data-point-count={length(@projected_transformed_point_cloud)}
          opacity="0.55"
        >
          <circle
            :for={{x, y, depth} <- @projected_transformed_point_cloud}
            cx={fr(x)}
            cy={fr(y)}
            r={fr(14 / depth)}
            fill="#2563eb"
          />
        </g>
      </svg>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Orb">
      export default {
        mounted() {
          let lastX, lastY;
          this.el.addEventListener("pointerdown", event => {
            if (event.isPrimary && (event.pointerType !== "mouse" || event.button === 0)) {
              this.el.setPointerCapture(event.pointerId);
              lastX = event.clientX;
              lastY = event.clientY;
            }
          });
          this.el.addEventListener("pointermove", event => {
            if (!this.el.hasPointerCapture(event.pointerId)) return;
            const dx = event.clientX - lastX;
            const dy = event.clientY - lastY;
            lastX = event.clientX;
            lastY = event.clientY;
            this.pushEvent("rot", {h: (dx / window.innerWidth * 20).toFixed(3), v: (dy / window.innerHeight * 20).toFixed(3)});
          });
          this.el.addEventListener("wheel", event => {
            event.preventDefault();
            this.pushEvent("zoom_by", {value: (event.deltaY / window.innerHeight * 2).toFixed(3)});
          }, {passive: false});
        }
      };
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Zoom">
      export default {
        mounted() {
          this.el.addEventListener("input", event => this.pushEvent("zoom", {value: event.target.value}));
        }
      };
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ElementPanels">
      export default {
        beforeUpdate() {
          this.openPanelIds = new Set(
            [...this.el.querySelectorAll("details")]
              .filter(panel => panel.open)
              .map(panel => panel.id),
          );
        },
        updated() {
          for (const panel of this.el.querySelectorAll("details")) {
            panel.open = this.openPanelIds?.has(panel.id) ?? false;
          }
        },
      };
    </script>
    """
  end
end
