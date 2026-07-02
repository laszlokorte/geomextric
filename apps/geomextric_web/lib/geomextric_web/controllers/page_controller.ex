defmodule GeomextricWeb.PageController do
  use GeomextricWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
