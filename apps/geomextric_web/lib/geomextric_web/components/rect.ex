defmodule GeomextricWeb.Rectangle do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  import GeomextricWeb.Dragger

  attr :x, :float, default: 0.0, doc: "x"
  attr :y, :float, default: 0.0, doc: "y"
  attr :rx, :float, default: 0.0, doc: "rx"
  attr :ry, :float, default: 0.0, doc: "ry"
  attr :width, :float, default: 0.0, doc: "width"
  attr :height, :float, default: 0.0, doc: "height"
  attr :fill, :string, default: "red", doc: "fill color"
  attr :id, :string, default: "rect", doc: "id"
  attr :selection, :list, default: []

  def rect(assigns) do
    ~H"""
    <g id={"g-#{@id}"} overflow="visible">
      <.dragger selection={@selection} x={@x} y={@y} id={@id} color={@fill}>
        <rect
          shape-rendering="geometricPrecision"
          x={@x}
          y={@y}
          rx={@rx}
          ry={@ry}
          width={@width}
          height={@height}
          fill={@fill}
        >
        </rect>
        <:handle>
          <rect
            shape-rendering="geometricPrecision"
            x={@x}
            y={@y}
            rx={@rx}
            ry={@ry}
            width={@width}
            height={@height}
            fill={@fill}
            opacity="1"
            fill-opacity="0.3"
            fill-opacity="0.5"
            stroke={@fill}
            stroke-width={2}
            data-non-zoom-stroke="yes"
            stroke-linecap="square"
          />
        </:handle>
        <:pin :for={{x, y} <- for x <- [0, 0.5, 1], y <- [0, 0.5, 1], do: {x, y}}>
          <circle data-non-scaling cx={@x + x * @width} cy={@y + y * @height} r="5" />
        </:pin>
      </.dragger>
    </g>
    """
  end
end
