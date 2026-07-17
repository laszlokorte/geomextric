defmodule GeomextricWeb.Menu do
  use Phoenix.Component
  use Gettext, backend: GeomextricWeb.Gettext

  attr :items, :list, default: [], doc: "items", required: false
  slot :inner_block, required: false
  slot :head, required: false

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
       button:disabled {
       color: #aaa;
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
       display: flex;
       gap: 2em;
       align-items: baseline;
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

       kbd {
       color: #aaaa;
       margin-left: auto;
       font-size: 0.8em;
       }

       .head {
        align-self: center;
        padding: 0 1ex;
        font-size: 1em;
       }
    </style>

    <style rel="stylesheet" :type={GeomextricWeb.ColocatedCSS}>
      @media(pointer: coarse) {
       .m {
         display: none;
       }
      }
    </style>

    <div class="m">
      <div class="head">
        {render_slot(@head)}
      </div>
      <div :for={{item, idx} <- @items |> Enum.with_index()} class="menu">
        <%= if Map.get(item, :items, []) |> Enum.empty? do %>
          <button
            id={"button-#{idx}"}
            data-shortcut={Map.get(item, :shortcut, []) |> Keyword.get(:key)}
            phx-hook=".Shortcut"
            disabled={not Map.get(item, :active, true)}
            phx-click={Map.get(item, :send)}
            href={Map.get(item, :link)}
            value={Map.get(item, :value)}
            style={"anchor-name: --menu-#{idx}"}
          >
            {item.label}
            <kbd>{Map.get(item, :shortcut, []) |> Keyword.get(:key)}</kbd>
          </button>
        <% else %>
          <button
            disabled={not Map.get(item, :active, true)}
            popovertarget={"menu-#{idx}"}
            interestfor={"menu-#{idx}"}
            id={"button-#{idx}"}
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
                  disabled={not Map.get(sub, :active, true)}
                  phx-click={Map.get(sub, :send)}
                  href={Map.get(sub, :link)}
                  value={Map.get(sub, :value)}
                  popovertarget={"menu-#{idx}-#{sdx}"}
                  interestfor={"menu-#{idx}-#{sdx}"}
                  popovertargetaction="show"
                  style={"anchor-name: --menu-#{idx}-#{sdx}"}
                  data-shortcut={Map.get(sub, :shortcut, []) |> Keyword.get(:key)}
                  data-shortcut-ctrl={
                    Map.get(sub, :shortcut, [])
                    |> Keyword.get(:ctrl, false)
                  }
                  data-shortcut-shift={
                    Map.get(sub, :shortcut, [])
                    |> Keyword.get(:shift, false)
                  }
                  data-shortcut-alt={
                    Map.get(sub, :shortcut, [])
                    |> Keyword.get(:alt, false)
                  }
                  id={"menu-button-#{idx}-#{sdx}"}
                  phx-hook=".Shortcut"
                >
                  {sub.label}

                  <kbd>
                    {Map.get(sub, :shortcut, [])
                    |> Keyword.get(:ctrl, false)
                    |> then(&if(&1, do: "Ctrl + "))}

                    {Map.get(sub, :shortcut, [])
                    |> Keyword.get(:shift, false)
                    |> then(&if(&1, do: "Shift + "))}

                    {Map.get(sub, :shortcut, [])
                    |> Keyword.get(:alt, false)
                    |> then(&if(&1, do: "Alt + "))}
                    {Map.get(sub, :shortcut, []) |> Keyword.get(:key, "") |> String.upcase()}
                  </kbd>
                </button>
              <% else %>
                <button
                  disabled={not Map.get(sub, :active, true)}
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
                      phx-click={Map.get(subsub, :send)}
                      href={Map.get(subsub, :link)}
                      value={Map.get(subsub, :value)}
                      disabled={not Map.get(subsub, :active, true)}
                      popovertarget={"menu-#{idx}-#{sdx}-#{ssdx}"}
                      interestfor={"menu-#{idx}-#{sdx}-#{ssdx}"}
                      data-shortcut={Map.get(subsub, :shortcut, []) |> Keyword.get(:key)}
                      data-shortcut-ctrl={
                        Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:ctrl, false)
                      }
                      data-shortcut-shift={
                        Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:shift, false)
                      }
                      data-shortcut-alt={
                        Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:alt, false)
                      }
                      id={"menu-button-#{idx}-#{sdx}-#{ssdx}"}
                      phx-hook=".Shortcut"
                    >
                      {subsub.label}
                      <kbd>
                        {Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:ctrl, false)
                        |> then(&if(&1, do: "Ctrl + "))}

                        {Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:shift, false)
                        |> then(&if(&1, do: "Shift + "))}

                        {Map.get(subsub, :shortcut, [])
                        |> Keyword.get(:alt, false)
                        |> then(&if(&1, do: "Alt + "))}

                        {Map.get(subsub, :shortcut, []) |> Keyword.get(:key, "") |> String.upcase()}
                      </kbd>
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

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Shortcut">
      function throttle(fun, delay, fallback) {
        let lastTime = 0;
        return function (...args) {
          let now = Date.now();
          if (now - lastTime >= delay) {
            fun(...args);
            lastTime = now;
          } else if (fallback) {
            fallback(...args);
          }
        };
      }
      export default {
        mounted() {
          if (this.el.hasAttribute("data-shortcut")) {
            const click = throttle(() => this.el.click(), 4);

            const shortCut = this.el.getAttribute("data-shortcut");
            const shortCutShift = this.el.hasAttribute("data-shortcut-shift");
            const shortCutCtrl = this.el.hasAttribute("data-shortcut-ctrl");
            const shortCutAlt = this.el.hasAttribute("data-shortcut-alt");
            document.addEventListener("keydown", (evt) => {
              if (
                shortCut == evt.key &&
                shortCutShift === evt.shiftKey &&
                shortCutCtrl === evt.ctrlKey &&
                shortCutAlt === evt.altKey
              ) {
                evt.preventDefault();
                click();
              }
            });
          }
        },
      };
    </script>
    """
  end
end
