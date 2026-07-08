defmodule GeomextricWeb.Line do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext
  import GeomextricWeb.Dragger

  attr :x1, :float, default: 0.0, doc: "x1"
  attr :y1, :float, default: 0.0, doc: "y1"
  attr :x2, :float, default: 0.0, doc: "x2"
  attr :y2, :float, default: 0.0, doc: "y2"
  attr :source_tip, :boolean, default: false
  attr :target_tip, :boolean, default: false
  attr :stroke, :string, default: "blue", doc: "stroke color"
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
      <path
        :if={@target_tip}
        fill={@stroke}
        transform={"rotate(#{:math.atan2(@y1 - @y2, @x1 - @x2) / :math.pi() * 180} #{@x2} #{@y2}) translate(#{-@stroke_width*2}, 0)"}
        d={"M #{@x2} #{@y2} l #{2*@stroke_width} #{1.5*@stroke_width} v #{-3*@stroke_width} z"}
      />

      <path
        :if={@source_tip}
        fill={@stroke}
        transform={"rotate(#{:math.atan2(@y2 - @y1, @x2 - @x1) / :math.pi() * 180} #{@x1} #{@y1}) translate(#{-@stroke_width*2}, 0)"}
        d={"M #{@x1} #{@y1} l #{2*@stroke_width} #{1.5*@stroke_width} v #{-3*@stroke_width} z"}
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
          stroke-width={@stroke_width}
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

        <path
          :if={@source_tip}
          fill={@stroke}
          stroke={@stroke}
          stroke-width={@stroke_width}
          transform={"rotate(#{:math.atan2(@y2 - @y1, @x2 - @x1) / :math.pi() * 180} #{@x1} #{@y1}) translate(#{-@stroke_width*2}, 0)"}
          d={"M #{@x1} #{@y1} l #{2*@stroke_width} #{1.5*@stroke_width} v #{-3*@stroke_width} z"}
        />

        <path
          :if={@target_tip}
          fill={@stroke}
          stroke={@stroke}
          stroke-width={@stroke_width}
          transform={"rotate(#{:math.atan2(@y1 - @y2, @x1 - @x2) / :math.pi() * 180} #{@x2} #{@y2}) translate(#{-@stroke_width*2}, 0)"}
          d={"M #{@x2} #{@y2} l #{2*@stroke_width} #{1.5*@stroke_width} v #{-3*@stroke_width} z"}
        />
      </:handle>
    </.dragger>
    """
  end
end
