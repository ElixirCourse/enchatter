defmodule Client do
  use Application

  alias Client.Connectivity

  def start(_type, [server_location]) do
    with nick when not is_nil(nick) <- Connectivity.nick(),
    true <- Connectivity.connect_to_server_node(server_location) do
      start_client(nick)
    else
      _ -> {:error, "Can't connect to server or establish client."}
    end
  end

  def connect do
    GenServer.call(:enchatter_client, :connect)
  end

  def disconnect do
    GenServer.call(:enchatter_client, :disconnect)
  end

  def enchatters do
    list = GenServer.call(:enchatter_client, :list_users)

    IO.puts("Enchatters online:")
    IO.puts(IO.ANSI.green())
    list |> Enum.each(&IO.puts/1)
    IO.puts(IO.ANSI.reset())
  end

  def shout(message) do
    GenServer.cast(:enchatter_client, {:send_message, message})
  end

  def whisper(to, message) do
    GenServer.cast(:enchatter_client, {:send_private_message, to, message})
  end

  defp start_client(nick) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Client.Worker, [nick, :enchatter_client])
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
