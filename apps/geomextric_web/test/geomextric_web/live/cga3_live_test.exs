defmodule GeomextricWeb.CGA3LiveTest do
  use GeomextricWeb.ConnCase

  import Phoenix.LiveViewTest

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
    refute has_element?(view, "#scene-object-0 ellipse")
    assert has_element?(view, "#add-sphere:not([disabled])")
    assert has_element?(view, "#add-plane:not([disabled])")
    assert has_element?(view, "details#cga3-element-panel-0")
    assert has_element?(view, "#cga3-element-color-0[type=color][value='#b45309']")
    assert has_element?(view, "#cga3-element-0-nx[type=range]")
    assert has_element?(view, "#cga3-element-0-distance[type=range]")

    render_click(element(view, "#add-sphere"))
    assert has_element?(view, "#scene-object-1 ellipse.sphere-fill")
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
