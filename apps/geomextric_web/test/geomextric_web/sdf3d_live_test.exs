defmodule GeomextricWeb.SDF3DLiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "scene metadata is hidden so it does not displace the canvas grid item" do
    html =
      render_component(&GeomextricWeb.SDF3DLive.render/1,
        box: %{x: 0, y: 0, width: 100, height: 100},
        layers: []
      )

    document = LazyHTML.from_fragment(html)
    metadata = LazyHTML.query(document, "#canvas > [data-scene][hidden]")

    assert LazyHTML.to_tree(metadata) != []
  end

  test "renders separate records with stable shape IDs in scene order" do
    shapes = [
      %{id: "new", pos: {10, 20}, attrs: %{color: "#ff0000"}},
      %{id: "old", pos: {30, 40}, attrs: %{color: "#00ff00"}}
    ]

    render = fn layers ->
      render_component(&GeomextricWeb.SDF3DLive.render/1,
        box: %{x: 0, y: 0, width: 100, height: 100},
        layers: layers
      )
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#sdf3d-scene-data > [data-shape]")
      |> LazyHTML.to_tree()
      |> Enum.map(fn {"div", attrs, _} ->
        {List.keyfind(attrs, "id", 0) |> elem(1),
         List.keyfind(attrs, "data-shape", 0) |> elem(1) |> Jason.decode!()}
      end)
    end

    original = render.(shapes)
    moved = render.([%{hd(shapes) | pos: {50, 60}}, List.last(shapes)])

    assert Enum.map(original, &elem(&1, 0)) ==
             ["sdf3d-bounds", "sdf3d-x-axis", "sdf3d-y-axis", "sdf3d-old", "sdf3d-new"]

    assert Enum.drop(original, -1) == Enum.drop(moved, -1)
    assert {"sdf3d-new", [1, 50, 60 | _]} = List.last(moved)
    assert render.([List.last(shapes)]) == Enum.drop(original, -1)
  end
end
