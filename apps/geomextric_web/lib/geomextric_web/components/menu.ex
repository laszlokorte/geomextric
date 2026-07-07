defmodule GeomextricWeb.Menu do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :items, :list, default: [], doc: "items"

  def menu(assigns) do
    ~H"""
    <style rel="stylesheet" :type={GeomextricWeb.ColocatedScopedCSS}>
      .menu {
      margin: 0;
      padding: 0;
      }
      .submenu{

      margin: 1px;
        display: none;
      }

      .menu-button:hover + .popup {
        display: flex;
        flex-direction: column;
      }

      .m:scope {
        display: flex;
        margin: 0;
        gap: 0;
        flex-direction: row;
        background: #f0f0f0;
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
       padding-left: 1em;
       padding-right: 2em;
       text-align: left;
       display: block;
       border-radius: 0;
       background: #f0f0f0;
       color: #000;
       position: relative;
       cursor: pointer;
       }
       button:hover {
       background: #eee;
       }

       .submenu button {
         interest-delay: 0s 0s;
       }

       .menu > button {
         interest-delay: 10000s 0s;
       }

       .m:has(:popover-open) .menu > button {
         interest-delay: 0s 1000s;
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
              <button
                phx-click={Map.get(sub, :send)}
                popovertarget={"menu-#{idx}-#{sdx}"}
                interestfor={"menu-#{idx}-#{sdx}"}
                style={"anchor-name: --menu-#{idx}-#{sdx}"}
              >
                {sub.label}

                {if(Map.get(sub, :items, []) |> Enum.empty?(), do: "", else: "▶")}
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
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
