defmodule GeomextricWeb.GeometryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias GeomextricWeb.Geometry
  alias Galixir.Algebras.PGA3

  test "clips a line crossing the near plane instead of dropping it" do
    camera = PGA3.new(scalar: 1)
    behind = PGA3.point(0, 0, -1)
    in_front = PGA3.point(0, 0, 1)

    assert {{x1, y1, z1}, {x2, y2, z2}} = Geometry.project_line(camera, behind, in_front)
    assert_in_delta x1, 0, 1.0e-9
    assert_in_delta y1, 0, 1.0e-9
    assert_in_delta z1, 1.0e-3, 1.0e-9
    assert_in_delta x2, 0, 1.0e-9
    assert_in_delta y2, 0, 1.0e-9
    assert_in_delta z2, 1, 1.0e-9
  end

  test "renders an in-frustum face through the geometry component" do
    camera = PGA3.new(scalar: 1)

    quad = [
      PGA3.point(-0.5, -0.5, 1),
      PGA3.point(0.5, -0.5, 1),
      PGA3.point(0.5, 0.5, 1),
      PGA3.point(-0.5, 0.5, 1)
    ]

    html =
      render_component(&Geometry.geometry/1,
        camera: camera,
        id: "face",
        geo: %{faces: [{"#f00", quad}], edges: [], points: [], labels: []},
        rotation: 0.0,
        scale: 1.0
      )

    assert html |> LazyHTML.from_fragment() |> LazyHTML.query("polygon") |> LazyHTML.to_tree() !=
             []

    shifted_html =
      render_component(&Geometry.geometry/1,
        camera: PGA3.translator(1, 0, 0),
        id: "face",
        geo: %{faces: [{"#f00", quad}], edges: [], points: [], labels: []},
        rotation: 0.0,
        scale: 1.0
      )

    assert html != shifted_html
  end

  test "clips a quad crossing the near plane into a visible polygon" do
    camera = PGA3.new(scalar: 1)

    quad = [
      PGA3.point(-0.5, -0.5, -1),
      PGA3.point(0.5, -0.5, 1),
      PGA3.point(0.5, 0.5, 1),
      PGA3.point(-0.5, 0.5, -1)
    ]

    projected = Geometry.project_polygon(camera, quad)

    assert length(projected) > 4

    assert Enum.all?(projected, fn {x, y, z} ->
             z >= 1.0e-3 - 1.0e-9 and abs(x) <= 100 and abs(y) <= 100
           end)
  end

  test "drops a quad entirely outside the perspective frustum" do
    camera = PGA3.new(scalar: 1)

    quad = [
      PGA3.point(3, -0.5, 1),
      PGA3.point(4, -0.5, 1),
      PGA3.point(4, 0.5, 1),
      PGA3.point(3, 0.5, 1)
    ]

    assert Geometry.project_polygon(camera, quad) == []
  end

  test "clips line endpoints to the sides of the perspective frustum" do
    camera = PGA3.new(scalar: 1)
    outside = PGA3.point(3, 0, 1)
    inside = PGA3.point(0, 0, 1)

    assert {{x1, _, _}, {x2, _, _}} = Geometry.project_line(camera, outside, inside)
    assert_in_delta x1, 100, 1.0e-9
    assert_in_delta x2, 0, 1.0e-9
    assert is_nil(Geometry.project_line(camera, PGA3.point(3, 0, 1), PGA3.point(4, 0, 1)))
  end

  test "fits a circle inside a non-degenerate quadrilateral" do
    ellipse = Geometry.quad_to_ellipse({-1, -1}, {1, -1}, {1, 1}, {-1, 1})

    assert_in_delta ellipse.center_x, 0, 1.0e-9
    assert_in_delta ellipse.center_y, 0, 1.0e-9
    assert_in_delta ellipse.radius_a, 1, 1.0e-9
    assert_in_delta ellipse.radius_b, 1, 1.0e-9
  end

  test "returns a correctly oriented zero-width ellipse for an edge-on quad" do
    ellipse = Geometry.quad_to_ellipse({2, 1}, {6, 3}, {6, 3}, {2, 1})

    assert_in_delta ellipse.center_x, 4, 1.0e-9
    assert_in_delta ellipse.center_y, 2, 1.0e-9
    assert_in_delta ellipse.radius_a, :math.sqrt(5), 1.0e-9
    assert ellipse.radius_b == 0.0
    assert_in_delta ellipse.angle, :math.atan2(2, 4), 1.0e-9
  end

  test "handles a collapsed quad at a single point without dividing by zero" do
    assert Geometry.quad_to_ellipse({3, 4}, {3, 4}, {3, 4}, {3, 4}) == %{
             center_x: 3.0,
             center_y: 4.0,
             radius_a: 0.0,
             radius_b: 0.0,
             angle: 0.0
           }
  end
end
