defmodule GeomextricWeb.CGA3LiveTest do
  use GeomextricWeb.ConnCase

  import Phoenix.LiveViewTest

  test "adds and edits projected lines", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    render_click(element(view, "#add-line"))

    assert has_element?(view, "#scene-object-1 line.scene-line")
    assert has_element?(view, "#cga3-element-1-dx[type=range]")
    assert has_element?(view, "#cga3-element-1-ox[type=range]")

    render_hook(view, "change_element", %{
      "index" => "1",
      "dx" => "1",
      "dy" => "0",
      "dz" => "0",
      "ox" => "2",
      "oy" => "3",
      "oz" => "1",
      "color" => "#2563eb"
    })

    assert has_element?(view, "#cga3-element-1-dx[value^='1']")
    assert has_element?(view, "#scene-object-1[stroke='#2563eb'] line.scene-line")
  end

  test "adds and edits projected circles", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    render_click(element(view, "#add-circle"))

    assert has_element?(view, "#scene-object-1 ellipse.scene-circle[fill='#2563eb']")
    assert has_element?(view, "#cga3-element-1-radius[type=range]")
    assert has_element?(view, "#cga3-element-1-nz[type=range]")

    render_hook(view, "change_element", %{
      "index" => "1",
      "x" => "1.5",
      "y" => "-0.5",
      "z" => "2",
      "radius" => "3",
      "nx" => "0",
      "ny" => "1",
      "nz" => "0",
      "color" => "#15803d"
    })

    assert has_element?(view, "#cga3-element-1-x[value='1.5']")
    assert has_element?(view, "#cga3-element-1-radius[value='3.0']")
    assert has_element?(view, "#scene-object-1 ellipse.scene-circle[fill='#15803d']")
  end

  test "adds and edits projected point pairs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    render_click(element(view, "#add-point-pair"))

    assert has_element?(view, "#scene-object-1 line.point-pair-link")
    assert has_element?(view, "#scene-object-1 circle.point-pair-point")
    assert has_element?(view, "#cga3-element-1-ax[type=range]")
    assert has_element?(view, "#cga3-element-1-bz[type=range]")

    render_hook(view, "change_element", %{
      "index" => "1",
      "ax" => "-2",
      "color" => "#2563eb"
    })

    assert has_element?(view, "#cga3-element-1-ax[value^='-1.99']")
    assert has_element?(view, "#cga3-element-1-bx[value^='-1.49']")

    render_hook(view, "change_element", %{
      "index" => "1",
      "ax" => "-2",
      "ay" => "1",
      "az" => "0.5",
      "bx" => "2",
      "by" => "1",
      "bz" => "0.5",
      "color" => "#2563eb"
    })

    assert has_element?(view, "#cga3-element-1-ax[value^='-2']")
    assert has_element?(view, "#cga3-element-1-bx[value^='2']")
    assert has_element?(view, "#scene-object-1 circle.point-pair-point[fill='#2563eb']")
  end

  test "sphere silhouettes tolerate steep camera angles", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    render_click(element(view, "#add-sphere"))

    render_hook(view, "rot", %{"v" => "4.9", "h" => "0"})

    assert has_element?(view, "#scene-object-1 ellipse.sphere-fill")
    assert has_element?(view, "#cga3-scene")
  end

  test "cycles added spheres through the origin and unit axis centers", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    centers = [
      {1, "0.0", "0.0", "0.0"},
      {2, "1.0", "0.0", "0.0"},
      {3, "0.0", "1.0", "0.0"},
      {4, "0.0", "0.0", "1.0"}
    ]

    for {index, x, y, z} <- centers do
      render_click(element(view, "#add-sphere"))
      assert has_element?(view, "#cga3-element-#{index}-x[value='#{x}']")
      assert has_element?(view, "#cga3-element-#{index}-y[value='#{y}']")
      assert has_element?(view, "#cga3-element-#{index}-z[value='#{z}']")
    end
  end

  test "cycles added planes through X, Y, and Z normals", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    for {index, field} <- [{1, "nx"}, {2, "ny"}, {3, "nz"}, {4, "nx"}] do
      render_click(element(view, "#add-plane"))
      assert has_element?(view, "#cga3-element-#{index}-#{field}[value='1.0']")
    end
  end

  test "starts with a plane, adds and deletes colored elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    assert has_element?(view, "#cga3-scene")

    assert has_element?(
             view,
             "#point-cloud[data-point-count='99'][opacity='0.65'] circle[fill='#f97316']"
           )

    assert has_element?(
             view,
             "#transformed-point-cloud[data-point-count='99'][opacity='0.55'] circle[fill='#2563eb']"
           )

    assert has_element?(view, "#scene-object-0 polygon[fill='#b45309']")
    assert has_element?(view, "#cga3-element-expression-0", "~G[")
    refute has_element?(view, "#scene-object-0 ellipse")
    assert has_element?(view, "#add-sphere:not([disabled])")
    assert has_element?(view, "#add-plane:not([disabled])")
    assert has_element?(view, "details#cga3-element-panel-0")
    assert has_element?(view, "#cga3-element-color-0[type=color][value='#b45309']")
    assert has_element?(view, "#cga3-element-0-nx[type=range]")
    assert has_element?(view, "#cga3-element-0-distance[type=range]")

    render_click(element(view, "#add-sphere"))
    assert has_element?(view, "#scene-object-1 ellipse.sphere-fill")
    assert has_element?(view, "#cga3-element-expression-1", "~G[")
    assert has_element?(view, "#scene-object-1 ellipse.sphere-ring-secondary")
    assert has_element?(view, "#scene-object-1[stroke='#2563eb']")
    assert has_element?(view, "#cga3-element-1-x[type=range]")
    assert has_element?(view, "#cga3-element-1-radius[type=range]")

    render_click(element(view, "#add-plane"))
    assert has_element?(view, "#scene-object-2 polygon[fill='#15803d']")
    assert has_element?(view, "#cga3-element-2-nz[type=range]")
    assert has_element?(view, "#cga3-element-2-nx[value='1.0']")

    render_hook(view, "change_element", %{"index" => "1", "color" => "#ff0000"})
    assert has_element?(view, "#cga3-element-color-1[value='#ff0000']")
    assert has_element?(view, "#scene-object-1[stroke='#ff0000']")

    render_hook(view, "change_element", %{"index" => "1", "x" => "2.5", "color" => "#ff0000"})
    assert has_element?(view, "#cga3-element-1-x[value='2.5']")

    render_hook(view, "change_element", %{"index" => "0", "distance" => "2", "color" => "#b45309"})

    assert has_element?(view, "#cga3-element-0-distance[value^='2']")

    render_click(element(view, "#delete-element-1"))
    refute has_element?(view, "#scene-object-2 polygon")
    render_click(element(view, "#add-sphere"))
    assert has_element?(view, "#scene-object-2[stroke='#2563eb']")

    render_hook(view, "zoom", %{"value" => "20"})
    assert has_element?(view, "#cga3-zoom[type=range][value^='20']")

    render_hook(view, "zoom_by", %{"value" => "0.1"})
    assert has_element?(view, "#cga3-zoom[type=range][value^='22.1']")

    for _ <- 1..13, do: render_click(element(view, "#add-sphere"))
    assert has_element?(view, "#add-sphere[disabled]")
    assert has_element?(view, "#add-plane[disabled]")

    render_click(element(view, "#delete-element-15"))
    assert has_element?(view, "#add-plane:not([disabled])")
    render_click(element(view, "#add-plane"))
    assert has_element?(view, "#scene-object-15[stroke='#9f1239']")
  end
end
