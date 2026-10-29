defmodule GeomextricWeb.CGA3LiveTest do
  use GeomextricWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Galixir.Algebras.CGA3

  test "normalizes elements before summing them", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-point-pair"))
    render_click(element(view, "#add-point-pair"))

    pair = CGA3.point_pair(CGA3.point(-1.5, 0, 0), CGA3.point(1.5, 0, 0))
    normalized_pair = CGA3.normalize!(pair)
    expected_sum = CGA3.add(normalized_pair, normalized_pair) |> inspect(limit: :infinity)

    assert has_element?(view, "#cga3-sum-expression[value='#{expected_sum}']")
  end

  test "dualizes and negates individual scene elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    assert has_element?(view, "#dual-element-0")
    assert has_element?(view, "#negate-element-0")
    assert has_element?(view, "#cga3-element-color-0[value='#b45309']")

    render_click(element(view, "#dual-element-0"))

    dual_expression = inspect(CGA3.dual(CGA3.plane({0, 0, 1}, 0)), limit: :infinity)
    assert has_element?(view, "#cga3-element-expression-0[value='#{dual_expression}']")
    assert has_element?(view, "#cga3-element-panel-0 summary", "Dual of Plane 1")
    assert has_element?(view, "#cga3-element-0-nz[type=range]")
    assert has_element?(view, "#cga3-element-color-0[value='#b45309']")

    render_click(element(view, "#negate-element-0"))

    negated_expression =
      inspect(CGA3.scale(-1, CGA3.dual(CGA3.plane({0, 0, 1}, 0))), limit: :infinity)

    assert has_element?(view, "#cga3-element-expression-0[value='#{negated_expression}']")
    assert has_element?(view, "#cga3-element-color-0[value='#b45309']")
  end

  test "dual elements retain their primitive label and editable controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    for {index, add_button, label, control_id, change} <- [
          {0, "#add-plane", "Plane", "nz", %{"nz" => "0.8"}},
          {1, "#add-sphere", "Sphere", "radius", %{"radius" => "1.8"}},
          {2, "#add-line", "Line", "dx", %{"dx" => "0.8"}},
          {3, "#add-circle", "Circle", "radius", %{"radius" => "1.8"}},
          {4, "#add-point-pair", "Point pair", "ax", %{"ax" => "-2.0"}}
        ] do
      render_click(element(view, add_button))
      render_click(element(view, "#dual-element-#{index}"))

      assert has_element?(
               view,
               "#cga3-element-panel-#{index} summary",
               "Dual of #{label} #{index + 1}"
             )

      assert has_element?(view, "#cga3-element-#{index}-#{control_id}[type=range]")

      render_hook(
        view,
        "change_element",
        Map.merge(%{"index" => Integer.to_string(index)}, change)
      )

      assert has_element?(
               view,
               "#cga3-element-panel-#{index} summary",
               "Dual of #{label} #{index + 1}"
             )
    end
  end

  test "renders and preserves imaginary point pairs created by dualizing a circle", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)
    render_click(element(view, "#add-circle"))

    render_hook(view, "change_element", %{"index" => "0", "radius" => "-2"})
    render_click(element(view, "#dual-element-0"))

    imaginary_pair = CGA3.circle({0, 0, 0}, -2, {0, 0, 1}) |> CGA3.dual()
    expression = inspect(imaginary_pair, limit: :infinity)

    assert has_element?(view, "#cga3-element-expression-0[readonly][value='#{expression}']")
    assert has_element?(view, "#dual-element-0")
    assert has_element?(view, "#negate-element-0")

    render_hook(view, "change_element", %{"index" => "0", "color" => "#ff0000"})
    assert has_element?(view, "#cga3-element-color-0[value='#ff0000']")
  end

  test "keeps derived render toggles enabled without enough elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    assert has_element?(view, "#cga3-show-sum-all:not([disabled])")
    assert has_element?(view, "#cga3-show-meet-all:not([disabled])")
    assert has_element?(view, "#cga3-show-gp-all:not([disabled])")

    render_change(element(view, "#cga3-meet-visibility"), %{"meet_all" => "on"})
    render_change(element(view, "#cga3-sum-visibility"), %{"sum_all" => "on"})
    render_change(element(view, "#cga3-gp-visibility"), %{"gp_all" => "on"})

    assert has_element?(view, "#cga3-show-meet-all:checked")
    assert has_element?(view, "#cga3-show-sum-all:checked")
    assert has_element?(view, "#cga3-show-gp-all:checked")
    refute has_element?(view, "#scene-object-meet-all-result")
    refute has_element?(view, "#scene-object-sum-all-result")
    refute has_element?(view, "#scene-object-gp-all-result")

    render_click(element(view, "#add-plane"))
    assert has_element?(view, "#cga3-show-meet-all:checked")
    assert has_element?(view, "#cga3-show-sum-all:checked")
    assert has_element?(view, "#cga3-show-gp-all:checked")
    refute has_element?(view, "#scene-object-meet-all-result")
    refute has_element?(view, "#scene-object-sum-all-result")
    refute has_element?(view, "#scene-object-gp-all-result")

    render_click(element(view, "#add-plane-y"))
    assert has_element?(view, "#scene-object-meet-all-result line.scene-line")
    assert has_element?(view, "#scene-object-sum-all-result")
    assert has_element?(view, "#cga3-meet-result strong", "Meet all")
    assert has_element?(view, "#cga3-meet-expression[readonly]")
    refute has_element?(view, "#cga3-element-2")
    refute has_element?(view, "#delete-element-2")

    render_change(element(view, "#cga3-meet-visibility"), %{"meet_all" => "off"})
    refute has_element?(view, "#scene-object-meet-all-result")

    render_change(element(view, "#cga3-meet-visibility"), %{"meet_all" => "on"})
    render_click(element(view, "#delete-element-1"))

    assert has_element?(view, "#cga3-show-meet-all:checked")
    assert has_element?(view, "#cga3-show-sum-all:checked")
    assert has_element?(view, "#cga3-show-gp-all:checked")
    refute has_element?(view, "#scene-object-meet-all-result")
    refute has_element?(view, "#scene-object-sum-all-result")
    refute has_element?(view, "#scene-object-gp-all-result")
  end

  test "renders and edits point results from intersecting three planes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    assert has_element?(view, "#cga3-show-meet-all:checked")

    clear_initial_plane(view)
    render_click(element(view, "#add-plane"))
    render_click(element(view, "#add-plane-y"))
    render_click(element(view, "#add-plane-z"))
    render_click(element(view, "#cga3-apply-meet-all"))

    assert has_element?(view, "#cga3-element-panel-0 summary", "Point 1")
    assert has_element?(view, "#scene-object-0 circle.scene-point")
    assert has_element?(view, "#cga3-element-0-x[type=range]")

    render_hook(view, "change_element", %{"index" => "0", "x" => "1.5"})
    assert has_element?(view, "#cga3-element-0-x[value='1.5']")
  end

  test "applies Sum, Meet, and GP by replacing scene elements", %{conn: conn} do
    operations = [
      {"sum", "#cga3-apply-sum-all"},
      {"meet", "#cga3-apply-meet-all"},
      {"gp", "#cga3-apply-gp-all"}
    ]

    for {operation, button_id} <- operations do
      {:ok, view, _html} = live(conn, "/cga3")
      clear_initial_plane(view)
      render_click(element(view, "#add-plane"))
      render_click(element(view, "#add-plane-y"))

      first = CGA3.plane({1, 0, 0}, 0)
      second = CGA3.plane({0, 1, 0}, 0)

      result =
        case operation do
          "sum" ->
            first = CGA3.normalize!(first)
            second = CGA3.normalize!(second)
            CGA3.add(first, second)

          "meet" ->
            CGA3.meet(first, second)

          "gp" ->
            CGA3.gp(first, second)
        end

      expression = inspect(result, limit: :infinity)
      assert has_element?(view, button_id)
      render_click(element(view, button_id))

      assert has_element?(view, "#cga3-element-expression-0[readonly][value='#{expression}']")
      assert has_element?(view, "#cga3-element-panel-0")
      refute has_element?(view, "#cga3-element-panel-1")

      render_click(element(view, "#add-sphere"))
      assert has_element?(view, "#cga3-element-color-1[value='#2563eb']")
    end
  end

  test "shows the geometric product result and selects cloud transforms", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-plane"))
    render_click(element(view, "#add-plane-y"))

    assert has_element?(view, "#cga3-gp-expression[readonly]")
    assert has_element?(view, "#cga3-show-gp-all:not([disabled])")
    assert has_element?(view, "#cga3-transform-gp:checked")

    render_change(element(view, "#cga3-gp-visibility"), %{"gp_all" => "on"})
    assert has_element?(view, "#cga3-show-gp-all:checked")

    render_change(element(view, "#cga3-transform-sum-form"), %{"point_cloud_transform" => "sum"})
    assert has_element?(view, "#cga3-transform-sum:checked")
    refute has_element?(view, "#cga3-transform-gp:checked")

    render_change(element(view, "#cga3-transform-meet-form"), %{"point_cloud_transform" => "meet"})

    assert has_element?(view, "#cga3-transform-meet:checked")

    render_click(element(view, "#delete-element-1"))
    assert has_element?(view, "#cga3-transform-meet:checked")
    assert has_element?(view, "#cga3-transform-sum:not([disabled])")
    assert has_element?(view, "#cga3-transform-meet:not([disabled])")
    assert has_element?(view, "#cga3-show-gp-all:not([disabled])")
    assert has_element?(view, "#cga3-show-gp-all:checked")
    refute has_element?(view, "#scene-object-gp-all-result")
  end

  test "toggles the independent vector-field point cloud", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")

    refute has_element?(view, "#vector-field")
    refute has_element?(view, "#cga3-show-vector-field:checked")

    render_change(
      element(view, "#cga3-vector-field-visibility"),
      %{"vector_field" => "on"}
    )

    render_async(view, 2_000)

    assert has_element?(view, "#cga3-show-vector-field:checked")
    assert has_element?(view, "#vector-field[data-arrow-count='0']")

    render_click(element(view, "#add-plane"))
    render_async(view, 2_000)

    assert has_element?(view, "#vector-field[data-arrow-count='20']")

    assert has_element?(
             view,
             "#vector-field polyline.vector-field-arrow[data-step-count='10'][marker-end='url(#cga3-vector-arrow)']"
           )

    refute has_element?(view, "#vector-field circle")
    refute has_element?(view, "#cga3-point-cloud-offset")

    render_change(
      element(view, "#cga3-vector-field-visibility"),
      %{"vector_field" => "off"}
    )

    refute has_element?(view, "#vector-field")
  end

  test "scene edits debounce vector-field recalculation and discard stale results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    render_click(element(view, "#add-plane"))

    render_change(
      element(view, "#cga3-vector-field-visibility"),
      %{"vector_field" => "on"}
    )

    render_click(element(view, "#delete-element-1"))
    render_async(view, 2_000)

    assert has_element?(view, "#vector-field[data-arrow-count='0']")
  end

  test "a line generates a rotational vector field from its dual bivector", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-line"))

    render_change(
      element(view, "#cga3-vector-field-visibility"),
      %{"vector_field" => "on"}
    )

    render_async(view, 2_000)

    assert has_element?(view, "#vector-field[data-arrow-count='20']")

    assert has_element?(
             view,
             "#vector-field polyline.vector-field-arrow[data-step-count='10'][marker-end='url(#cga3-vector-arrow)']"
           )
  end

  test "point-cloud transforms remain selectable with no scene elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_change(element(view, "#cga3-cloud-visibility"), %{"point_cloud" => "on"})
    assert has_element?(view, "#transformed-point-cloud")

    for {operation, form_id, radio_id} <- [
          {"sum", "#cga3-transform-sum-form", "#cga3-transform-sum"},
          {"meet", "#cga3-transform-meet-form", "#cga3-transform-meet"},
          {"gp", "#cga3-transform-gp-form", "#cga3-transform-gp"}
        ] do
      render_change(element(view, form_id), %{"point_cloud_transform" => operation})
      assert has_element?(view, "#{radio_id}:checked")
      assert has_element?(view, "#transformed-point-cloud")

      if operation == "sum" do
        assert has_element?(view, "#transformed-point-cloud[data-point-count='0']")
      end
    end

    assert has_element?(view, "#cga3-sum-expression[readonly]")
    assert has_element?(view, "#cga3-meet-expression[readonly]")
    assert has_element?(view, "#cga3-gp-expression[readonly]")
  end

  test "renders dual point pairs for imaginary circle meets", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-sphere"))
    render_click(element(view, "#add-sphere"))

    render_hook(view, "change_element", %{
      "index" => "1",
      "x" => "7",
      "color" => "#2563eb"
    })

    render_change(element(view, "#cga3-meet-visibility"), %{"meet_all" => "on"})

    assert has_element?(view, "#scene-object-meet-all-result line.point-pair-link")
    assert has_element?(view, "#scene-object-meet-all-result circle.point-pair-point")
    assert has_element?(view, "#cga3-meet-result strong", "Meet all")
    assert has_element?(view, "#cga3-meet-expression[readonly]")
  end

  test "renders tangent circle meets as points", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-sphere"))
    render_click(element(view, "#add-plane"))

    render_hook(view, "change_element", %{
      "index" => "1",
      "distance" => "3.5",
      "color" => "#2563eb"
    })

    render_change(element(view, "#cga3-meet-visibility"), %{"meet_all" => "on"})

    assert has_element?(view, "#scene-object-meet-all-result circle.scene-circle-tangent")
    assert has_element?(view, "#cga3-meet-result strong", "Meet all")
    assert has_element?(view, "#cga3-meet-expression[readonly]")
  end

  test "adds and edits projected lines", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-line"))

    assert has_element?(
             view,
             "#scene-object-0 line.scene-line[marker-end='url(#cga3-line-arrow)']"
           )

    assert has_element?(view, "#cga3-line-arrow circle")

    assert has_element?(view, "#cga3-element-0-dx[type=range]")
    assert has_element?(view, "#cga3-element-0-ox[type=range]")

    render_hook(view, "change_element", %{
      "index" => "0",
      "dx" => "1",
      "dy" => "0",
      "dz" => "0",
      "ox" => "2",
      "oy" => "3",
      "oz" => "1",
      "color" => "#b45309"
    })

    assert has_element?(view, "#cga3-element-0-dx[value^='1']")
    assert has_element?(view, "#scene-object-0[stroke='#b45309'] line.scene-line")
  end

  test "adds and edits projected circles", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-circle"))

    assert has_element?(view, "#scene-object-0 ellipse.scene-circle[fill='#b45309']")
    assert has_element?(view, "#cga3-element-0-radius[type=range]")
    assert has_element?(view, "#cga3-element-0-nz[type=range]")

    render_hook(view, "change_element", %{
      "index" => "0",
      "x" => "1.5",
      "y" => "-0.5",
      "z" => "2",
      "radius" => "3",
      "nx" => "0",
      "ny" => "1",
      "nz" => "0",
      "color" => "#15803d"
    })

    assert has_element?(view, "#cga3-element-0-x[value='1.5']")
    assert has_element?(view, "#cga3-element-0-radius[value='3.0']")
    assert has_element?(view, "#scene-object-0 ellipse.scene-circle[fill='#15803d']")
  end

  test "adds and edits projected point pairs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-point-pair"))

    assert has_element?(view, "#scene-object-0 line.point-pair-link[stroke-dasharray]")
    assert has_element?(view, "#scene-object-0 circle.point-pair-point")
    assert has_element?(view, "#cga3-element-0-ax[type=range]")
    assert has_element?(view, "#cga3-element-0-bz[type=range]")

    render_hook(view, "change_element", %{
      "index" => "0",
      "ax" => "-2",
      "color" => "#2563eb"
    })

    assert has_element?(view, "#cga3-element-0-ax[value^='-2']")
    assert has_element?(view, "#cga3-element-0-bx[value^='1.5']")

    render_hook(view, "change_element", %{
      "index" => "0",
      "ax" => "-2",
      "ay" => "1",
      "az" => "0.5",
      "bx" => "2",
      "by" => "1",
      "bz" => "0.5",
      "color" => "#2563eb"
    })

    assert has_element?(view, "#cga3-element-0-ax[value^='-2']")
    assert has_element?(view, "#cga3-element-0-bx[value^='2']")
    assert has_element?(view, "#scene-object-0 circle.point-pair-point[fill='#2563eb']")
  end

  test "renders a negative-radius sphere as an imaginary shell", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)
    render_click(element(view, "#add-sphere"))

    render_hook(view, "change_element", %{"index" => "0", "radius" => "-1"})

    assert has_element?(view, "#scene-object-0 ellipse.sphere-ring-imaginary")
    assert has_element?(view, "#cga3-element-0-radius[value='-1.0']")
  end

  test "renders a tangent sphere without crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)
    render_click(element(view, "#add-sphere"))

    render_hook(view, "change_element", %{"index" => "0", "radius" => "0"})

    assert has_element?(view, "#scene-object-0 circle.sphere-tangent")
    refute has_element?(view, "#scene-object-0 ellipse.sphere-fill")
  end

  test "sphere silhouettes tolerate steep camera angles", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)
    render_click(element(view, "#add-sphere"))

    render_hook(view, "rot", %{"v" => "4.9", "h" => "0"})

    assert has_element?(view, "#scene-object-0 ellipse.sphere-fill")
    assert has_element?(view, "#cga3-scene")
  end

  test "axis add groups create oriented objects", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    default_axes = %{
      "point" => "x",
      "sphere" => "x",
      "plane" => "x",
      "line" => "y",
      "circle" => "z",
      "point-pair" => "x"
    }

    for group <- ["point", "sphere", "plane", "line", "circle", "point-pair"] do
      assert has_element?(view, "#add-#{group}-group.axis-add-group")

      if group in ["point", "sphere"] do
        assert has_element?(view, "#add-#{group}-origin[phx-value-axis='origin']")
      end

      for axis <- ["x", "y", "z"] do
        button_id =
          if axis == Map.fetch!(default_axes, group),
            do: "#add-#{group}",
            else: "#add-#{group}-#{axis}"

        assert has_element?(view, button_id)
      end
    end

    for {axis, expected} <- [
          {"x", {"1.0", "0.0", "0.0"}},
          {"y", {"0.0", "1.0", "0.0"}},
          {"z", {"0.0", "0.0", "1.0"}}
        ] do
      {x, y, z} = expected
      button_id = if axis == "x", do: "#add-sphere", else: "#add-sphere-#{axis}"
      render_click(element(view, button_id))
      assert has_element?(view, "#add-sphere-group.expanded")

      index =
        case axis do
          "x" -> 0
          "y" -> 1
          "z" -> 2
        end

      assert has_element?(view, "#cga3-element-#{index}-x[value='#{x}']")
      assert has_element?(view, "#cga3-element-#{index}-y[value='#{y}']")
      assert has_element?(view, "#cga3-element-#{index}-z[value='#{z}']")
    end

    render_click(element(view, "#add-plane"))
    assert has_element?(view, "#cga3-element-3-nx[value='1.0']")
    render_click(element(view, "#add-plane-y"))
    assert has_element?(view, "#cga3-element-4-ny[value='1.0']")
    render_click(element(view, "#add-plane-z"))
    assert has_element?(view, "#cga3-element-5-nz[value='1.0']")

    render_click(element(view, "#add-line-x"))
    assert has_element?(view, "#cga3-element-6-dx[value='1.0']")
    render_click(element(view, "#add-line-z"))
    assert has_element?(view, "#cga3-element-7-dz[value='1.0']")

    render_click(element(view, "#add-circle-x"))
    assert has_element?(view, "#cga3-element-8-nx[value='1.0']")
    render_click(element(view, "#add-circle-y"))
    assert has_element?(view, "#cga3-element-9-ny[value='1.0']")

    render_click(element(view, "#add-point-pair-y"))
    assert has_element?(view, "#cga3-element-10-ay[value^='-1.5']")
    assert has_element?(view, "#cga3-element-10-by[value^='1.5']")
    render_click(element(view, "#add-point-pair-z"))
    assert has_element?(view, "#cga3-element-11-az[value^='-1.5']")
    assert has_element?(view, "#cga3-element-11-bz[value^='1.5']")

    render_click(element(view, "#add-point-origin"))
    assert has_element?(view, "#scene-object-12 circle.scene-point")
    assert has_element?(view, "#cga3-element-12-x[value='0.0']")
    assert has_element?(view, "#cga3-element-12-y[value='0.0']")
    assert has_element?(view, "#cga3-element-12-z[value='0.0']")

    for {axis, expected} <- [
          {"x", {"1.0", "0.0", "0.0"}},
          {"y", {"0.0", "1.0", "0.0"}},
          {"z", {"0.0", "0.0", "1.0"}}
        ] do
      {x, y, z} = expected
      button_id = if axis == "x", do: "#add-point", else: "#add-point-#{axis}"
      render_click(element(view, button_id))

      index =
        case axis do
          "x" -> 13
          "y" -> 14
          "z" -> 15
        end

      assert has_element?(view, "#scene-object-#{index} circle.scene-point")

      point_reflection =
        CGA3.new(
          e1p: String.to_float(x),
          e1m: String.to_float(x),
          e2p: String.to_float(y),
          e2m: String.to_float(y),
          e3p: String.to_float(z),
          e3m: String.to_float(z),
          epm: -1.0
        )

      assert has_element?(
               view,
               "#cga3-element-expression-#{index}[value='#{inspect(point_reflection, limit: :infinity)}']"
             )

      assert has_element?(view, "#cga3-element-#{index}-x[value='#{x}']")
      assert has_element?(view, "#cga3-element-#{index}-y[value='#{y}']")
      assert has_element?(view, "#cga3-element-#{index}-z[value='#{z}']")
    end
  end

  test "editing a point reflection preserves its grade-2 representation", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)

    render_click(element(view, "#add-plane"))
    render_click(element(view, "#add-plane-y"))
    render_click(element(view, "#add-plane-z"))
    render_click(element(view, "#cga3-apply-gp-all"))

    point_at_origin = CGA3.new(epm: -1.0)

    assert has_element?(
             view,
             "#cga3-element-expression-0[value='#{inspect(point_at_origin, limit: :infinity)}']"
           )

    assert has_element?(view, "#cga3-element-0-x[value='0.0']")

    render_change(element(view, "#cga3-element-0"), %{
      "index" => "0",
      "color" => "#b45309",
      "x" => "0.1",
      "y" => "0.0",
      "z" => "0.0"
    })

    moved_point = CGA3.new(e1p: 0.1, e1m: 0.1, epm: -1.0)

    assert has_element?(
             view,
             "#cga3-element-expression-0[value='#{inspect(moved_point, limit: :infinity)}']"
           )
  end

  test "creates spheres and points at the origin", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/cga3")
    clear_initial_plane(view)
    render_change(element(view, "#cga3-cloud-visibility"), %{"point_cloud" => "off"})

    render_click(element(view, "#add-sphere-origin"))
    assert has_element?(view, "#cga3-element-0-x[value='0.0']")
    assert has_element?(view, "#cga3-element-0-y[value='0.0']")
    assert has_element?(view, "#cga3-element-0-z[value='0.0']")

    render_click(element(view, "#add-point-origin"))
    assert has_element?(view, "#scene-object-1 circle.scene-point")
    point_at_origin = CGA3.new(epm: -1.0)

    assert has_element?(
             view,
             "#cga3-element-expression-1[value='#{inspect(point_at_origin, limit: :infinity)}']"
           )

    assert has_element?(view, "#cga3-element-1-x[value='0.0']")
    assert has_element?(view, "#cga3-element-1-y[value='0.0']")
    assert has_element?(view, "#cga3-element-1-z[value='0.0']")
  end

  test "starts with a plane and hidden point clouds, then adds and deletes elements", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/cga3")

    assert has_element?(view, "#cga3-scene")
    assert has_element?(view, "#cga3-axis-indicator g.axis-x line[stroke='#ef4444']")
    assert has_element?(view, "#cga3-axis-indicator g.axis-y line[stroke='#22c55e']")

    assert has_element?(
             view,
             "#cga3-axis-indicator g.axis-z line[stroke='#3b82f6'][marker-end='url(#cga3-axis-arrow)']"
           )

    assert has_element?(view, "#cga3-axis-arrow circle")
    assert has_element?(view, "#cga3-ground-grid polygon.ground-grid-cell[fill='none']")
    refute has_element?(view, "#cga3-ground-grid polygon.plane-fill")

    assert has_element?(view, "#scene-object-0 polygon.grid-cell")
    assert has_element?(view, "#cga3-element-expression-0[readonly][value='~G[-1.0e12pm]']")
    refute has_element?(view, "#point-cloud")
    refute has_element?(view, "#transformed-point-cloud")
    refute has_element?(view, "#cga3-show-point-cloud:checked")
    assert has_element?(view, "#cga3-sum-expression[readonly][value='~G[-1.0e12pm]']")
    assert has_element?(view, "#cga3-show-sum-all:not([disabled])")
    refute has_element?(view, "#cga3-show-sum-all:checked")
    assert has_element?(view, "#cga3-show-meet-all:not([disabled])")
    assert has_element?(view, "#cga3-meet-expression[readonly][value]")
    refute has_element?(view, "#cga3-meet-expression[value='Needs at least two elements']")
    refute has_element?(view, "#scene-object-meet-all-result")

    render_change(element(view, "#cga3-sum-visibility"), %{"sum_all" => "on"})
    assert has_element?(view, "#cga3-show-sum-all:checked")
    refute has_element?(view, "#scene-object-sum-all-result")

    clear_initial_plane(view)

    render_change(element(view, "#cga3-cloud-visibility"), %{"point_cloud" => "on"})
    assert has_element?(view, "#point-cloud")
    assert has_element?(view, "#transformed-point-cloud")
    assert has_element?(view, "#cga3-show-point-cloud:checked")

    render_change(element(view, "#cga3-point-cloud-offset"), %{
      "x" => "2.5",
      "y" => "-1",
      "z" => "0.5"
    })

    assert has_element?(view, "#cga3-point-cloud-offset-x[value='2.5']")
    assert has_element?(view, "#cga3-point-cloud-offset-y[value^='-1']")
    assert has_element?(view, "#cga3-point-cloud-offset-z[value='0.5']")

    assert has_element?(view, "#add-sphere:not([disabled])")
    assert has_element?(view, "#add-plane:not([disabled])")

    render_click(element(view, "#add-plane"))
    assert has_element?(view, "#scene-object-0 polygon[fill='#b45309']")
    assert has_element?(view, "#cga3-element-expression-0[type=text][readonly][value^='~G[']")
    assert has_element?(view, "details#cga3-element-panel-0")
    assert has_element?(view, "#cga3-element-color-0[type=color][value='#b45309']")
    assert has_element?(view, "#cga3-element-0-nx[type=range]")
    assert has_element?(view, "#cga3-element-0-distance[type=range]")

    render_click(element(view, "#add-sphere"))
    assert has_element?(view, "#scene-object-1 ellipse.sphere-fill")
    assert has_element?(view, "#cga3-element-expression-1[type=text][readonly][value^='~G[']")
    assert has_element?(view, "#scene-object-1 ellipse.sphere-ring-secondary")
    assert has_element?(view, "#scene-object-1[stroke='#2563eb']")
    assert has_element?(view, "#cga3-element-1-x[type=range]")
    assert has_element?(view, "#cga3-element-1-radius[type=range]")

    render_click(element(view, "#add-plane-y"))
    assert has_element?(view, "#scene-object-2 polygon[fill='#15803d']")
    assert has_element?(view, "#cga3-element-2-ny[type=range]")
    assert has_element?(view, "#cga3-element-2-ny[value='1.0']")

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

  defp clear_initial_plane(view) do
    render_click(element(view, "#delete-element-0"))
  end
end
