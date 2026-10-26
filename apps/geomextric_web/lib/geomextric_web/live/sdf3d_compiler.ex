defmodule SDF3DCompiler do
  @doc """
  Encodes scene-order records for a four-texel-wide RGBA32F texture.

  Texel 0 stores type and geometry; texel 1 stores remaining dimensions and
  the source tip flag. Texel 2 stores RGB and the target tip flag; texel 3
  is reserved. Types are rectangle (0), dot (1), and line (2).
  """
  def encode(shapes, bounding) do
    scene_shapes(shapes, bounding) |> Enum.flat_map(&encode_shape/1)
  end

  @doc "Encodes scene records with stable DOM IDs for keyed LiveView rendering."
  def encode_entries(shapes, bounding) do
    scene_shapes(shapes, bounding)
    |> Enum.flat_map(fn shape ->
      Enum.map(encode_shape(shape), fn data ->
        %{id: "sdf3d-#{shape.id}", data: data}
      end)
    end)
  end

  defp scene_shapes(shapes, bounding) do
    bounds = %{
      id: "bounds",
      pos: {bounding.x, bounding.y, bounding.width, bounding.height},
      attrs: %{color: "#ffffff", radius: 0.0, height: 1}
    }

    x_axis = %{
      id: "x-axis",
      pos: {{bounding.x, 0}, {bounding.x + bounding.width, 0}},
      attrs: %{color: "#000000", thickness: -15.5, source_tip: false, target_tip: true}
    }

    y_axis = %{
      id: "y-axis",
      pos: {{0, bounding.y}, {0, bounding.y + bounding.height}},
      attrs: %{color: "#000000", thickness: -15.5, source_tip: true, target_tip: false}
    }

    [bounds, x_axis, y_axis | Enum.reverse(shapes)]
  end

  defp encode_shape(%{pos: {x, y, w, h}, attrs: attrs}) do
    record(
      [0, x, y, w],
      [h, Map.get(attrs, :height, 50.0), Map.get(attrs, :radius, 0.0), 0],
      attrs.color
    )
  end

  defp encode_shape(%{pos: {x, y}, attrs: attrs}) when is_number(x) do
    radius = Map.get(attrs, :radius, 1.0)
    record([1, x, y, radius], [Map.get(attrs, :height, radius * 2.0), 0, 0, 0], attrs.color)
  end

  defp encode_shape(%{pos: {{x1, y1}, {x2, y2}}, attrs: attrs}) do
    thickness = abs(Map.get(attrs, :thickness, 1.0))
    source_tip = if Map.get(attrs, :source_tip, thickness), do: 1.0, else: 0.0
    target_tip = if Map.get(attrs, :target_tip, thickness), do: 1.0, else: 0.0

    record(
      [2, x1, y1, x2],
      [y2, thickness * 0.5, Map.get(attrs, :height, thickness), source_tip],
      attrs.color,
      target_tip
    )
  end

  defp encode_shape(_), do: []

  defp record(texel0, texel1, color, target_tip \\ 0) do
    {r, g, b} = hex_to_rgb(color)
    [texel0 ++ texel1 ++ [r, g, b, target_tip, 0, 0, 0, 0]]
  end

  defp hex_to_rgb("#" <> hex) do
    {
      String.to_integer(binary_part(hex, 0, 2), 16) / 255,
      String.to_integer(binary_part(hex, 2, 2), 16) / 255,
      String.to_integer(binary_part(hex, 4, 2), 16) / 255
    }
  end
end
