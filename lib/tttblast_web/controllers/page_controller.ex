defmodule TttblastWeb.PageController do
  use TttblastWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
