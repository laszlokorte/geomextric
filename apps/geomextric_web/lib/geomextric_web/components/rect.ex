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
  attr :prefix, :string, default: "rect", doc: "id"
  attr :handles, :boolean, default: false

  def rect(assigns) do
    ~H"""
    <g id={"g-#{@prefix}-#{@id}"} overflow="visible">
      <.dragger x={@x} y={@y} id={@id} prefix={@prefix} color={@fill} show_handle={@handles}>
        <rect
          :if={not @handles}
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
            multi-drag={@handles}
            stroke-width={if(@handles, do: 10, else: 2)}
            data-non-zoom-stroke="yes"
            stroke-linecap="square"
          />
        </:handle>
        <:pin :for={{x, y} <- for x <- [0, 0.5, 1], y <- [0, 0.5, 1], do: {x, y}} :if={@handles}>
          <circle data-non-scaling cx={@x + x * @width} cy={@y + y * @height} r="5" />
        </:pin>
      </.dragger>
    </g>
    """
  end
end
