defmodule GeomextricWeb.CGA3Live do
  use GeomextricWeb, :live_view

  alias Galixir.Algebras.CGA3
  alias Galixir.Algebras.PGA3
  alias GeomextricWeb.CGA3Motor

  import GeomextricWeb.Geometry,
    only: [
      fr: 1,
      project: 2,
      project_line: 3,
      project_camera_line: 2,
      project_camera_quad_for_ellipse: 1,
      project_polygon: 2,
      project_quad_for_ellipse: 2,
      quad_to_ellipse: 4
    ]

  import GeomextricWeb.Menu

  @vector_field_count 20
  @vector_field_debounce_ms 300

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

  def mount(%{}, _, socket) do
    {:ok,
     assign(socket,
       camera: %{yaw: 0.0, pitch: 0.3, radius: 10.0},
       focus: {0.0, 0.0, 0.0},
       elements: [],
       point_cloud: letter_point_cloud(),
       vector_field: vector_field_cloud(),
       vector_field_samples: empty_vector_field_samples(),
       vector_field_completed: MapSet.new(),
       vector_field_invalid_arrows: MapSet.new(),
       vector_field_transform_key: nil,
       vector_field_generation: 0,
       vector_field_computing: false,
       point_cloud_offset: %{x: 0.0, y: 0.0, z: 0.0},
       show_point_cloud: false,
       show_vector_field: false,
       show_scene_elements: true,
       show_sum_all: false,
       show_meet_all: true,
       show_gp_all: false,
       point_cloud_transform: "gp",
       element_slots: [],
       available_colors:
         @palette
         |> Enum.with_index()
         |> Enum.map(fn {color, slot} -> {slot, color} end)
     )}
  end

  defp offset_point(point, %{x: offset_x, y: offset_y, z: offset_z}) do
    {x, y, z} = CGA3.point_coordinates(point)
    CGA3.point(x + offset_x, y + offset_y, z + offset_z)
  end

  defp global_axis_directions(camera) do
    origin = camera_coordinates({0, 0, 0}, camera)
    origin_screen = perspective_project(origin)

    projected_axes =
      [
        {:x, "#ef4444", {1, 0, 0}},
        {:y, "#22c55e", {0, 1, 0}},
        {:z, "#3b82f6", {0, 0, 1}}
      ]
      |> Enum.map(fn {axis, color, point} ->
        endpoint = clip_axis_endpoint(origin, camera_coordinates(point, camera))
        {x, y} = perspective_project(endpoint)
        {axis, color, x - elem(origin_screen, 0), y - elem(origin_screen, 1)}
      end)

    longest =
      projected_axes
      |> Enum.map(fn {_axis, _color, x, y} -> :math.sqrt(x * x + y * y) end)
      |> Enum.max(fn -> 0.0 end)

    scale = if longest > 0, do: 30 / longest, else: 1.0

    Enum.map(projected_axes, fn {axis, color, x, y} ->
      %{axis: axis, color: color, x: x * scale, y: y * scale}
    end)
  end

  defp camera_coordinates(point, camera) do
    point
    |> then(fn {x, y, z} -> PGA3.point(x, y, z) end)
    |> PGA3.transform(camera)
    |> PGA3.point_coordinates()
  end

  defp perspective_project({x, y, z}), do: {100 * x / z, -100 * y / z}

  defp clip_axis_endpoint({origin_x, origin_y, origin_z}, {end_x, end_y, end_z}) do
    near = 0.05

    if end_z > near do
      {end_x, end_y, end_z}
    else
      t = (near - origin_z) / (end_z - origin_z)
      {origin_x + t * (end_x - origin_x), origin_y + t * (end_y - origin_y), near}
    end
  end

  defp project_vector_field(samples, completed, camera) do
    samples
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {[], _index} ->
        []

      {world_samples, index} ->
        projected =
          Enum.map(world_samples, fn {x, y, z} ->
            project(camera, PGA3.point(x, y, z))
          end)

        visible_paths =
          projected
          |> Enum.chunk_by(&is_nil/1)
          |> Enum.filter(fn
            [{_, _, _} | _] = path -> length(path) >= 2
            _ -> false
          end)

        marker_depth =
          case List.last(projected) do
            {_, _, depth} -> depth
            _ -> 10.0
          end

        [
          %{
            id: "vector-field-arrow-#{index}",
            marker_id: "cga3-vector-arrow-#{index}",
            marker_size: clamp(20 / marker_depth, 1, 4),
            paths: visible_paths,
            complete?:
              MapSet.member?(completed, index) and List.last(projected) != nil and
                length(visible_paths) == 1
          }
        ]
    end)
  end

  defp vector_field_paths_path(paths) do
    Enum.map_join(paths, " ", &vector_field_path/1)
  end

  defp vector_field_path(points) do
    case Enum.map(points, fn {x, y, _depth} -> {x, y} end) do
      [] ->
        ""

      [first, second | rest] ->
        "M #{vector_field_path_point(first)}" <>
          quadratic_path_segments([first, second | rest])
    end
  end

  defp quadratic_path_segments([_start, endpoint]) do
    " Q #{vector_field_path_point(endpoint)} #{vector_field_path_point(endpoint)}"
  end

  defp quadratic_path_segments([_start, control, next | rest]) do
    midpoint = {(elem(control, 0) + elem(next, 0)) / 2, (elem(control, 1) + elem(next, 1)) / 2}

    " Q #{vector_field_path_point(control)} #{vector_field_path_point(midpoint)}" <>
      quadratic_path_segments([midpoint, next | rest])
  end

  defp vector_field_path_point({x, y}), do: "#{fr(x)} #{fr(y)}"

  defp empty_vector_field_samples do
    List.duplicate([], @vector_field_count)
  end

  defp calculate_vector_field(points, transform, parent, generation) do
    Process.flag(:priority, :low)
    Process.sleep(@vector_field_debounce_ms)

    with {:ok, generator} <- CGA3Motor.interpolation_generator(transform),
         {:ok, motors} <- interpolated_motors(generator) do
      points
      |> Enum.with_index()
      |> Enum.each(fn {point, point_index} ->
        samples =
          Enum.reduce_while(motors, {:ok, []}, fn motor, {:ok, samples} ->
            case point |> CGA3.transform(motor) |> finite_point_coordinates() do
              {x, y, z} -> {:cont, {:ok, [{x, y, z} | samples]}}
              nil -> {:halt, :invalid}
            end
          end)

        case samples do
          {:ok, samples} ->
            send(parent, {:vector_field_arrow, generation, point_index, Enum.reverse(samples)})

          :invalid ->
            send(parent, {:vector_field_arrow_invalid, generation, point_index})
        end
      end)
    else
      _ -> send(parent, {:vector_field_invalid, generation})
    end

    send(parent, {:vector_field_done, generation})
    :ok
  end

  defp schedule_vector_field(socket) do
    socket = cancel_async(socket, :vector_field, :shutdown)
    generation = socket.assigns.vector_field_generation + 1
    transform = selected_transform(socket.assigns)

    socket =
      assign(socket,
        vector_field_transform_key: transform,
        vector_field_generation: generation,
        vector_field_samples: empty_vector_field_samples(),
        vector_field_completed: MapSet.new(),
        vector_field_invalid_arrows: MapSet.new(),
        vector_field_computing: socket.assigns.show_vector_field
      )

    if socket.assigns.show_vector_field do
      parent = self()
      points = socket.assigns.vector_field

      start_async(socket, :vector_field, fn ->
        calculate_vector_field(points, transform, parent, generation)
      end)
    else
      socket
    end
  end

  def handle_info({:vector_field_arrow, generation, point_index, samples}, socket) do
    if generation == socket.assigns.vector_field_generation and
         not MapSet.member?(socket.assigns.vector_field_invalid_arrows, point_index) do
      {:noreply,
       assign(socket,
         vector_field_samples:
           List.replace_at(socket.assigns.vector_field_samples, point_index, samples),
         vector_field_completed: MapSet.put(socket.assigns.vector_field_completed, point_index)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:vector_field_arrow_invalid, generation, point_index}, socket) do
    if generation == socket.assigns.vector_field_generation do
      {:noreply,
       assign(socket,
         vector_field_samples:
           List.replace_at(socket.assigns.vector_field_samples, point_index, []),
         vector_field_completed:
           MapSet.delete(socket.assigns.vector_field_completed, point_index),
         vector_field_invalid_arrows:
           MapSet.put(socket.assigns.vector_field_invalid_arrows, point_index)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:vector_field_invalid, generation}, socket) do
    if generation == socket.assigns.vector_field_generation do
      {:noreply,
       assign(socket,
         vector_field_samples: empty_vector_field_samples(),
         vector_field_completed: MapSet.new(),
         vector_field_computing: false
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:vector_field_done, generation}, socket) do
    if generation == socket.assigns.vector_field_generation do
      {:noreply, assign(socket, :vector_field_computing, false)}
    else
      {:noreply, socket}
    end
  end

  def handle_async(:vector_field, {:ok, :ok}, socket) do
    {:noreply, assign(socket, :vector_field_computing, false)}
  end

  def handle_async(:vector_field, {:exit, _reason}, socket) do
    {:noreply,
     assign(socket,
       vector_field_samples: empty_vector_field_samples(),
       vector_field_completed: MapSet.new(),
       vector_field_computing: false
     )}
  end

  defp selected_transform(assigns) do
    case assigns.point_cloud_transform do
      "sum" -> sum_all(assigns.elements)
      "wedge" -> meet_all(assigns.elements)
      "gp" -> gp_all(assigns.elements)
    end
  end

  defp interpolated_motors(generator) do
    Enum.reduce_while(0..10, {:ok, []}, fn step, {:ok, motors} ->
      case CGA3Motor.exp(CGA3.scale(-step / 5 / :math.pi(), generator)) do
        motor -> {:cont, {:ok, [motor | motors]}}
      end
    end)
    |> case do
      {:ok, motors} -> {:ok, Enum.reverse(motors)}
      :error -> :error
    end
  end

  defp project_point_cloud(points, camera) do
    Enum.flat_map(points, fn point ->
      case finite_point_coordinates(point) do
        {x, y, z} ->
          case project(camera, PGA3.point(x, y, z)) do
            nil -> []
            projected -> [projected]
          end

        nil ->
          []
      end
    end)
  end

  defp finite_point_coordinates(point) do
    CGA3.point_coordinates(point)
  rescue
    ArgumentError -> nil
  end

  defp vector_field_cloud do
    half_count = div(@vector_field_count, 2)
    golden_angle = :math.pi() * (3 - :math.sqrt(5))

    for index <- 0..(half_count - 1), reduce: [] do
      points ->
        direction_y = 1 - 2 * (index + 0.5) / half_count
        ring_radius = :math.sqrt(1 - direction_y * direction_y)
        angle = golden_angle * index
        radius = 3.0 * :math.pow((index + 0.5) / half_count, 1 / 3)
        x = radius * ring_radius * :math.cos(angle)
        y = radius * direction_y
        z = radius * ring_radius * :math.sin(angle)

        [CGA3.point(x, y, z), CGA3.point(-x, -y, -z) | points]
    end
    |> Enum.reverse()
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

  def handle_event("add_point", %{"axis" => "origin"}, socket) do
    add_element(socket, CGA3.new(e123: 1.0))
  end

  def handle_event("add_point", %{"axis" => axis}, socket) when axis in ["x", "y", "z"] do
    {x, y, z} = axis_vector(axis, 1.0)
    point = point_reflection(x, y, z) |> CGA3.dual()
    add_element(socket, point)
  end

  def handle_event("add_sphere", %{"axis" => "origin"}, socket) do
    add_element(socket, CGA3.new(ep: 1.0))
  end

  def handle_event("add_sphere", %{"axis" => axis}, socket) when axis in ["x", "y", "z"] do
    {x, y, z} = axis_vector(axis, 1.0)
    sphere = CGA3.sphere(x, y, z, 1.0) |> CGA3.dual()
    add_element(socket, sphere)
  end

  def handle_event("add_line", %{"axis" => axis}, socket) when axis in ["x", "y", "z"] do
    line =
      case axis do
        "x" -> CGA3.new(e23: 1.0)
        "y" -> CGA3.new(e13: 1.0)
        "z" -> CGA3.new(e12: 1.0)
      end

    add_element(socket, line)
  end

  def handle_event("add_circle", %{"axis" => axis}, socket) when axis in ["x", "y", "z"] do
    circle =
      case axis do
        "x" -> CGA3.new(e1p: 1.0)
        "y" -> CGA3.new(e2p: 1.0)
        "z" -> CGA3.new(e3p: 1.0)
      end

    add_element(socket, circle)
  end

  def handle_event("add_point_pair", %{"axis" => axis}, socket)
      when axis in ["x", "y", "z"] do
    pair =
      case axis do
        "x" -> CGA3.new(e1m: 1.0)
        "y" -> CGA3.new(e2m: 1.0)
        "z" -> CGA3.new(e3m: 1.0)
      end

    add_element(socket, pair)
  end

  def handle_event("add_plane", %{"axis" => axis}, socket) when axis in ["x", "y", "z"] do
    plane =
      case axis do
        "x" -> CGA3.new(e1: 1.0)
        "y" -> CGA3.new(e2: 1.0)
        "z" -> CGA3.new(e3: 1.0)
      end

    add_element(socket, plane)
  end

  def handle_event("toggle_representation", %{"index" => index}, socket) do
    transform_element(socket, index, &CGA3.dual/1)
  end

  def handle_event("negate_element", %{"index" => index}, socket) do
    transform_element(socket, index, &CGA3.scale(-1, &1))
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

      socket =
        assign(socket,
          elements: elements,
          element_slots: slots,
          available_colors: available_colors,
          show_sum_all: socket.assigns.show_sum_all,
          show_meet_all: socket.assigns.show_meet_all,
          show_gp_all: socket.assigns.show_gp_all,
          point_cloud_transform: socket.assigns.point_cloud_transform
        )

      {:noreply, schedule_vector_field(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_point_cloud", %{"point_cloud" => value}, socket) do
    {:noreply, assign(socket, :show_point_cloud, value == "on")}
  end

  def handle_event("toggle_vector_field", %{"vector_field" => value}, socket) do
    socket = assign(socket, :show_vector_field, value == "on")
    {:noreply, schedule_vector_field(socket)}
  end

  def handle_event("toggle_scene_elements", %{"scene_elements" => value}, socket) do
    {:noreply, assign(socket, :show_scene_elements, value == "on")}
  end

  def handle_event("apply_sum_all", %{}, socket) do
    {:noreply, socket |> apply_scene_result(:sum) |> schedule_vector_field()}
  end

  def handle_event("apply_meet_all", %{}, socket) do
    {:noreply, socket |> apply_scene_result(:meet) |> schedule_vector_field()}
  end

  def handle_event("apply_gp_all", %{}, socket) do
    {:noreply, socket |> apply_scene_result(:gp) |> schedule_vector_field()}
  end

  def handle_event("toggle_sum_all", %{"sum_all" => value}, socket) do
    {:noreply, assign(socket, :show_sum_all, value == "on")}
  end

  def handle_event("toggle_meet_all", %{"meet_all" => value}, socket) do
    {:noreply, assign(socket, :show_meet_all, value == "on")}
  end

  def handle_event("toggle_gp_all", %{"gp_all" => value}, socket) do
    {:noreply, assign(socket, :show_gp_all, value == "on")}
  end

  def handle_event(
        "change_point_cloud_transform",
        %{"point_cloud_transform" => transform},
        socket
      )
      when transform in ["sum", "wedge", "gp"] do
    socket = assign(socket, :point_cloud_transform, transform)
    {:noreply, schedule_vector_field(socket)}
  end

  def handle_event("change_point_cloud_offset", %{"x" => x, "y" => y, "z" => z}, socket) do
    offset = %{
      x: clamp(parse_number(x), -10, 10),
      y: clamp(parse_number(y), -10, 10),
      z: clamp(parse_number(z), -10, 10)
    }

    {:noreply, assign(socket, :point_cloud_offset, offset)}
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

      socket = assign(socket, :elements, elements)
      {:noreply, schedule_vector_field(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  defp transform_element(socket, index, transform) do
    with {index, ""} <- Integer.parse(index),
         true <- index >= 0,
         {object, color} when is_binary(color) <- Enum.at(socket.assigns.elements, index) do
      elements =
        List.update_at(socket.assigns.elements, index, fn {_object, old_color} ->
          {transform.(object), old_color}
        end)

      socket = assign(socket, :elements, elements)
      {:noreply, schedule_vector_field(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  defp apply_scene_result(socket, operation) do
    result =
      case operation do
        :sum -> sum_all(socket.assigns.elements)
        :meet -> meet_all(socket.assigns.elements)
        :gp -> gp_all(socket.assigns.elements)
      end

    case {socket.assigns.elements, socket.assigns.available_colors} do
      {[{_first, color} | _rest], _available} ->
        slot = hd(socket.assigns.element_slots)
        restore_slots = Enum.drop(socket.assigns.element_slots, 1)

        available_colors =
          (socket.assigns.available_colors ++
             Enum.map(restore_slots, &{&1, Enum.at(@palette, &1)}))
          |> Enum.sort_by(&elem(&1, 0))

        assign(socket,
          elements: [{result, color}],
          element_slots: [slot],
          available_colors: available_colors
        )

      {[], [{slot, color} | remaining]} ->
        assign(socket,
          elements: [{result, color}],
          element_slots: [slot],
          available_colors: remaining
        )

      {[], []} ->
        socket
    end
  end

  defp add_element(socket, object) do
    case socket.assigns.available_colors do
      [{slot, color} | remaining] ->
        socket =
          assign(socket,
            elements: socket.assigns.elements ++ [{object, color}],
            element_slots: socket.assigns.element_slots ++ [slot],
            available_colors: remaining
          )

        {:noreply, schedule_vector_field(socket)}

      [] ->
        {:noreply, socket}
    end
  end

  defp update_element(object, params) do
    case editable_element(object) do
      {primitive, _type, representation} ->
        updated = update_primitive_element(primitive, params)
        if representation == :reflecting, do: CGA3.dual(updated), else: updated

      :unknown ->
        object
    end
  end

  defp update_primitive_element(object, params) do
    cond do
      scene_point_coordinates(object) != nil ->
        {x, y, z} = scene_point_coordinates(object)
        x = number_param(params, "x", x)
        y = number_param(params, "y", y)
        z = number_param(params, "z", z)

        if point_reflection_coordinates(object) != nil do
          point_reflection(x, y, z)
        else
          CGA3.point(x, y, z)
        end

      CGA3.sphere?(object) ->
        case CGA3.sphere_parameters(object) do
          {:sphere, {kind, {x, y, z}, radius}} when kind in [:real, :imag, :tangent] ->
            CGA3.sphere(
              number_param(params, "x", x),
              number_param(params, "y", y),
              number_param(params, "z", z),
              number_param(params, "radius", if(kind == :imag, do: -radius, else: radius))
            )

          _ ->
            object
        end

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

            CGA3.point_pair(point_a, point_b)

          {:tangent, {x, y, z}} ->
            point =
              CGA3.point(
                number_param(params, "ax", x),
                number_param(params, "ay", y),
                number_param(params, "az", z)
              )

            CGA3.point_pair(point, point)

          {:imag, _center, _radius, _direction} ->
            object
        end

      CGA3.circle?(object) ->
        case CGA3.circle_parameters(object) do
          {:circle, {kind, {x, y, z}, radius, {nx, ny, nz}}}
          when kind in [:real, :imag, :tangent] ->
            normal = {
              number_param(params, "nx", nx),
              number_param(params, "ny", ny),
              number_param(params, "nz", nz)
            }

            if vector_length(normal) > 1.0e-6 do
              signed_radius = if kind == :imag, do: -radius, else: radius

              CGA3.circle(
                {
                  number_param(params, "x", x),
                  number_param(params, "y", y),
                  number_param(params, "z", z)
                },
                number_param(params, "radius", signed_radius),
                normal
              )
            else
              object
            end

          _ ->
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

  defp axis_vector("x", magnitude), do: {magnitude, 0, 0}
  defp axis_vector("y", magnitude), do: {0, magnitude, 0}
  defp axis_vector("z", magnitude), do: {0, 0, magnitude}

  defp element_controls({object, color}) do
    case editable_element(object) do
      {primitive, _type, _representation} -> primitive_element_controls({primitive, color})
      :unknown -> []
    end
  end

  defp primitive_element_controls({object, _color}) do
    cond do
      scene_point_coordinates(object) != nil ->
        {x, y, z} = scene_point_coordinates(object)
        [{"X", "x", x, -6, 6, 0.1}, {"Y", "y", y, -6, 6, 0.1}, {"Z", "z", z, -6, 6, 0.1}]

      CGA3.sphere?(object) ->
        case CGA3.sphere_parameters(object) do
          {:sphere, {kind, {x, y, z}, radius}} when kind in [:real, :imag, :tangent] ->
            [
              {"Center X", "x", x, -6, 6, 0.1},
              {"Center Y", "y", y, -6, 6, 0.1},
              {"Center Z", "z", z, -6, 6, 0.1},
              {"Radius", "radius", if(kind == :imag, do: -radius, else: radius), -5, 5, 0.1}
            ]

          _ ->
            []
        end

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

          {:imag, _center, _radius, _direction} ->
            []
        end

      CGA3.circle?(object) ->
        case CGA3.circle_parameters(object) do
          {:circle, {kind, {x, y, z}, radius, {nx, ny, nz}}}
          when kind in [:real, :imag, :tangent] ->
            [
              {"Center X", "x", x, -6, 6, 0.1},
              {"Center Y", "y", y, -6, 6, 0.1},
              {"Center Z", "z", z, -6, 6, 0.1},
              {"Radius", "radius", if(kind == :imag, do: -radius, else: radius), -5, 5, 0.1},
              {"Normal X", "nx", nx, -1, 1, 0.01},
              {"Normal Y", "ny", ny, -1, 1, 0.01},
              {"Normal Z", "nz", nz, -1, 1, 0.01}
            ]

          _ ->
            []
        end

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
    label =
      case editable_element(object) do
        {_primitive, type, representation} ->
          "#{representation_label(representation)} #{element_type_label(type)}"

        :unknown ->
          "Unknown"
      end

    "#{label} #{index + 1}"
  end

  defp editable_element(object) do
    direct_type = primitive_element_type(object)
    reflected_object = CGA3.undual(object)
    reflected_type = primitive_element_type(reflected_object)

    cond do
      reflected_type == :sphere and direct_type != :sphere ->
        {reflected_object, :sphere, :reflecting}

      direct_type == :point_pair and reflected_type == :circle and
          imaginary_point_pair?(object) ->
        {reflected_object, :circle, :reflecting}

      direct_type != nil ->
        {object, direct_type, :directing}

      reflected_type != nil ->
        {reflected_object, reflected_type, :reflecting}

      true ->
        :unknown
    end
  end

  defp imaginary_point_pair?(object) do
    match?({:imag, _, _, _}, CGA3.point_pair_parameters(object))
  end

  defp representation_label(:directing), do: "Directing"
  defp representation_label(:reflecting), do: "Reflecting"

  defp primitive_element_type(object) do
    cond do
      scene_point_coordinates(object) != nil -> :point
      CGA3.sphere?(object) -> :sphere
      CGA3.circle?(object) -> :circle
      CGA3.point_pair?(object) -> :point_pair
      CGA3.plane?(object) -> :plane
      CGA3.line?(object) -> :line
      true -> nil
    end
  end

  defp element_type_label(:point), do: "Point"
  defp element_type_label(:sphere), do: "Sphere"
  defp element_type_label(:circle), do: "Circle"
  defp element_type_label(:point_pair), do: "Point pair"
  defp element_type_label(:plane), do: "Plane"
  defp element_type_label(:line), do: "Line"

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
    case CGA3.sphere_parameters(sphere) do
      {:sphere, {:real, center, radius}} ->
        sphere_ellipses(camera, center, radius, false)

      {:sphere, {:imag, center, radius}} ->
        sphere_ellipses(camera, center, radius, true)

      {:sphere, {:tangent, {x, y, z}, _radius}} ->
        tangent =
          case project(camera, PGA3.point(x, y, z)) do
            {screen_x, screen_y, depth} -> {screen_x, screen_y, depth}
            _ -> nil
          end

        %{
          ellipses: [],
          fill: nil,
          depth: if(tangent, do: elem(tangent, 2), else: 0),
          tangent: tangent,
          imaginary: false
        }

      _ ->
        %{ellipses: [], fill: nil, depth: 0, tangent: nil, imaginary: false}
    end
  end

  defp sphere_ellipses(camera, {x, y, z}, radius, imaginary) do
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
          Enum.map(points, fn {px, py, pz} -> PGA3.point(px, py, pz) end)
          |> then(&project_quad_for_ellipse(camera, &1))

        case projected do
          [{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}] ->
            ellipse = quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})

            ellipse =
              if fr(ellipse.radius_b) <= 0.0 do
                projected_circle_line(
                  camera,
                  {x + cx, y + cy, z + cz},
                  circle_radius,
                  {ax, ay, az},
                  {bx, by, bz},
                  ellipse
                )
              else
                ellipse
              end

            Map.put(ellipse, :secondary, secondary)

          points when length(points) >= 3 ->
            %{points: points, secondary: secondary}

          _ ->
            nil
        end
      end)

    ellipses = Enum.reject(ellipses, &is_nil/1)

    case center do
      {_screen_x, _screen_y, depth} ->
        %{ellipses: ellipses, fill: fill, depth: depth, tangent: nil, imaginary: imaginary}

      _ ->
        %{ellipses: ellipses, fill: fill, depth: 0, tangent: nil, imaginary: imaginary}
    end
  end

  defp projected_circle_line(camera, {cx, cy, cz}, radius, {ax, ay, az}, {bx, by, bz}, fallback) do
    center = camera_coordinates({cx, cy, cz}, camera)
    axis_a = camera_coordinates({cx + radius * ax, cy + radius * ay, cz + radius * az}, camera)
    axis_b = camera_coordinates({cx + radius * bx, cy + radius * by, cz + radius * bz}, camera)
    {center_x, center_y, center_z} = center
    {axis_ax, axis_ay, axis_az} = axis_a
    {axis_bx, axis_by, axis_bz} = axis_b

    u = {axis_ax - center_x, axis_ay - center_y, axis_az - center_z}
    v = {axis_bx - center_x, axis_by - center_y, axis_bz - center_z}
    direction_x = :math.cos(fallback.angle)
    direction_y = :math.sin(fallback.angle)

    n0 = 100 * (direction_x * center_x - direction_y * center_y)
    n1 = 100 * (direction_x * elem(u, 0) - direction_y * elem(u, 1))
    n2 = 100 * (direction_x * elem(v, 0) - direction_y * elem(v, 1))
    d0 = center_z
    d1 = elem(u, 2)
    d2 = elem(v, 2)

    constant = n2 * d1 - n1 * d2
    cos_coefficient = n2 * d0 - n0 * d2
    sin_coefficient = n0 * d1 - n1 * d0
    amplitude = :math.sqrt(cos_coefficient * cos_coefficient + sin_coefficient * sin_coefficient)

    if amplitude > 1.0e-12 do
      ratio = -constant / amplitude

      if abs(ratio) < 1.0 do
        phase = :math.atan2(sin_coefficient, cos_coefficient)
        offset = :math.acos(ratio)
        angles = [phase - offset, phase + offset]

        projected =
          Enum.map(angles, fn angle ->
            cos = :math.cos(angle)
            sin = :math.sin(angle)

            point =
              PGA3.point(
                cx + radius * (ax * cos + bx * sin),
                cy + radius * (ay * cos + by * sin),
                cz + radius * (az * cos + bz * sin)
              )

            project(camera, point)
          end)

        case projected do
          [{x1, y1, _}, {x2, y2, _}] ->
            dx = x2 - x1
            dy = y2 - y1

            %{
              center_x: (x1 + x2) / 2,
              center_y: (y1 + y2) / 2,
              radius_a: :math.sqrt(dx * dx + dy * dy) / 2,
              radius_b: 0.0,
              angle: :math.atan2(dy, dx)
            }

          _ ->
            fallback
        end
      else
        fallback
      end
    else
      fallback
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

      projected = project_camera_quad_for_ellipse(camera_points)

      case projected do
        [{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}] ->
          quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})

        points when length(points) >= 3 ->
          %{points: points}

        _ ->
          nil
      end
    end
  rescue
    ArgumentError -> nil
  end

  defp finite_number?(number),
    do: is_number(number) and number == number and abs(number) < 1.0e300

  defp point_pair_geometry(camera, pair) do
    case CGA3.point_pair_parameters(pair) do
      {:real, {ax, ay, az}, {bx, by, bz}} ->
        case project_line(camera, PGA3.point(ax, ay, az), PGA3.point(bx, by, bz)) do
          {{screen_ax, screen_ay, depth_a}, {screen_bx, screen_by, depth_b}} ->
            %{
              a: {screen_ax, screen_ay, depth_a},
              b: {screen_bx, screen_by, depth_b},
              a_visible: not is_nil(project(camera, PGA3.point(ax, ay, az))),
              b_visible: not is_nil(project(camera, PGA3.point(bx, by, bz))),
              depth: (depth_a + depth_b) * 0.5
            }

          _ ->
            nil
        end

      {:tangent, {x, y, z}} ->
        case project(camera, PGA3.point(x, y, z)) do
          {px, py, depth} ->
            %{
              a: {px, py, depth},
              b: {px, py, depth},
              a_visible: true,
              b_visible: true,
              depth: depth
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp circle_geometry(camera, circle) do
    case CGA3.circle_parameters(circle) do
      {:circle, {:real, center, radius, normal}} ->
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
          |> Enum.map(fn {px, py, pz} -> PGA3.point(px, py, pz) end)
          |> then(&project_quad_for_ellipse(camera, &1))

        case {projected, project(camera, PGA3.point(x, y, z))} do
          {[{x1, y1, _}, {x2, y2, _}, {x3, y3, _}, {x4, y4, _}], {_cx, _cy, depth}} ->
            ellipse = quad_to_ellipse({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4})
            %{ellipse: ellipse, depth: depth}

          {points, {_cx, _cy, depth}} when length(points) >= 3 ->
            %{polygon: points, depth: depth}

          _ ->
            nil
        end

      {:circle, {:tangent, {x, y, z}, _radius, _normal}} ->
        case project(camera, PGA3.point(x, y, z)) do
          {projected_x, projected_y, depth} ->
            %{tangent: true, x: projected_x, y: projected_y, depth: depth}

          _ ->
            nil
        end

      {:circle, {:imag, _center, _radius, _normal}} ->
        case point_pair_geometry(camera, CGA3.dual(circle)) do
          nil -> nil
          geometry -> Map.put(geometry, :type, :point_pair)
        end

      _ ->
        nil
    end
  end

  defp scene_point_coordinates(object) do
    if CGA3.point?(object) do
      CGA3.point_coordinates(object)
    else
      meet_point_coordinates(object)
    end
  end

  defp point_reflection_coordinates(object) do
    if CGA3.grades(object) == [2] do
      epm = CGA3.coefficient(object, :epm)
      coordinates = meet_point_coordinates(object)

      if coordinates != nil and epm != 0 do
        coordinates
      end
    end
  end

  defp point_reflection(x, y, z) do
    CGA3.new(e1p: x, e1m: x, e2p: y, e2m: y, e3p: z, e3m: z, epm: -1)
  end

  defp meet_point_coordinates(object) do
    if CGA3.grades(object) == [2] do
      epm = CGA3.coefficient(object, :epm)
      e1p = CGA3.coefficient(object, :e1p)
      e1m = CGA3.coefficient(object, :e1m)
      e2p = CGA3.coefficient(object, :e2p)
      e2m = CGA3.coefficient(object, :e2m)
      e3p = CGA3.coefficient(object, :e3p)
      e3m = CGA3.coefficient(object, :e3m)
      e12 = CGA3.coefficient(object, :e12)
      e13 = CGA3.coefficient(object, :e13)
      e23 = CGA3.coefficient(object, :e23)

      scale = Enum.max_by([epm, e1p, e1m, e2p, e2m, e3p, e3m, e12, e13, e23], &abs/1) |> abs()
      tolerance = scale * 1.0e-8

      if epm != 0 and scale > 0 and
           Enum.all?([e1p - e1m, e2p - e2m, e3p - e3m, e12, e13, e23], &(abs(&1) <= tolerance)) do
        {-e1p / epm, -e2p / epm, -e3p / epm}
      end
    end
  end

  defp point_geometry(camera, point) do
    {x, y, z} = scene_point_coordinates(point)

    case project(camera, PGA3.point(x, y, z)) do
      {screen_x, screen_y, depth} -> %{x: screen_x, y: screen_y, depth: depth}
      _ -> nil
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

        case project_camera_line({x1, y1, z1}, {x2, y2, z2}) do
          {{screen_x1, screen_y1, depth1}, {screen_x2, screen_y2, depth2}} ->
            %{
              x1: screen_x1,
              y1: screen_y1,
              x2: screen_x2,
              y2: screen_y2,
              depth: (depth1 + depth2) * 0.5
            }

          _ ->
            nil
        end

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

        points = [
          point_on_plane(origin, u, v, u0, v0),
          point_on_plane(origin, u, v, u1, v0),
          point_on_plane(origin, u, v, u1, v1),
          point_on_plane(origin, u, v, u0, v1)
        ]

        projected =
          Enum.map(points, fn {x, y, z} -> PGA3.point(x, y, z) end)
          |> then(&project_polygon(camera, &1))

        if length(projected) >= 3, do: projected, else: nil
      end
      |> Enum.reject(&is_nil/1)

    fill =
      [
        point_on_plane(origin, u, v, -extent, -extent),
        point_on_plane(origin, u, v, extent, -extent),
        point_on_plane(origin, u, v, extent, extent),
        point_on_plane(origin, u, v, -extent, extent)
      ]
      |> Enum.map(fn {x, y, z} -> PGA3.point(x, y, z) end)
      |> then(&project_polygon(camera, &1))

    center = project(camera, PGA3.point(elem(origin, 0), elem(origin, 1), elem(origin, 2)))
    fill = if length(fill) >= 3, do: fill, else: nil

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

  defp sum_all(elements) do
    case Enum.map(elements, fn {element, _color} ->
           case CGA3.normalize(element) do
             {:ok, normalized} -> normalized
             :error -> element
           end
         end) do
      [] ->
        CGA3.new(scalar: 0)

      [first | rest] ->
        Enum.reduce(rest, first, &CGA3.add/2)
    end
  end

  defp meet_all([]), do: CGA3.new(scalar: 1)

  defp meet_all([{element, _color}]), do: element

  defp meet_all([{first, _color} | rest]) do
    Enum.reduce(rest, first, fn {element, _color}, result ->
      CGA3.wedge(result, element)
    end)
  end

  defp gp_all([]), do: CGA3.new(scalar: 1)

  defp gp_all([{first, _color} | rest]) do
    Enum.reduce(rest, first, fn {element, _color}, result ->
      CGA3.gp(result, element)
    end)
  end

  defp classify_elements(elements, camera) do
    elements
    |> Enum.with_index()
    |> Enum.flat_map(fn {{element, color}, index} ->
      components = grade_components(element)

      Enum.flat_map(components, fn {component, grade} ->
        case classify_component(component, camera) do
          nil ->
            []

          {type, geometry} ->
            id = if grade, do: "#{index}-grade-#{grade}", else: index
            [Map.merge(%{id: id, color: color, type: type}, geometry)]
        end
      end)
    end)
    |> Enum.sort_by(& &1.depth, :desc)
  end

  defp grade_components(element) do
    case CGA3.grades(element) do
      [_grade] ->
        [{element, nil}]

      grades ->
        Enum.map(grades, fn grade -> {CGA3.grade(element, grade), grade} end)
    end
  end

  defp classify_component(element, camera) do
    case editable_element(element) do
      {primitive, _type, _representation} ->
        classify_direct(primitive, camera)

      :unknown ->
        case classify_direct(element, camera) do
          nil -> classify_direct(CGA3.dual(element), camera)
          classified -> classified
        end
    end
  end

  defp classify_direct(element, camera) do
    cond do
      scene_point_coordinates(element) != nil ->
        case point_geometry(camera, element) do
          nil -> nil
          geometry -> {:point, geometry}
        end

      CGA3.sphere?(element) ->
        {:sphere, sphere_ellipses(camera, element)}

      CGA3.plane?(element) ->
        {:plane, plane_grid(camera, element)}

      CGA3.point_pair?(element) ->
        case point_pair_geometry(camera, element) do
          nil -> nil
          geometry -> {:point_pair, geometry}
        end

      CGA3.circle?(element) ->
        case circle_geometry(camera, element) do
          nil -> nil
          geometry -> {Map.get(geometry, :type, :circle), geometry}
        end

      CGA3.line?(element) ->
        case line_geometry(camera, element) do
          nil -> nil
          geometry -> {:line, geometry}
        end

      true ->
        nil
    end
  end

  def render(assigns) do
    camera = camera_transform(assigns.camera, assigns.focus)
    elements = classify_elements(assigns.elements, camera)

    ground_grid =
      classify_elements([{CGA3.plane({0, 0, 1}, 0), "#64748b"}], camera)
      |> Enum.map(fn grid -> %{grid | id: "ground-grid", fill: nil} end)

    sum_result = sum_all(assigns.elements)
    meet_result = meet_all(assigns.elements)
    gp_result = gp_all(assigns.elements)

    sum_elements =
      if assigns.show_sum_all and length(assigns.elements) >= 2 and sum_result do
        classify_elements([{sum_result, "#7c3aed"}], camera)
        |> Enum.with_index()
        |> Enum.map(fn {element, index} ->
          id = if index == 0, do: "sum-all-result", else: "sum-all-result-#{index}"
          %{element | id: id, color: "#7c3aed"}
        end)
      else
        []
      end

    meet_elements =
      if assigns.show_meet_all and length(assigns.elements) >= 2 and meet_result do
        classify_elements([{meet_result, "#dc2626"}], camera)
        |> Enum.with_index()
        |> Enum.map(fn {element, index} ->
          id = if index == 0, do: "meet-all-result", else: "meet-all-result-#{index}"
          %{element | id: id, color: "#dc2626"}
        end)
      else
        []
      end

    gp_elements =
      if assigns.show_gp_all and length(assigns.elements) >= 2 and gp_result do
        classify_elements([{gp_result, "#0891b2"}], camera)
        |> Enum.with_index()
        |> Enum.map(fn {element, index} ->
          id = if index == 0, do: "gp-all-result", else: "gp-all-result-#{index}"
          %{element | id: id, color: "#0891b2"}
        end)
      else
        []
      end

    transform =
      case assigns.point_cloud_transform do
        "sum" -> sum_result
        "wedge" -> meet_result
        "gp" -> gp_result
      end

    {offset_points, transformed_points} =
      if assigns.show_point_cloud do
        offset_points =
          Enum.map(assigns.point_cloud, &offset_point(&1, assigns.point_cloud_offset))

        transformed_points =
          if CGA3.zero?(transform) do
            []
          else
            Enum.map(offset_points, &CGA3.transform(&1, transform))
          end

        {offset_points, transformed_points}
      else
        {[], []}
      end

    assigns =
      assign(assigns,
        camera_transform: camera,
        global_axes: global_axis_directions(camera),
        ground_grid: ground_grid,
        scene_elements: elements ++ sum_elements ++ meet_elements ++ gp_elements,
        sum_expression: inspect(sum_result, limit: :infinity),
        meet_expression: inspect(meet_result, limit: :infinity),
        gp_expression: inspect(gp_result, limit: :infinity),
        projected_point_cloud: project_point_cloud(offset_points, camera),
        projected_transformed_point_cloud: project_point_cloud(transformed_points, camera),
        projected_vector_field:
          if(assigns.show_vector_field,
            do:
              project_vector_field(
                assigns.vector_field_samples,
                assigns.vector_field_completed,
                camera
              ),
            else: []
          )
      )

    ~H"""
    <style :type={GeomextricWeb.ColocatedScopedCSS}>
      .screen { position: absolute; inset: 0; }
      .scene { position: absolute; inset: 0; touch-action: none; }
      .axis-indicator {
        position: fixed;
        z-index: 1000;
        right: 1rem;
        bottom: 1rem;
        width: 7.5rem;
        height: 7.5rem;
        padding: .35rem;
        pointer-events: none;
      }

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
              flex-wrap: wrap;
              align-items: center;
              gap: 1ex;
              background: #0003;
              border-radius: 1ex;
            }

      @keyframes vector-field-fade-in {
        from { opacity: 0; }
        to { opacity: 1; }
      }
      .vector-field-arrow {
        animation: vector-field-fade-in .35s ease-out both;
      }
      .toolbar input[type="checkbox"] { display: none; }
      .toolbar button {
        align-self: stretch;
        border: 0;
        border-radius: .5ex;
        padding: .5ex .75ex;
        color: #fff;
        background: #0008;
        cursor: pointer;
      }
      .toolbar button:hover { background: #000c; }
      .toolbar button:focus-visible { outline: 2px solid #fff; }

      .toolbar fieldset {
        display: flex;
      }
      .point-cloud-offsets legend { padding: 0 .25rem; font-size: .75rem; }
      .point-cloud-offsets label { display: grid; gap: .2rem; font-size: .7rem; }
      .point-cloud-offsets input { width: 100%; min-width: 0; margin: 0;  }
      .toolbar label:has(input[type="checkbox"]) {
        align-self: stretch;
        display: flex;
        align-items: center;
        border-radius: .5ex;
        padding: .5ex;
        margin: 0;
        background: #0001;
        user-select: none;
        filter: saturate(0%) brightness(500%);
        cursor: pointer;
      }
      .toolbar label:has(input[type="checkbox"]:checked) {
        background: #000a;
        filter: saturate(100%);
      }
      .toolbar label:has(input[type="checkbox"]:focus-visible) { outline: 2px solid #fff; }
            .elements-panel {
            display: grid;
            grid-template-rows: auto 1fr auto;
              position: fixed;
              z-index: 1000;
              left: 1rem;
              bottom: 1rem;
              width: min(21rem, calc(100vw - 2rem));
              max-height: 70vh;
              padding: .75rem;
              color: #222;
              background: #fffffff0;
              border: 1px solid #0002;
              border-radius: .75rem;
              box-shadow: 0 .5rem 1.5rem #0002;
            }
            .elements-list {
              height: 100%;
              overflow: auto;
              border-bottom: 1px solid #0002;
              display: flex;
              flex-direction: column;
            }
            .elements-list.empty {
            border: none;
            }
            .elements-list.empty::after {
              content: "None";
              text-align: center;
              justify-self: center;
              color: #888;
            }
            .elements-panel h2 { margin: 0 0 .5rem; font-size: .95rem; }
            .element-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .3rem 0; }
            .element-actions { margin-top: .75rem; }
            .element-side-actions { display: flex; align-items: center; gap: .2rem; margin-left: auto; }
            .element-operations { display: flex; gap: .2rem; }
            .element-operation {
              border: 1px solid #0002;
              border-radius: .3rem;
              padding: .1rem .3rem;
              color: #333;
              background: #fff;
              font-size: .65rem;
              line-height: 1.2;
              cursor: pointer;
            }
            .element-operation:hover { background: #f3f4f6; }
                        .element-actions-label { display: block; margin-bottom: .25rem; font-size: .75rem; font-weight: 600; }
                        .element-action-buttons { display: flex; flex-wrap: wrap; gap: .3rem; }
                        .axis-add-group {
                          position: relative;
                          display: flex;
                          min-width: 4.8rem;
                          height: 1.65rem;
                          overflow: hidden;
                          border: 0;
                          border-radius: .35rem;
                          background: #1f2937;
                        }
                        .axis-add-label {
                          z-index: 1;
                          inset: 0;
                          padding: 0 1ex 0 2ex;
                          align-self: center;
                          place-items: center;
                          color: #fff;
                          font-size: .7rem;
                          font-weight: 600;
                          pointer-events: none;
                          transition: opacity .15s ease;
                        }

                        .axis-add-group.expanded .axis-add-label { opacity: 0; }
                        .axis-add-options button {
                          flex: 1;
                          min-width: 1.45rem;
                          padding: .15rem .25rem;
                          border: 0;
                          border-radius: 0;
                          color: #fff;
                          background: transparent;
                          font-size: .7rem;
                          cursor: pointer;
                        }
                        .axis-add-options button:hover,
                        .axis-add-options button:focus-visible { color: #fff; background: #4b5563; outline: none; }
                        .axis-add-options button:disabled { opacity: .45; cursor: not-allowed; }
            .derived-results { margin-top: .75rem; }
            .derived-result { padding-top: .5rem; }
            .derived-result + .derived-result { margin-top: .25rem; border-top: 1px solid #0001; }
            .derived-result-row { display: grid; grid-template-columns: auto minmax(0, 1fr) auto auto auto; align-items: center; gap: .4rem; }
            .derived-result-title { grid-column: 1; grid-row: 1; display: flex; align-items: center; gap: .35rem; white-space: nowrap; }
                        .derived-result-title strong { font-size: .8rem; }
                        .derived-result-title label { display: flex; align-items: center; gap: .15rem; margin: 0; font-size: .65rem; cursor: pointer; }
                        .derived-result-title label:has(input:disabled) { opacity: .45; cursor: not-allowed; }
                        .derived-result-row form.render-result { grid-column: 4; grid-row: 1; }
                        .derived-result-row form.transform-choice { grid-column: 3; grid-row: 1; }
                        .derived-result-row .apply-result { grid-column: 5; grid-row: 1; }
                        .derived-result-row .element-expression { grid-column: 2; grid-row: 1; }
            .derived-result-row form, .derived-result-row label { margin: 0; }
                        .apply-result { padding: .2rem .35rem; border: 1px solid #111827; border-radius: .3rem; color: #fff; background: #1f2937; font-size: .65rem; font-weight: 600; cursor: pointer; }
                        .apply-result:hover { background: #111827; }
            .derived-result-row label { display: flex; align-items: center; gap: .25rem; font-size: .7rem; white-space: nowrap; cursor: pointer; }
            .derived-result-row label:has(input:disabled) { opacity: .45; cursor: not-allowed; }
            .derived-result-row .element-expression { min-width: 0; margin: 0; padding: .3rem; font-size: .65rem; }
            .element-actions button, .delete-element { border: 1px solid #0002; border-radius: .4rem; padding: .25rem .5rem; cursor: pointer; }
            .element-actions .axis-add-options button { border: 0; border-radius: 0; padding: .15rem .25rem; }
            .element-actions button:disabled { opacity: .45; cursor: not-allowed; }
            .delete-element {
              flex: none;
              display: grid;
              place-items: center;
              margin: 0;
              padding: .1rem .3rem;
              color: #fff;
              background: #7f1d1d;
              border-color: #7f1d1d;
              font-size: .65rem;
              line-height: 1.2;
            }
            .delete-element:hover { background: #991b1b; }
            .element-editor {
              display: block;
              margin: .35rem 0;
              padding: .4rem .5rem;
              border: 1px solid #0002;
              border-radius: .45rem;
              background: #ffffffb8;
              accent-color: var(--element-color);
              transition: border-color .15s ease, background-color .15s ease;
            }
            .element-editor:hover,
            .element-editor:focus-within { border-color: color-mix(in srgb, var(--element-color) 45%, #0002); background: #fff; }
            .element-editor[open] { border-color: color-mix(in srgb, var(--element-color) 35%, #0002); background: #fff; }

            .element-disclosure { width: 100%; min-width: 0; }
            .element-editor summary { display: flex; align-items: center; gap: .35rem; color: var(--element-color); cursor: pointer; white-space: nowrap; }
            .element-summary-label { min-width: 0; overflow: hidden; text-overflow: ellipsis; }
            .element-expression {
              display: block;
              width: 100%;
              box-sizing: border-box;
              margin: .35rem 0 .5rem;
              padding: .35rem .45rem;
              border: 1px solid #0002;
              border-radius: .35rem;
              color: #555;
              background: #f7f7f7;
              font: .68rem ui-monospace, SFMono-Regular, monospace;
              white-space: nowrap;
              overflow: hidden;
              text-overflow: ellipsis;
            }
            .element-row + .element-row { border-top: 1px solid #0001; }
            .element-row input[type="color"] { width: 2.5rem; height: 2rem; padding: 0; border: 0; background: transparent; cursor: pointer; }
            .element-controls { display: grid; grid-template-columns: minmax(0, 1fr); box-sizing: border-box; gap: .35rem; padding: .5rem 0; }
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
        <div class={["elements-list", if(Enum.empty?(@elements), do: "empty")]}>
          <div
            :for={{element, index} <- Enum.with_index(@elements)}
            class="element-editor"
            style={"--element-color: #{elem(element, 1)}"}
          >
            <details id={"cga3-element-panel-#{index}"} class="element-disclosure">
              <summary>
                <span class="element-summary-label">{element_label(element, index)}</span>
                <span class="element-side-actions">
                  <span class="element-operations">
                    <button
                      id={"representation-element-#{index}"}
                      type="button"
                      class="element-operation"
                      phx-click="toggle_representation"
                      phx-value-index={index}
                      aria-label={"Dualize #{element_label(element, index)}"}
                      title="Dualize element"
                    >Dual</button>
                    <button
                      id={"negate-element-#{index}"}
                      type="button"
                      class="element-operation"
                      phx-click="negate_element"
                      phx-value-index={index}
                      aria-label={"Negate #{element_label(element, index)}"}
                      title="Negate element"
                    >Negate</button>
                  </span>
                  <button
                    id={"delete-element-#{index}"}
                    type="button"
                    class="delete-element"
                    phx-click="delete_element"
                    phx-value-index={index}
                    aria-label={"Remove #{element_label(element, index)}"}
                    title="Remove element"
                  >×</button>
                </span>
              </summary>
              <input
                id={"cga3-element-expression-#{index}"}
                class="element-expression"
                type="text"
                readonly
                value={element_expression(element)}
                title={element_expression(element)}
                aria-label={"Algebraic expression for #{element_label(element, index)}"}
              />
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
                  :for={
                    {label, name, value, min, max, step} <-
                      element_controls(element)
                  }
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
          </div>
        </div>
        <div class="derived-results" id="cga3-derived-results">
          <section class="derived-result" id="cga3-sum-result">
            <div class="derived-result-row">
              <strong>Sum all</strong>
              <form
                id="cga3-transform-sum-form"
                class="transform-choice"
                phx-change="change_point_cloud_transform"
              >
                <label for="cga3-transform-sum">
                  <input
                    id="cga3-transform-sum"
                    type="radio"
                    name="point_cloud_transform"
                    value="sum"
                    checked={@point_cloud_transform == "sum"}
                  /> Cloud
                </label>
              </form>
              <input
                id="cga3-sum-expression"
                class="element-expression"
                type="text"
                readonly
                value={@sum_expression}
                title={@sum_expression}
                aria-label="Algebraic expression for sum of all elements"
              />
              <form id="cga3-sum-visibility" class="render-result" phx-change="toggle_sum_all">
                <input type="hidden" name="sum_all" value="off" />
                <label for="cga3-show-sum-all">
                  <input
                    id="cga3-show-sum-all"
                    name="sum_all"
                    type="checkbox"
                    value="on"
                    checked={@show_sum_all}
                  /> Show
                </label>
              </form>
              <button
                id="cga3-apply-sum-all"
                type="button"
                class="apply-result"
                phx-click="apply_sum_all"
              >
                Apply
              </button>
            </div>
          </section>
          <section class="derived-result" id="cga3-meet-result">
            <div class="derived-result-row">
              <strong>Wedge all</strong>
              <form
                id="cga3-transform-meet-form"
                class="transform-choice"
                phx-change="change_point_cloud_transform"
              >
                <label for="cga3-transform-meet">
                  <input
                    id="cga3-transform-meet"
                    type="radio"
                    name="point_cloud_transform"
                    value="wedge"
                    checked={@point_cloud_transform == "wedge"}
                  /> Cloud
                </label>
              </form>
              <input
                id="cga3-meet-expression"
                class="element-expression"
                type="text"
                readonly
                value={@meet_expression}
                title={@meet_expression}
                aria-label="Algebraic expression for wedge of all elements"
              />
              <form id="cga3-meet-visibility" class="render-result" phx-change="toggle_meet_all">
                <input type="hidden" name="meet_all" value="off" />
                <label for="cga3-show-meet-all">
                  <input
                    id="cga3-show-meet-all"
                    name="meet_all"
                    type="checkbox"
                    value="on"
                    checked={@show_meet_all}
                  /> Show
                </label>
              </form>
              <button
                id="cga3-apply-meet-all"
                type="button"
                class="apply-result"
                phx-click="apply_meet_all"
              >
                Apply
              </button>
            </div>
          </section>
          <section class="derived-result" id="cga3-gp-result">
            <div class="derived-result-row">
              <strong>GP all</strong>
              <form
                id="cga3-transform-gp-form"
                class="transform-choice"
                phx-change="change_point_cloud_transform"
              >
                <label for="cga3-transform-gp">
                  <input
                    id="cga3-transform-gp"
                    type="radio"
                    name="point_cloud_transform"
                    value="gp"
                    checked={@point_cloud_transform == "gp"}
                  /> Cloud
                </label>
              </form>
              <input
                id="cga3-gp-expression"
                class="element-expression"
                type="text"
                readonly
                value={@gp_expression}
                title={@gp_expression}
                aria-label="Algebraic expression for geometric product of all elements"
              />
              <form id="cga3-gp-visibility" class="render-result" phx-change="toggle_gp_all">
                <input type="hidden" name="gp_all" value="off" />
                <label for="cga3-show-gp-all">
                  <input
                    id="cga3-show-gp-all"
                    name="gp_all"
                    type="checkbox"
                    value="on"
                    checked={@show_gp_all}
                  /> show
                </label>
              </form>
              <button
                id="cga3-apply-gp-all"
                type="button"
                class="apply-result"
                phx-click="apply_gp_all"
              >
                Apply
              </button>
            </div>
          </section>
        </div>
        <div class="element-actions">
          <strong class="element-actions-label">Add</strong>
          <div class="element-action-buttons">
            <div
              id="add-point-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add point"
              phx-value-group="point"
            >
              <span class="axis-add-label">Point</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"origin", "O"}, {"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "x", do: "add-point", else: "add-point-#{axis}")}
                  type="button"
                  phx-click="add_point"
                  phx-value-axis={axis}
                  aria-label={
                    if(axis == "origin",
                      do: "Add point at origin",
                      else: "Add point offset along #{axis_name}"
                    )
                  }
                  title={
                    if(axis == "origin",
                      do: "Create point at origin",
                      else: "Offset point along #{axis_name}"
                    )
                  }
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
            <div
              id="add-sphere-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add sphere"
              phx-value-group="sphere"
            >
              <span class="axis-add-label">Sphere</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"origin", "O"}, {"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "x", do: "add-sphere", else: "add-sphere-#{axis}")}
                  type="button"
                  phx-click="add_sphere"
                  phx-value-axis={axis}
                  aria-label={
                    if(axis == "origin",
                      do: "Add sphere at origin",
                      else: "Add sphere offset along #{axis_name}"
                    )
                  }
                  title={
                    if(axis == "origin",
                      do: "Create sphere at origin",
                      else: "Offset sphere along #{axis_name}"
                    )
                  }
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
            <div
              id="add-plane-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add plane"
              phx-value-group="plane"
            >
              <span class="axis-add-label">Plane</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "x", do: "add-plane", else: "add-plane-#{axis}")}
                  type="button"
                  phx-click="add_plane"
                  phx-value-axis={axis}
                  aria-label={"Add plane with #{axis_name} normal"}
                  title={"Orient plane to #{axis_name} axis"}
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
            <div
              id="add-line-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add line"
              phx-value-group="line"
            >
              <span class="axis-add-label">Line</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "y", do: "add-line", else: "add-line-#{axis}")}
                  type="button"
                  phx-click="add_line"
                  phx-value-axis={axis}
                  aria-label={"Add line along #{axis_name}"}
                  title={"Direct line along #{axis_name} axis"}
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
            <div
              id="add-circle-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add circle"
              phx-value-group="circle"
            >
              <span class="axis-add-label">Circle</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "z", do: "add-circle", else: "add-circle-#{axis}")}
                  type="button"
                  phx-click="add_circle"
                  phx-value-axis={axis}
                  aria-label={"Add circle with #{axis_name} normal"}
                  title={"Orient circle normal to #{axis_name} axis"}
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
            <div
              id="add-point-pair-group"
              class={["axis-add-group"]}
              role="group"
              aria-label="Add point pair"
              phx-value-group="point-pair"
            >
              <span class="axis-add-label">Point pair</span>
              <div class="axis-add-options">
                <button
                  :for={{axis, axis_name} <- [{"x", "X"}, {"y", "Y"}, {"z", "Z"}]}
                  id={if(axis == "x", do: "add-point-pair", else: "add-point-pair-#{axis}")}
                  type="button"
                  phx-click="add_point_pair"
                  phx-value-axis={axis}
                  aria-label={"Add point pair along #{axis_name}"}
                  title={"Orient point pair along #{axis_name} axis"}
                  disabled={@available_colors == []}
                >{axis_name}</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="toolbar">
        <form>
          <fieldset>
            <legend>Zoom</legend>
            <label>
              <input
                id="cga3-zoom"
                type="range"
                min="1"
                max="30"
                step="0.1"
                value={@camera.radius}
                phx-hook=".Zoom"
              />
            </label>
          </fieldset>
        </form>
        <form id="cga3-cloud-visibility" phx-change="toggle_point_cloud">
          <input type="hidden" name="point_cloud" value="off" />
          <label for="cga3-show-point-cloud">
            <input
              id="cga3-show-point-cloud"
              name="point_cloud"
              type="checkbox"
              value="on"
              checked={@show_point_cloud}
              phx-throttle="16"
            /> Point cloud
          </label>
        </form>
        <form id="cga3-vector-field-visibility" phx-change="toggle_vector_field">
          <input type="hidden" name="vector_field" value="off" />
          <label for="cga3-show-vector-field">
            <input
              id="cga3-show-vector-field"
              name="vector_field"
              type="checkbox"
              value="on"
              checked={@show_vector_field}
            /> Vector field
          </label>
        </form>
        <form id="cga3-scene-elements-visibility" phx-change="toggle_scene_elements">
          <input type="hidden" name="scene_elements" value="off" />
          <label for="cga3-show-scene-elements">
            <input
              id="cga3-show-scene-elements"
              name="scene_elements"
              type="checkbox"
              value="on"
              checked={@show_scene_elements}
            /> Scene elements
          </label>
        </form>

        <%= if @show_point_cloud do %>
          <form id="cga3-point-cloud-offset" phx-change="change_point_cloud_offset">
            <fieldset class="point-cloud-offsets">
              <legend>Point cloud offset</legend>
              <label :for={
                {axis, value} <- [
                  x: @point_cloud_offset.x,
                  y: @point_cloud_offset.y,
                  z: @point_cloud_offset.z
                ]
              }>
                <input
                  id={"cga3-point-cloud-offset-#{axis}"}
                  type="range"
                  name={axis}
                  min="-3"
                  max="3"
                  step="0.1"
                  value={value}
                />
              </label>
            </fieldset>
          </form>
        <% end %>
        <button
          id="cga3-export-svg"
          type="button"
          phx-hook=".ExportSvg"
        >Download SVG</button>
      </div>
      <svg
        id="cga3-scene"
        class="scene"
        width="100%"
        height="100%"
        viewBox="-100 -100 200 200"
        preserveAspectRatio="xMidYMid slice"
        phx-hook=".Orb"
      >
        <defs>
          <marker
            :for={arrow <- @projected_vector_field}
            id={arrow.marker_id}
            viewBox="0 0 10 10"
            refX="8"
            refY="5"
            markerWidth={arrow.marker_size}
            markerHeight={arrow.marker_size}
            markerUnits="userSpaceOnUse"
            fill="context-stroke"
            orient="auto"
          >
            <path d="M 0 0 L 10 5 L 0 10 z" />
          </marker>
          <marker
            id="cga3-line-arrow"
            viewBox="0 0 10 10"
            refX="5"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            fill="context-stroke"
            orient="auto"
          >
            <circle cx="5" cy="5" r="3" />
          </marker>
        </defs>
        <rect x="-100" y="-100" width="200" height="200" fill="#fff" pointer-events="none" />
        <g :for={grid <- @ground_grid} id="cga3-ground-grid" stroke={grid.color} opacity="0.16">
          <polygon
            :for={points <- grid.cells}
            points={points |> Enum.map(fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end) |> Enum.join(" ")}
            fill="none"
            stroke-width="0.55"
            vector-effect="non-scaling-stroke"
            class="ground-grid-cell"
          />
        </g>
        <g
          id="scene-elements"
          display={if(@show_scene_elements, do: "inline", else: "none")}
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
                  stroke="none"
                  opacity="0.1"
                  class="plane-fill"
                />
                <polygon
                  :for={points <- object.cells}
                  points={
                    points |> Enum.map(fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end) |> Enum.join(" ")
                  }
                  fill="none"
                  stroke-width="0.7"
                  vector-effect="non-scaling-stroke"
                  class="grid-cell"
                />
              <% object.type == :sphere -> %>
                <polygon
                  :if={object.fill && Map.has_key?(object.fill, :points)}
                  points={
                    Enum.map_join(object.fill.points, " ", fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end)
                  }
                  fill={object.color}
                  stroke="none"
                  opacity={if(object.imaginary, do: "0.035", else: "0.12")}
                  class={["sphere-fill", object.imaginary && "sphere-fill-imaginary"]}
                />
                <ellipse
                  :if={object.fill && !Map.has_key?(object.fill, :points)}
                  cx={fr(object.fill.center_x)}
                  cy={fr(object.fill.center_y)}
                  rx={fr(object.fill.radius_a)}
                  ry={fr(object.fill.radius_b)}
                  transform={"rotate(#{fr(object.fill.angle * 180 / :math.pi())} #{fr(object.fill.center_x)} #{fr(object.fill.center_y)})"}
                  fill={object.color}
                  stroke="none"
                  opacity={if(object.imaginary, do: "0.035", else: "0.12")}
                  class={["sphere-fill", object.imaginary && "sphere-fill-imaginary"]}
                />
                <circle
                  :if={object.tangent}
                  cx={fr(elem(object.tangent, 0))}
                  cy={fr(elem(object.tangent, 1))}
                  r="2"
                  fill={object.color}
                  stroke="none"
                  class="sphere-tangent"
                />
                <polygon
                  :for={ellipse <- object.ellipses}
                  :if={Map.has_key?(ellipse, :points)}
                  points={Enum.map_join(ellipse.points, " ", fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end)}
                  fill="none"
                  stroke-width={if(ellipse.secondary, do: "1", else: "2")}
                  opacity={if(ellipse.secondary, do: "0.72")}
                  stroke-dasharray={if(object.imaginary, do: "5 3")}
                  vector-effect="non-scaling-stroke"
                  class={[
                    "sphere-ring",
                    ellipse.secondary && "sphere-ring-secondary",
                    object.imaginary && "sphere-ring-imaginary"
                  ]}
                />
                <line
                  :for={ellipse <- object.ellipses}
                  :if={
                    !Map.has_key?(ellipse, :points) && fr(ellipse.radius_b) <= 0.0 &&
                      fr(ellipse.radius_a) > 0.0
                  }
                  x1={fr(ellipse.center_x) - fr(ellipse.radius_a)}
                  y1={fr(ellipse.center_y)}
                  x2={fr(ellipse.center_x) + fr(ellipse.radius_a)}
                  y2={fr(ellipse.center_y)}
                  transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
                  fill="none"
                  stroke-width={if(ellipse.secondary, do: "1", else: "2")}
                  opacity={if(ellipse.secondary, do: "0.72")}
                  stroke-dasharray={if(object.imaginary, do: "5 3")}
                  vector-effect="non-scaling-stroke"
                  class={[
                    "sphere-ring",
                    ellipse.secondary && "sphere-ring-secondary",
                    object.imaginary && "sphere-ring-imaginary"
                  ]}
                />
                <ellipse
                  :for={ellipse <- object.ellipses}
                  :if={
                    !Map.has_key?(ellipse, :points) && fr(ellipse.radius_b) > 0.0 &&
                      fr(ellipse.radius_a) > 0.0
                  }
                  cx={fr(ellipse.center_x)}
                  cy={fr(ellipse.center_y)}
                  rx={fr(ellipse.radius_a)}
                  ry={fr(ellipse.radius_b)}
                  transform={"rotate(#{fr(ellipse.angle * 180 / :math.pi())} #{fr(ellipse.center_x)} #{fr(ellipse.center_y)})"}
                  fill="none"
                  stroke-width={if(ellipse.secondary, do: "1", else: "2")}
                  opacity={if(ellipse.secondary, do: "0.72")}
                  stroke-dasharray={if(object.imaginary, do: "5 3")}
                  vector-effect="non-scaling-stroke"
                  class={[
                    "sphere-ring",
                    ellipse.secondary && "sphere-ring-secondary",
                    object.imaginary && "sphere-ring-imaginary"
                  ]}
                />
              <% object.type == :circle -> %>
                <circle
                  :if={Map.get(object, :tangent, false)}
                  cx={fr(object.x)}
                  cy={fr(object.y)}
                  r="1.5"
                  fill={object.color}
                  stroke="none"
                  class="scene-circle-tangent"
                />
                <polygon
                  :if={Map.has_key?(object, :polygon)}
                  points={Enum.map_join(object.polygon, " ", fn {x, y, _} -> "#{fr(x)},#{fr(y)}" end)}
                  fill={object.color}
                  fill-opacity="0.12"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  class="scene-circle"
                />
                <ellipse
                  :if={Map.has_key?(object, :ellipse)}
                  cx={fr(object.ellipse.center_x)}
                  cy={fr(object.ellipse.center_y)}
                  rx={fr(object.ellipse.radius_a)}
                  ry={fr(object.ellipse.radius_b)}
                  transform={"rotate(#{fr(object.ellipse.angle * 180 / :math.pi())} #{fr(object.ellipse.center_x)} #{fr(object.ellipse.center_y)})"}
                  fill={object.color}
                  fill-opacity="0.12"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  class="scene-circle"
                />
              <% object.type == :point -> %>
                <circle
                  cx={fr(object.x)}
                  cy={fr(object.y)}
                  r={fr(3 / :math.sqrt(object.depth))}
                  fill={object.color}
                  stroke="none"
                  class="scene-point"
                />
              <% object.type == :point_pair -> %>
                <line
                  x1={fr(elem(object.a, 0))}
                  y1={fr(elem(object.a, 1))}
                  x2={fr(elem(object.b, 0))}
                  y2={fr(elem(object.b, 1))}
                  opacity="0.25"
                  stroke-dasharray={"#{fr(70 / object.depth)} #{fr(40 / object.depth)}"}
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  vector-effect="non-scaling-stroke"
                  class="point-pair-link"
                />
                <circle
                  :if={object.a_visible}
                  cx={fr(elem(object.a, 0))}
                  cy={fr(elem(object.a, 1))}
                  r={fr(5 / :math.sqrt(elem(object.a, 2)))}
                  fill={object.color}
                  stroke="#fff"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  class="point-pair-point"
                />
                <circle
                  :if={object.b_visible}
                  cx={fr(elem(object.b, 0))}
                  cy={fr(elem(object.b, 1))}
                  r={fr(5 / :math.sqrt(elem(object.b, 2)))}
                  fill={object.color}
                  stroke="#fff"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  class="point-pair-point"
                />
              <% object.type == :line -> %>
                <line
                  x1={fr(object.x1)}
                  y1={fr(object.y1)}
                  x2={fr(object.x2)}
                  y2={fr(object.y2)}
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  class="scene-line"
                />
              <% true -> %>
            <% end %>
          </g>
        </g>
        <g
          :if={@show_point_cloud}
          id="point-cloud"
          data-point-count={length(@projected_point_cloud)}
          opacity="0.65"
        >
          <circle
            :for={{x, y, depth} <- @projected_point_cloud}
            cx={fr(x)}
            cy={fr(y)}
            r={fr(14 / depth)}
            fill="#f97316"
          />
        </g>
        <g
          :if={@show_vector_field}
          id="vector-field"
          data-arrow-count={Enum.count(@projected_vector_field, &(&1.paths != []))}
          data-computing={@vector_field_computing}
          opacity="0.65"
          stroke="#f97316"
        >
          <path
            :for={arrow <- @projected_vector_field}
            id={"#{arrow.id}-base"}
            d={vector_field_paths_path(arrow.paths)}
            pathLength="1"
            data-step-count="10"
            fill="none"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
            vector-effect="non-scaling-stroke"
            opacity="0.35"
            class="vector-field-arrow-base"
          />
          <path
            :for={arrow <- @projected_vector_field}
            id={arrow.id}
            d={vector_field_paths_path(arrow.paths)}
            marker-end={if(arrow.complete?, do: "url(##{arrow.marker_id})")}
            pathLength="1"
            data-step-count="10"
            fill="none"
            stroke-width="3"
            stroke-dasharray="0.32 0.48"
            stroke-linecap="round"
            stroke-linejoin="round"
            vector-effect="non-scaling-stroke"
            class="vector-field-arrow"
          >
            <animate
              attributeName="stroke-dashoffset"
              from="0"
              to="-0.8"
              dur="1s"
              begin="0.35s"
              repeatCount="indefinite"
            />
          </path>
        </g>
        <g
          :if={@show_point_cloud}
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
      <svg
        id="cga3-axis-indicator"
        class="axis-indicator"
        viewBox="0 0 100 100"
        role="img"
        aria-label="Global XYZ orientation"
      >
        <defs>
          <marker
            id="cga3-axis-arrow"
            viewBox="0 0 10 10"
            refX="5"
            refY="5"
            markerWidth="6"
            markerHeight="6"
            fill="context-stroke"
            orient="auto"
          >
            <circle cx="5" cy="5" r="3" />
          </marker>
        </defs>
        <title>Global XYZ orientation</title>
        <circle cx="50" cy="50" r="50" fill="#000" fill-opacity="0.16" />
        <circle cx="50" cy="50" r="2.5" fill="#444" />
        <g :for={axis <- @global_axes} class={"axis-#{axis.axis}"}>
          <line
            x1="50"
            y1="50"
            x2={fr(50 + axis.x)}
            y2={fr(50 + axis.y)}
            stroke={axis.color}
            stroke-width="3"
            stroke-linecap="round"
            marker-end="url(#cga3-axis-arrow)"
          />
          <text
            x={fr(56 + axis.x)}
            y={fr(44 + axis.y)}
            fill={axis.color}
            font-family="ui-sans-serif, sans-serif"
            font-size="9"
            font-weight="700"
            text-anchor="start"
            dominant-baseline="middle"
          >
            {String.upcase(to_string(axis.axis))}
          </text>
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
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ExportSvg">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            const svg = document.querySelector("#cga3-scene");
            if (!svg) return;

            const exported = svg.cloneNode(true);
            exported.setAttribute("xmlns", "http://www.w3.org/2000/svg");
            exported.setAttribute("xmlns:xlink", "http://www.w3.org/1999/xlink");
            [exported, ...exported.querySelectorAll("*")].forEach(element => {
              for (const attribute of [...element.attributes]) {
                if (attribute.name.startsWith("phx-") || attribute.name.startsWith("data-phx-")) {
                  element.removeAttribute(attribute.name);
                }
              }
            });

            const markup = new XMLSerializer().serializeToString(exported);
            const file = new Blob(
              [`<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n`, markup],
              { type: "image/svg+xml;charset=utf-8" },
            );
            const url = URL.createObjectURL(file);
            const link = document.createElement("a");
            link.href = url;
            const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
            link.download = `geomextric-cga3-${timestamp}.svg`;
            link.click();
            URL.revokeObjectURL(url);
          });
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
