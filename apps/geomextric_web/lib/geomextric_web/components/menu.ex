defmodule GeomextricWeb.Menu do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :items, :list, default: [], doc: "items", required: false
  slot :inner_block, required: false

  def menu(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedScopedCSS}>
      .menu {
      margin: 0;
      padding: 0;
      background: #fff;
      }
      .submenu{

      background: inherit;
      border: 1px solid #aaa;
      padding: 3px;
      gap: 2px;

      margin: -2px 1px 1px 1px;
        display: none;
      }

      .menu-button:hover + .popup {
        display: flex;
        flex-direction: column;
      }

      .m:scope {
      user-select: none;
        display: flex;
        margin: 0;
        gap: 0;
        flex-direction: row;
        background: #fff;
        border-bottom: 1px solid #aaa;
      }
      .submenu:popover-open {
      position: fixed;
        display: flex;
        flex-direction: column;

        inset: auto;
        top: anchor(bottom);
        position-try-fallbacks: flip-block;
        left: anchor(left);
      }

      .subsubmenu {
      border: 1px solid #aaa;

      background: inherit;

      padding: 3px;
      gap: 2px;
      margin: 1px;

      inset: auto;
      top: anchor(top);
      left: anchor(right);
      position-try-fallbacks: flip-block;
      }

      .subsubmenu:popover-open {
      position: fixed;
        display: flex;
        flex-direction: column;

      }

      .submenu::backdrop {
         background-color: #abc0;
       }
       button {
       border: none;
       padding-left: 1em;
       padding-right: 1em;
       text-align: left;
       display: block;
       border-radius: 0;
       background: #fff;
       color: #000;
       position: relative;
       cursor: pointer;
       }
       button:hover {
       background: #000;
       color: #fff;
       }

       .submenu button {
         interest-delay: 0s 0s;
       }

       .menu > button {
         interest-delay: 10000s 0s;
       }

       :scope:has(:popover-open) .menu > button {
         interest-delay: 0s 1000s;
       }

       .inner {
       margin-left: auto;
       align-self: center;
       }
       [popovertarget]:has(+:popover-open) {
        background: #000;
        color: #fff;
       }
    </style>

    <div class="m">
      <div :for={{item, idx} <- @items |> Enum.with_index()} class="menu">
        <%= if Map.get(item, :items, []) |> Enum.empty? do %>
          <button
            id={"button-#{idx}"}
            phx-click={Map.get(item, :send)}
            style={"anchor-name: --menu-#{idx}"}
          >
            {item.label}
          </button>
        <% else %>
          <button
            popovertarget={"menu-#{idx}"}
            interestfor={"menu-#{idx}"}
            id={"button-#{idx}"}
            phx-click={Map.get(item, :send)}
            style={"anchor-name: --menu-#{idx}"}
          >
            {item.label}
          </button>

          <div
            popover="hint"
            class="submenu"
            id={"menu-#{idx}"}
            style={"position-anchor: --menu-#{idx}"}
          >
            <%= for {sub, sdx} <- Map.get(item, :items, []) |> Enum.with_index() do %>
              <%= if Map.get(sub, :items, []) |> Enum.empty? do %>
                <button
                  phx-click={Map.get(sub, :send)}
                  popovertarget={"menu-#{idx}-#{sdx}"}
                  interestfor={"menu-#{idx}-#{sdx}"}
                  popovertargetaction="show"
                  style={"anchor-name: --menu-#{idx}-#{sdx}"}
                >
                  {sub.label}
                </button>
              <% else %>
                <button
                  phx-click={Map.get(sub, :send)}
                  popovertarget={"menu-#{idx}-#{sdx}"}
                  interestfor={"menu-#{idx}-#{sdx}"}
                  popovertargetaction="show"
                  style={"anchor-name: --menu-#{idx}-#{sdx}"}
                >
                  {sub.label} ▶
                </button>
                <div
                  popover="hint"
                  class="subsubmenu"
                  id={"menu-#{idx}-#{sdx}"}
                  style={"position-anchor: --menu-#{idx}-#{sdx}"}
                >
                  <%= for {subsub, ssdx} <- Map.get(sub, :items, []) |> Enum.with_index() do %>
                    <button
                      popovertarget={"menu-#{idx}-#{sdx}-#{ssdx}"}
                      interestfor={"menu-#{idx}-#{sdx}-#{ssdx}"}
                    >
                      {sub.label}
                    </button>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="inner">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
