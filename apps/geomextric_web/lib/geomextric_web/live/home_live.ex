defmodule GeomextricWeb.HomeLive do
  use GeomextricWeb, :live_view

  def mount(%{}, _, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
        .full {
        display: grid;
        position: absolute;
        inset: 0;
        grid-template-rows: auto;
        grid-auto-rows: 1fr;
        grid-template-columns: 1fr 1fr;

        gap: 1em;
        padding: 1em;
        }
        h1 {
        text-align: center;
        font-size: 1.5em;
        grid-column: 1 / -1;
        }

        .split {
        display: grid;
        grid-template-columns: subgrid;
        grid-column: 1 / -1;
        align-items: stretch;
        justify-items: stretch;
        text-align: center;
        }

        .enter-link {
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 10vmin;
          opacity: 0.8;
          transition: opacity 50ms linear;
        }
        .enter-link:hover, .enter-link:focus {
          opacity: 1;
        }
        .left {
        background: royalblue;
      }
      .right {
      background: tomato;
      }
    </style>
    <div class="full">
      <h1>LiveView Canvas Experiment</h1>
      <div class="split">
        <.link navigate={~p"/canvas"} class="left enter-link">
          2D
        </.link>
        <.link navigate={~p"/scene"} class="right enter-link">
          3D
        </.link>
      </div>
    </div>
    """
  end
end
