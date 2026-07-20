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

  def gen_grid(horizontal \\ true, vertical \\ true) do
    %{
      points: [],
      edges:
        Enum.concat([
          for(
            i <- -10..10,
            horizontal,
            do: {"#0001", {PGA3.point(i / 2, -5, 0), PGA3.point(i / 2, 5, 0)}}
          ),
          for(
            i <- -10..10,
            horizontal,
            do: {"#0001", {PGA3.point(-5, i / 2, 0), PGA3.point(5, i / 2, 0)}}
          ),
          for(
            i <- -10..10,
            vertical,
            do: {"#0001", {PGA3.point(5, -5, 5 + i / 2), PGA3.point(5, 5, 5 + i / 2)}}
          ),
          for(
            i <- -10..10,
            vertical,
            do: {"#0001", {PGA3.point(-5, 5, 5 + i / 2), PGA3.point(5, 5, 5 + i / 2)}}
          ),
          for(
            i <- -10..10,
            vertical,
            do: {"#0001", {PGA3.point(i / 2, 5, 0), PGA3.point(i / 2, 5, 10)}}
          ),
          for(
            i <- -10..10,
            vertical,
            do: {"#0001", {PGA3.point(5, i / 2, 0), PGA3.point(5, i / 2, 10)}}
          )
        ]),
      faces: [],
      labels: []
    }
  end

  def gen_vector(x, y, z, attrs \\ []) do
    %{
      points: [],
      edges: [
        {Keyword.get(attrs, :color, "black"), {PGA3.point(0, 0, 0), PGA3.point(-x, y, z)}}
      ],
      faces: [],
      labels: [
        {Keyword.get(attrs, :color, "black"), PGA3.point(-x, y, z),
         Keyword.get(attrs, :name, "v")}
      ]
    }
  end

  def gen_bivector(x, y, z, attrs \\ []) do
    area = :math.sqrt(x * x + y * y + z * z)
    area = if(area == 0.0, do: 1, else: area)
    size = :math.sqrt(area)
    offset = size / 2
    o = Keyword.get(attrs, :offset, %{x: 1, y: 1, z: 1})

    n = %{
      x: -x / area,
      y: y / area,
      z: -z / area
    }

    len = :math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z)

    face =
      if len == 0 do
        [
          %{
            x: 0,
            y: 0,
            z: 0
          },
          %{
            x: 0,
            y: 0,
            z: 0
          },
          %{
            x: 0,
            y: 0,
            z: 0
          },
          %{
            x: 0,
            y: 0,
            z: 0
          }
        ]
      else
        a = if(abs(n.x) < 0.001, do: %{x: 1, y: 0, z: 0}, else: %{x: 0, y: 1, z: 0})

        u = %{
          x: a.y * n.z - a.z * n.y,
          y: a.z * n.x - a.x * n.z,
          z: a.x * n.y - a.y * n.x
        }

        ulen = :math.sqrt(u.x * u.x + u.y * u.y + u.z * u.z)

        u = %{u | x: u.x / ulen * size, y: u.y / ulen * size, z: u.z / ulen * size}

        v = %{
          x: n.y * u.z - n.z * u.y,
          y: n.z * u.x - n.x * u.z,
          z: n.x * u.y - n.y * u.x
        }

        [
          %{
            x: u.x / 2 - v.x / 2 + offset * o.x,
            y: u.y / 2 - v.y / 2 + offset * o.y,
            z: u.z / 2 - v.z / 2 + offset * o.z
          },
          %{
            x: -v.x / 2 - u.x / 2 + offset * o.x,
            y: -v.y / 2 - u.y / 2 + offset * o.y,
            z: -v.z / 2 - u.z / 2 + offset * o.z
          },
          %{
            x: v.x / 2 - u.x / 2 + offset * o.x,
            y: v.y / 2 - u.y / 2 + offset * o.y,
            z: v.z / 2 - u.z / 2 + offset * o.z
          },
          %{
            x: u.x / 2 + v.x / 2 + offset * o.x,
            y: u.y / 2 + v.y / 2 + offset * o.y,
            z: u.z / 2 + v.z / 2 + offset * o.z
          }
        ]
      end

    %{
      points: [],
      edges:
        for {a, b} <- face |> Enum.zip(face |> Enum.concat(face) |> Enum.drop(1)) do
          {Keyword.get(attrs, :stroke, "black"),
           {PGA3.point(a.x, a.y, a.z), PGA3.point(b.x, b.y, b.z)}}
        end,
      faces: [
        {Keyword.get(attrs, :fill, "black"),
         for v <- face do
           PGA3.point(v.x, v.y, v.z)
         end}
      ],
      labels: [
        {Keyword.get(attrs, :text, "black"),
         Enum.map(face, fn p -> PGA3.point(p.x, p.y, p.z) end) |> Enum.reduce(&PGA3.add/2),
         Keyword.get(attrs, :name)}
      ]
    }
  end

  def gen_axis do
    %{
      points: [],
      edges: [
        {"black", {PGA3.point(5, 0, 0), PGA3.point(-5, 0, 0)}},
        {"black", {PGA3.point(0, -5, 0), PGA3.point(0, 5, 0)}},
        {"black", {PGA3.point(0, 0, -3), PGA3.point(0, 0, 4)}}
      ],
      faces: [],
      labels: [
        {"black", PGA3.point(-5, 0, 0), "X"},
        {"black", PGA3.point(0, 5, 0), "Y"},
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
    # https://observablehq.com/@enkimute/glu-lookat-in-3d-pga
    initial_m = one = PGA3.new(scalar: 1)
    initial_q = PGA3.dual(PGA3.new(scalar: 1))

    Enum.zip_reduce(ps, qs, {initial_m, initial_q}, fn p, q, {m, prev_q} ->
      p = prev_q |> PGA3.join(PGA3.transform(m, p)) |> PGA3.normalize()
      new_q = prev_q |> PGA3.join(q) |> PGA3.normalize() |> PGA3.blade_inverse()
      new_m = new_q |> PGA3.gp(p) |> PGA3.add(one) |> PGA3.gp(m)

      {new_m, new_q}
    end)
    |> elem(0)
  end

  def make_exp(ampl, freq, phase \\ 0, attr \\ []) do
    offset = Keyword.get(attr, :offset, %{x: 0, y: 0, z: 0})

    samples =
      for t <- -40..40 do
        sin = :math.sin(t / 20 * freq + phase)
        cos = :math.cos(t / 20 * freq + phase)
        PGA3.point(t / 10 + offset.x, sin * ampl + offset.y, cos * ampl + offset.z)
      end

    %{
      points: [],
      edges:
        for {p, q} <- Enum.zip(samples, Enum.drop(samples, 1)) do
          {"red", {p, q}}
        end,
      faces: [],
      labels: []
    }
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
