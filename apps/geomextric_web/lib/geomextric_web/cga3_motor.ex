defmodule GeomextricWeb.CGA3Motor do
  @moduledoc false

  alias Galixir.Algebras.CGA3

  @log_sqrt_limit 12

  @log_series_terms 16
  @exp_series_terms 12

  def interpolation_generator(transform) do
    cond do
      CGA3.line?(transform) ->
        {:ok, CGA3.dual(transform)}

      true ->
        case log(transform) do
          {:ok, _generator} = result -> result
          :error -> interpolation_fallback(transform)
        end
    end
  end

  def log(motor) do
    with true <- valid_motor?(motor),
         {:ok, near_identity, roots} <- reduce_to_near_identity(motor, 0),
         logarithm <- log_near_identity(near_identity, roots),
         true <- finite?(logarithm),
         {:ok, reconstructed} <- exp(logarithm),
         true <- close?(reconstructed, motor, 5.0e-3) do
      {:ok, logarithm}
    else
      _ -> :error
    end
  end

  def exp(generator) do
    norm = mv_norm(generator)

    cond do
      not finite?(generator) or not finite_number?(norm) ->
        :error

      norm < 1.0e-6 ->
        {:ok, CGA3.add(CGA3.one(), generator)}

      norm > 1.0e6 ->
        :error

      true ->
        squarings = max(1, ceil(:math.log(norm) / :math.log(2)))
        scaled_generator = CGA3.scale(:math.pow(2, -squarings), generator)
        exponential = exp_series(scaled_generator)
        result = Enum.reduce(1..squarings, exponential, fn _, motor -> CGA3.gp(motor, motor) end)

        if finite?(result), do: {:ok, result}, else: :error
    end
  rescue
    ArithmeticError -> :error
    ArgumentError -> :error
  end

  defp interpolation_fallback(transform) do
    case rigid_motor_log(transform) do
      {:ok, _generator} = result ->
        result

      :error ->
        if finite?(transform) and not primitive_without_flow?(transform) and
             not CGA3.zero?(transform) do
          {:ok, transform}
        else
          :error
        end
    end
  end

  defp primitive_without_flow?(element) do
    Enum.any?(
      [&CGA3.point?/1, &CGA3.plane?/1],
      fn predicate -> predicate.(element) end
    )
  end

  defp rigid_motor_log(motor) do
    with true <- valid_motor?(motor),
         {:ok, origin} <- transformed_coordinates(motor, {0.0, 0.0, 0.0}),
         {:ok, x_point} <- transformed_coordinates(motor, {1.0, 0.0, 0.0}),
         {:ok, y_point} <- transformed_coordinates(motor, {0.0, 1.0, 0.0}),
         {:ok, z_point} <- transformed_coordinates(motor, {0.0, 0.0, 1.0}),
         x_axis <- vector_subtract(x_point, origin),
         y_axis <- vector_subtract(y_point, origin),
         z_axis <- vector_subtract(z_point, origin),
         true <- orthonormal_rotation?(x_axis, y_axis, z_axis),
         matrix <- rotation_matrix(x_axis, y_axis, z_axis),
         omega <- rotation_vector(matrix),
         velocity <- translation_velocity(omega, origin),
         generator <- twist_generator(omega, velocity),
         {:ok, reconstructed} <- exp(generator),
         true <- close?(reconstructed, motor, 5.0e-3) do
      {:ok, generator}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp transformed_coordinates(motor, coordinates) do
    point = apply(CGA3, :point, Tuple.to_list(coordinates))
    result = point |> CGA3.transform(motor) |> CGA3.point_coordinates()
    if finite_coordinates?(result), do: {:ok, result}, else: :error
  rescue
    _ -> :error
  end

  defp finite_coordinates?({x, y, z}),
    do: finite_number?(x) and finite_number?(y) and finite_number?(z)

  defp rotation_matrix({r11, r21, r31}, {r12, r22, r32}, {r13, r23, r33}),
    do: {r11, r12, r13, r21, r22, r23, r31, r32, r33}

  defp orthonormal_rotation?(x_axis, y_axis, z_axis) do
    tolerance = 1.0e-4

    abs(vector_dot(x_axis, x_axis) - 1.0) < tolerance and
      abs(vector_dot(y_axis, y_axis) - 1.0) < tolerance and
      abs(vector_dot(z_axis, z_axis) - 1.0) < tolerance and
      abs(vector_dot(x_axis, y_axis)) < tolerance and
      abs(vector_dot(x_axis, z_axis)) < tolerance and
      abs(vector_dot(y_axis, z_axis)) < tolerance and
      abs(vector_dot(x_axis, vector_cross(y_axis, z_axis)) - 1.0) < tolerance
  end

  defp rotation_vector({r11, r12, r13, r21, r22, r23, r31, r32, r33}) do
    trace = r11 + r22 + r33

    {w, x, y, z} =
      cond do
        trace > 0.0 ->
          scale = 2 * :math.sqrt(trace + 1.0)
          {0.25 * scale, (r32 - r23) / scale, (r13 - r31) / scale, (r21 - r12) / scale}

        r11 >= r22 and r11 >= r33 ->
          scale = 2 * :math.sqrt(max(1.0 + r11 - r22 - r33, 0.0))
          {(r32 - r23) / scale, 0.25 * scale, (r12 + r21) / scale, (r13 + r31) / scale}

        r22 >= r33 ->
          scale = 2 * :math.sqrt(max(1.0 + r22 - r11 - r33, 0.0))
          {(r13 - r31) / scale, (r12 + r21) / scale, 0.25 * scale, (r23 + r32) / scale}

        true ->
          scale = 2 * :math.sqrt(max(1.0 + r33 - r11 - r22, 0.0))
          {(r21 - r12) / scale, (r13 + r31) / scale, (r23 + r32) / scale, 0.25 * scale}
      end

    quaternion_norm = :math.sqrt(w * w + x * x + y * y + z * z)

    {w, x, y, z} =
      {w / quaternion_norm, x / quaternion_norm, y / quaternion_norm, z / quaternion_norm}

    {w, x, y, z} = if w < 0.0, do: {-w, -x, -y, -z}, else: {w, x, y, z}
    vector_norm = :math.sqrt(x * x + y * y + z * z)

    if vector_norm < 1.0e-8 do
      {0.0, 0.0, 0.0}
    else
      angle = 2 * :math.atan2(vector_norm, w)
      scale = angle / vector_norm
      {scale * x, scale * y, scale * z}
    end
  end

  defp translation_velocity({omega_x, omega_y, omega_z} = omega, translation) do
    theta = :math.sqrt(omega_x * omega_x + omega_y * omega_y + omega_z * omega_z)

    if theta < 1.0e-6 do
      translation
    else
      first_cross = vector_cross(omega, translation)
      second_cross = vector_cross(omega, first_cross)
      coefficient = (1.0 - theta / (2.0 * :math.tan(theta / 2.0))) / (theta * theta)

      translation
      |> vector_add(vector_scale(-0.5, first_cross))
      |> vector_add(vector_scale(coefficient, second_cross))
    end
  end

  defp twist_generator({omega_x, omega_y, omega_z}, {vx, vy, vz}) do
    CGA3.new(
      e23: -omega_x / 2,
      e13: omega_y / 2,
      e12: -omega_z / 2,
      e1p: -vx / 2,
      e1m: -vx / 2,
      e2p: -vy / 2,
      e2m: -vy / 2,
      e3p: -vz / 2,
      e3m: -vz / 2
    )
  end

  defp vector_add({ax, ay, az}, {bx, by, bz}), do: {ax + bx, ay + by, az + bz}
  defp vector_subtract({ax, ay, az}, {bx, by, bz}), do: {ax - bx, ay - by, az - bz}
  defp vector_scale(scale, {x, y, z}), do: {scale * x, scale * y, scale * z}
  defp vector_dot({ax, ay, az}, {bx, by, bz}), do: ax * bx + ay * by + az * bz

  defp vector_cross({ax, ay, az}, {bx, by, bz}),
    do: {ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx}

  defp valid_motor?(motor) do
    grades = CGA3.grades(motor)
    reverse = CGA3.reverse(motor)
    product = CGA3.gp(motor, reverse)
    scalar = CGA3.scalar_product(motor, reverse)
    residual = CGA3.sub(product, CGA3.new(scalar: scalar))

    is_list(grades) and grades != [] and Enum.all?(grades, &(rem(&1, 2) == 0)) and
      finite?(motor) and abs(scalar) > 1.0e-10 and
      mv_norm(residual) <= 1.0e-8 * max(mv_norm(product), 1.0)
  rescue
    _ -> false
  end

  defp reduce_to_near_identity(motor, roots) do
    distance = mv_norm(CGA3.sub(motor, CGA3.one()))

    cond do
      not finite_number?(distance) ->
        :error

      distance < 0.01 ->
        {:ok, motor, roots}

      roots == @log_sqrt_limit ->
        :error

      true ->
        case motor_sqrt(motor) do
          {:ok, root} -> reduce_to_near_identity(root, roots + 1)
          :error -> :error
        end
    end
  rescue
    _ -> :error
  end

  defp motor_sqrt(motor), do: motor_sqrt(motor, CGA3.one(), 0)

  defp motor_sqrt(motor, root, iterations) when iterations < 32 do
    if close?(CGA3.gp(root, root), motor, 1.0e-8) do
      {:ok, root}
    else
      next_root =
        CGA3.scale(0.5, CGA3.add(root, CGA3.gp(motor, CGA3.inverse!(root))))

      if finite?(next_root), do: motor_sqrt(motor, next_root, iterations + 1), else: :error
    end
  rescue
    _ -> :error
  end

  defp motor_sqrt(_motor, _root, _iterations), do: :error

  defp log_near_identity(motor, roots) do
    difference = CGA3.sub(motor, CGA3.one())

    logarithm =
      Enum.reduce(1..@log_series_terms, {CGA3.new(), difference}, fn index, {result, power} ->
        sign = if rem(index, 2) == 1, do: 1.0, else: -1.0
        result = CGA3.add(result, CGA3.scale(sign / index, power))
        {result, CGA3.gp(power, difference)}
      end)
      |> elem(0)

    CGA3.scale(:math.pow(2, roots), logarithm)
  end

  defp exp_series(generator) do
    Enum.reduce(1..@exp_series_terms, {CGA3.one(), CGA3.one()}, fn index, {result, term} ->
      term = CGA3.scale(1.0 / index, CGA3.gp(term, generator))
      {CGA3.add(result, term), term}
    end)
    |> elem(0)
  end

  defp close?(left, right, tolerance) do
    finite?(left) and finite?(right) and
      mv_norm(CGA3.sub(left, right)) <= tolerance * max(mv_norm(right), 1.0)
  end

  defp mv_norm(%CGA3{data: coefficients}) do
    coefficients
    |> Tuple.to_list()
    |> Enum.reduce(0.0, fn coefficient, sum -> sum + coefficient * coefficient end)
    |> :math.sqrt()
  end

  defp finite?(%CGA3{data: coefficients}) do
    coefficients
    |> Tuple.to_list()
    |> Enum.all?(&finite_number?/1)
  end

  defp finite_number?(number) when is_number(number),
    do: number == number and abs(number) < 1.0e308

  defp finite_number?(_), do: false
end
