defmodule SDF3DCompilerTest do
  use ExUnit.Case, async: true

  @bounding %{x: -10, y: -20, width: 100, height: 200}

  test "prepends the bounds rectangle and both axes in order" do
    assert SDF3DCompiler.encode([], @bounding) == [
             [0, -10, -20, 100, 200, 1, 0.0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0],
             [2, -10, 0, 90, 0, 7.75, 15.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0, 0, 0, 0],
             [2, 0, -20, 0, 180, 7.75, 15.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0]
           ]
  end

  test "encodes rectangle dimensions, height, radius and normalized RGB" do
    assert records(%{pos: {2, 3, 4, 5}, attrs: %{color: "#8040ff", height: 6, radius: 7}}) ==
             [[0, 2, 3, 4, 5, 6, 7, 0, 128 / 255, 64 / 255, 1.0, 0, 0, 0, 0, 0]]
  end

  test "rectangle defaults to height 50 and radius zero" do
    assert records(%{pos: {2, 3, 4, 5}, attrs: %{color: "#000000"}}) ==
             [[0, 2, 3, 4, 5, 50.0, 0.0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0]]
  end

  test "encodes dot radius and explicit height" do
    assert records(%{pos: {2, 3}, attrs: %{color: "#ff0000", radius: 4, height: 9}}) ==
             [[1, 2, 3, 4, 9, 0, 0, 0, 1.0, 0.0, 0.0, 0, 0, 0, 0, 0]]
  end

  test "dot defaults to radius one and height twice its radius" do
    assert records(%{pos: {2, 3}, attrs: %{color: "#000000"}}) ==
             [[1, 2, 3, 1.0, 2.0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0]]

    assert records(%{pos: {2, 3}, attrs: %{color: "#000000", radius: 7}}) ==
             [[1, 2, 3, 7, 14.0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0]]
  end

  test "line uses absolute thickness, half-thickness radius, explicit height and tip flags" do
    for {source, target} <- [{false, true}, {true, false}, {false, false}, {true, true}] do
      shape = %{
        pos: {{2, 3}, {4, 5}},
        attrs: %{
          color: "#00ff80",
          thickness: -8,
          height: 12,
          source_tip: source,
          target_tip: target
        }
      }

      assert records(shape) == [
               [
                 2,
                 2,
                 3,
                 4,
                 5,
                 4.0,
                 12,
                 flag(source),
                 0.0,
                 1.0,
                 128 / 255,
                 flag(target),
                 0,
                 0,
                 0,
                 0
               ]
             ]
    end
  end

  test "line defaults to thickness one, height equal to absolute thickness and enabled tips" do
    assert records(%{pos: {{2, 3}, {4, 5}}, attrs: %{color: "#000000"}}) ==
             [[2, 2, 3, 4, 5, 0.5, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0, 0, 0, 0]]

    assert records(%{pos: {{2, 3}, {4, 5}}, attrs: %{color: "#000000", thickness: -6}}) ==
             [[2, 2, 3, 4, 5, 3.0, 6, 1.0, 0.0, 0.0, 0.0, 1.0, 0, 0, 0, 0]]
  end

  test "reverses mixed shapes and skips unknown shapes" do
    rect = %{pos: {1, 2, 3, 4}, attrs: %{color: "#000000"}}
    dot = %{pos: {5, 6}, attrs: %{color: "#000000"}}
    line = %{pos: {{7, 8}, {9, 10}}, attrs: %{color: "#000000"}}

    assert SDF3DCompiler.encode([rect, :unknown, dot, %{pos: {1, 2, 3}}, line], @bounding)
           |> Enum.drop(3) == records(line) ++ records(dot) ++ records(rect)
  end

  test "encodes hundreds of shapes as flat sixteen-number records without truncation" do
    shapes = for x <- 1..600, do: %{pos: {x, -x}, attrs: %{color: "#123456"}}
    encoded = SDF3DCompiler.encode(shapes, @bounding)

    assert length(encoded) == 603
    assert Enum.all?(encoded, &(length(&1) == 16 and Enum.all?(&1, fn n -> is_number(n) end)))
    assert Enum.map(Enum.drop(encoded, 3), &Enum.at(&1, 1)) == Enum.to_list(600..1//-1)
    assert Enum.all?(encoded, &(Enum.drop(&1, 12) == [0, 0, 0, 0]))
  end

  defp records(shape), do: Enum.drop(SDF3DCompiler.encode([shape], @bounding), 3)
  defp flag(true), do: 1.0
  defp flag(false), do: 0.0
end
