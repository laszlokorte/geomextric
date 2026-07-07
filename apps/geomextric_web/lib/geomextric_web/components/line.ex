defmodule GeomextricWeb.Line do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext
  import GeomextricWeb.Dragger

  attr :x1, :float, default: 0.0, doc: "x1"
  attr :y1, :float, default: 0.0, doc: "y1"
  attr :x2, :float, default: 0.0, doc: "x2"
  attr :y2, :float, default: 0.0, doc: "y2"
  attr :stroke, :string, default: "red", doc: "stroke color"
  attr :stroke_width, :float, default: 1.0, doc: "stroke width"
  attr :id, :string, default: "line", doc: "id"

  def line(assigns) do
    ~H"""
    <.dragger x={@x1} y={@y1} id={@id}>
      <line
        shape-rendering="geometricPrecision"
        x1={@x1}
        y1={@y1}
        x2={@x2}
        y2={@y2}
        stroke={@stroke}
        stroke-width={@stroke_width}
        stroke-linecap="round"
      />
      <:handle>
        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke={@stroke}
          stroke-width={@stroke_width * 1.5}
          stroke-linecap="round"
        />
        <line
          tabindex="-1"
          shape-rendering="geometricPrecision"
          x1={@x1}
          y1={@y1}
          x2={@x2}
          y2={@y2}
          stroke-width={10}
          stroke={@stroke}
          vector-effect="non-scaling-stroke"
          stroke-linecap="round"
        />
      </:handle>
    </.dragger>
    """
  end
end
