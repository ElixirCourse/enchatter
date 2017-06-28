defmodule Server do
  require Logger
  use Application

  def start(type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("Enchatter Server is in #{inspect(type)} mode")

    case Server.Connectivity.try_make_accessible() do
      {:ok, _} ->
        children = [
          worker(Server.Worker, [:enchatter_server])
        ]

        opts = [strategy: :one_for_one, name: Server.Supervisor]
        Supervisor.start_link(children, opts)
      anything -> {:error, anything}
    end
  end
end
