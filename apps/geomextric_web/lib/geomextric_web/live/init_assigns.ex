defmodule GeomextricWeb.InitAssigns do
  @moduledoc """
  Ensures common `assigns` are applied to all LiveViews attaching this hook.
  """
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :page_title, "Hello")}
  end

  def on_mount(:user, _params, _session, _socket) do
    # code
  end

  def on_mount(:admin, _params, _session, socket) do
    {:cont, socket, layout: {DemoWeb.Layouts, :admin}}
  end
end
