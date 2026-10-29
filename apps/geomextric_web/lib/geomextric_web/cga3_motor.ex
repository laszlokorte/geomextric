defmodule GeomextricWeb.CGA3Motor do
  @moduledoc false

  alias Galixir.Algebras.CGA3

  @log_sqrt_limit 8

  @log_series_terms 16
  @exp_series_terms 12

  def interpolation_generator(transform) do
    if CGA3.line?(transform) do
      {:ok, CGA3.dual(transform)}
    else
      log(transform)
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
