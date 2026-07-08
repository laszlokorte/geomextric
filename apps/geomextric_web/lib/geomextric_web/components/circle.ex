defmodule GeomextricWeb.Circle do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext
  import GeomextricWeb.Dragger

  attr :x, :float, default: 0.0, doc: "center x"
  attr :y, :float, default: 0.0, doc: "center y"
  attr :r, :float, default: 0.0, doc: "radius"
  attr :fill, :string, default: "red", doc: "fill color"
  attr :id, :string, default: "circle", doc: "id"
  attr :prefix, :string, default: "circle", doc: "id"
  attr :handles, :boolean, default: false

  def circle(assigns) do
    ~H"""
    <.dragger x={@x} y={@y} id={@id} prefix={@prefix} color={@fill} show_handle={@handles}>
      <circle
        :if={not @handles}
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
          stroke-width={if(@handles, do: 10, else: 2)}
          multi-drag={@handles}
          data-non-zoom-stroke="yes"
          stroke-opacity="0.3"
          stroke-linecap="square"
        />
      </:handle>

      <:pin :if={@handles}>
        <circle data-non-scaling cx={@x} cy={@y} r="5" />
      </:pin>
    </.dragger>
    """
  end
end
