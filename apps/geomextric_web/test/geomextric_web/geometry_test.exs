defmodule GeomextricWeb.GeometryTest do
  use ExUnit.Case, async: true

  alias GeomextricWeb.Geometry

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
