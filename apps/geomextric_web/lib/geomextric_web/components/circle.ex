defmodule GeomextricWeb.Circle do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext
  import GeomextricWeb.Dragger

  attr :x, :float, default: 0.0, doc: "center x"
  attr :y, :float, default: 0.0, doc: "center y"
  attr :r, :float, default: 0.0, doc: "radius"
  attr :fill, :string, default: "red", doc: "fill color"
  attr :id, :string, default: "circle", doc: "id"
  attr :selection, :list, default: []

  def circle(assigns) do
    ~H"""
    <.dragger selection={@selection} x={@x} y={@y} id={@id} color={@fill}>
      <circle
        shape-rendering="geometricPrecision"
        cx={@x}
        cy={@y}
        r={@r}
        fill={@fill}
      >
      </circle>
      <:handle>
        <circle
          shape-rendering="geometricPrecision"
          cx={@x}
          cy={@y}
          r={@r}
          fill-opacity="0.3"
          stroke={@fill}
          fill={@fill}
          stroke-width={2}
          data-non-zoom-stroke="yes"
          stroke-opacity="0.3"
          stroke-linecap="square"
        />
      </:handle>

      <:pin>
        <circle data-non-scaling cx={@x} cy={@y} r="5" />
      </:pin>
    </.dragger>
    """
  end
end
