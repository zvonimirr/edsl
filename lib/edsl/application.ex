defmodule Edsl.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # EDSL Runtime GenServer
      Edsl.Runtime
    ]

    opts = [strategy: :one_for_one, name: Edsl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
