defmodule GeomextricWeb.CGA3Motor do
  @moduledoc false

  alias Galixir.Algebras.CGA3

  @exp_terms 12

  def interpolation_generator(motor) do
    if motor?(motor) do
      {:ok, log(motor)}
    else
      {:ok, motor}
    end
  end

  def motor?(m, tolerance \\ 1.0e-6) do
    reverse = CGA3.reverse(m)
    product = CGA3.gp(m, reverse)

    infinity = CGA3.new(ep: 1.0, em: 1.0)

    Enum.all?(CGA3.grades(m), &(&1 in [0, 2, 4])) and
      norm(CGA3.sub(product, CGA3.one())) < tolerance and
      norm(
        CGA3.sub(
          CGA3.gp(CGA3.gp(m, infinity), reverse),
          infinity
        )
      ) < tolerance
  end

  def exp(generator) do
    norm = norm(generator)

    if norm < 1.0e-6 do
      CGA3.add(CGA3.one(), generator)
    else
      squarings = max(1, ceil(:math.log2(norm)))

      x = CGA3.scale(:math.pow(2.0, -squarings), generator)

      x
      |> exp_series()
      |> square_n(squarings)
    end
  end

  defp exp_series(x) do
    Enum.reduce(1..@exp_terms, {CGA3.one(), CGA3.one()}, fn k, {sum, term} ->
      term = CGA3.scale(1.0 / k, CGA3.gp(term, x))
      {CGA3.add(sum, term), term}
    end)
    |> elem(0)
  end

  defp square_n(motor, n) do
    Enum.reduce(1..n, motor, fn _, acc ->
      CGA3.gp(acc, acc)
    end)
  end

  defp norm(%CGA3{data: coefficients}) do
    coefficients
    |> Tuple.to_list()
    |> Enum.reduce(0.0, fn x, sum -> sum + x * x end)
    |> :math.sqrt()
  end

  @log_terms 16
  @sqrt_terms 10

  def log(motor) do
    {near_identity, roots} = reduce_motor(motor, 0)

    x = CGA3.sub(near_identity, CGA3.one())

    {result, _} =
      Enum.reduce(1..@log_terms, {CGA3.new(), x}, fn k, {sum, power} ->
        coefficient = if rem(k, 2) == 1, do: 1.0 / k, else: -1.0 / k

        {
          CGA3.add(sum, CGA3.scale(coefficient, power)),
          CGA3.gp(power, x)
        }
      end)

    CGA3.scale(:math.pow(2.0, roots), result)
  end

  defp reduce_motor(motor, roots) when roots >= 8, do: {motor, roots}

  defp reduce_motor(motor, roots) do
    distance = norm(CGA3.sub(motor, CGA3.one()))

    if distance < 0.1 do
      {motor, roots}
    else
      reduce_motor(motor_sqrt(motor), roots + 1)
    end
  end

  defp motor_sqrt(motor) do
    x = CGA3.sub(motor, CGA3.one())

    {result, _, _} =
      Enum.reduce(1..@sqrt_terms, {CGA3.one(), CGA3.one(), 1.0}, fn k,
                                                                    {sum, power, coefficient} ->
        coefficient = coefficient * (0.5 - (k - 1)) / k
        power = CGA3.gp(power, x)

        {CGA3.add(sum, CGA3.scale(coefficient, power)), power, coefficient}
      end)

    result
  end
end
