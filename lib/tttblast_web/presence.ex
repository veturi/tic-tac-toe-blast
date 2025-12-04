defmodule TttblastWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking players in game lobbies.

  Tracks player online status and ready state for the multiplayer lobby.
  """
  use Phoenix.Presence,
    otp_app: :tttblast,
    pubsub_server: Tttblast.PubSub
end
