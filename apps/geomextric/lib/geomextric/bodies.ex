defmodule Geomextric.Bodies do
  alias Galixir.Algebras.PGA3

  def empty do
    %{
      points: [],
      edges: [],
      faces: [],
      labels: []
    }
  end

  def gen_axis do
    %{
      points: [],
      edges: [
        {"black", {PGA3.point(-5, 0, 0), PGA3.point(5, 0, 0)}},
        {"black", {PGA3.point(0, 5, 0), PGA3.point(0, -5, 0)}},
        {"black", {PGA3.point(0, 0, -3), PGA3.point(0, 0, 4)}}
      ],
      faces: [],
      labels: [
        {"black", PGA3.point(5, 0, 0), "X"},
        {"black", PGA3.point(0, -5, 0), "Y"},
        {"black", PGA3.point(0, 0, 4), "Z"}
      ]
    }
  end

  def gen_cube do
    %{
      points:
        for x <- [-1, 1], y <- [-1, 1], z <- [-1, 1] do
          {"tomato", PGA3.point(x + 4, y - 4, z + 1)}
        end,
      edges:
        for x <- [-1, 1],
            y <- [-1, 1],
            z <- [-1, 1],
            {dx, dy, dz} <- [{2, 0, 0}, {0, 2, 0}, {0, 0, 2}],
            x + dx <= 1,
            y + dy <= 1,
            z + dz <= 1 do
          {"teal",
           {PGA3.point(x + 4, y - 4, z + 1), PGA3.point(x + dx + 4, y + dy - 4, z + dz + 1)}}
        end,
      labels: [],
      faces:
        for {{nx, ny, nz}, {ux, uy, uz}, {vx, vy, vz}} <- [
              {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
              {{0, 1, 0}, {1, 0, 0}, {0, 0, 1}},
              {{0, 0, 1}, {1, 0, 0}, {0, 1, 0}}
            ],
            s <- [-1, 1] do
          {"#5554",
           for {a, b} <- [{-1, -1}, {1, -1}, {1, 1}, {-1, 1}] do
             PGA3.point(
               s * nx + a * ux + b * vx + 4,
               s * ny + a * uy + b * vy - 4,
               s * nz + a * uz + b * vz + 1
             )
           end}
        end
    }
  end

  def gen_pyramid do
    pyramid_tip = PGA3.point(0, 0, 3)

    %{
      points: [
        {"rebeccapurple", pyramid_tip},
        {"tomato", PGA3.point(1, 1, 1)},
        {"tomato", PGA3.point(1, -1, 1)},
        {"tomato", PGA3.point(-1, -1, 1)},
        {"tomato", PGA3.point(-1, 1, 1)},
        {"yellowgreen", PGA3.point(1, 0, 1)},
        {"yellowgreen", PGA3.point(-1, 0, 1)},
        {"yellowgreen", PGA3.point(0, -1, 1)},
        {"yellowgreen", PGA3.point(0, 1, 1)},
        {"teal", PGA3.point(1, 1, 0)},
        {"teal", PGA3.point(1, -1, 0)},
        {"teal", PGA3.point(-1, -1, 0)},
        {"teal", PGA3.point(-1, 1, 0)}
      ],
      edges: [
        {"royalblue", {PGA3.point(1, 1, 1), pyramid_tip}},
        {"royalblue", {PGA3.point(-1, 1, 1), pyramid_tip}},
        {"royalblue", {PGA3.point(-1, -1, 1), pyramid_tip}},
        {"royalblue", {PGA3.point(1, -1, 1), pyramid_tip}},
        {"royalblue", {PGA3.point(1, 1, 1), PGA3.point(-1, 1, 1)}},
        {"royalblue", {PGA3.point(1, -1, 1), PGA3.point(-1, -1, 1)}},
        {"royalblue", {PGA3.point(-1, 1, 1), PGA3.point(-1, -1, 1)}},
        {"royalblue", {PGA3.point(1, 1, 1), PGA3.point(1, -1, 1)}},
        {"teal", {PGA3.point(1, 1, 0), PGA3.point(-1, 1, 0)}},
        {"teal", {PGA3.point(1, -1, 0), PGA3.point(-1, -1, 0)}},
        {"teal", {PGA3.point(-1, 1, 0), PGA3.point(-1, -1, 0)}},
        {"teal", {PGA3.point(1, 1, 0), PGA3.point(1, -1, 0)}}
      ],
      faces: [
        {"#4444",
         [
           PGA3.point(1, 1, 0),
           PGA3.point(-1, 1, 0),
           PGA3.point(-1, -1, 0),
           PGA3.point(1, -1, 0)
         ]},
        {"#5554",
         [
           PGA3.point(1, 1, 1),
           PGA3.point(-1, 1, 1),
           PGA3.point(-1, -1, 1),
           PGA3.point(1, -1, 1)
         ]},
        {"#0504",
         [
           PGA3.point(1, 1, 1),
           PGA3.point(1, -1, 1),
           pyramid_tip
         ]},
        {"#5504",
         [
           PGA3.point(-1, 1, 1),
           PGA3.point(-1, -1, 1),
           pyramid_tip
         ]},
        {"#0554",
         [
           PGA3.point(-1, -1, 1),
           PGA3.point(1, -1, 1),
           pyramid_tip
         ]},
        {"#5054",
         [
           PGA3.point(1, 1, 1),
           PGA3.point(-1, 1, 1),
           pyramid_tip
         ]}
      ],
      labels: []
    }
  end

  def align(ps, qs) do
    import PGA3
    # https://observablehq.com/@enkimute/glu-lookat-in-3d-pga
    initial_m = one = PGA3.new(scalar: 1)
    initial_q = PGA3.dual(PGA3.new(scalar: 1))

    Enum.zip_reduce(ps, qs, {initial_m, initial_q}, fn p, q, {m, prev_q} ->
      p = prev_q |> PGA3.join(PGA3.transform(m, p)) |> normalize()
      new_q = prev_q |> PGA3.join(q) |> normalize() |> PGA3.blade_inverse()
      new_m = new_q |> PGA3.gp(p) |> add(one) |> PGA3.gp(m)

      {new_m, new_q}
    end)
    |> elem(0)
  end

  def make_trace(from, to, steps \\ 20) do
    motor =
      align(
        from,
        to
      )

    intermediates =
      for i <- 0..steps do
        half = pow(motor, i / steps)

        for p <- from do
          PGA3.transform(half, p)
        end
      end

    %{
      points: [],
      edges:
        for {a, b} <- intermediates |> Enum.zip(Enum.drop(intermediates, 1)),
            {p, q} <- Enum.zip(a, b) do
          {"black", {p, q}}
        end,
      faces: [
        {"tomato", from},
        {"cyan", to}
        | for s <- intermediates do
            {"#aa008855", s}
          end
          |> Enum.drop(1)
          |> Enum.drop(-1)
      ],
      labels: []
    }
  end

  def log(mot) do
    PGA3.scale(
      PGA3.grade(mot, 2),
      1 / PGA3.coefficient(mot, :scalar)
    )
  end

  def exp(bv) do
    bv2 = PGA3.gp(bv, bv)
    bv4 = PGA3.grade(bv2, 4)

    numerator =
      PGA3.add(
        PGA3.add(
          PGA3.new(scalar: 1),
          bv
        ),
        PGA3.scale(bv4, 0.5)
      )

    denominator =
      1 - PGA3.coefficient(bv2, :scalar)

    PGA3.scale(numerator, 1 / denominator)
    |> PGA3.normalize()
  end

  def pow(motor, t) do
    motor
    |> log()
    |> PGA3.scale(t)
    |> exp()
  end
end
