defmodule Tttblast.Repo do
  use Ecto.Repo,
    otp_app: :tttblast,
    adapter: Ecto.Adapters.Postgres
end
