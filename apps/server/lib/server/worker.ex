defmodule Server.Worker do
  use GenServer

  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, name: {:global, name})
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:connect, nick_name}, {from, _}, clients) do
    Logger.info("Client #{nick_name} trying to connect.")

    case Map.has_key?(clients, nick_name) do
      true ->
        {:reply, :nick_taken, clients}
      false ->
        updated_clients = Map.put(clients, nick_name, node(from))
        {:reply, {:connected, Map.keys(updated_clients)}, updated_clients}
    end
  end

  def handle_call({:disconnect, nick_name}, {from, _}, clients) do
    Logger.info("Disconnecting #{nick_name}.")

    case Map.has_key?(clients, nick_name) &&
    node(from) == Map.get(clients, nick_name) do
      true ->
        {:reply, :disconnected, Map.delete(clients, nick_name)}
      false ->
        {:reply, :not_connected, clients}
    end
  end

  def handle_call(:list_connected, _, clients) do
    {:reply, Map.keys(clients), clients}
  end

  def handle_cast({:send_message, nick_name, message}, clients) do
    Logger.info("#{nick_name} is broadcasting a message.")

    broadcast(Map.delete(clients, nick_name), nick_name, message)
    {:noreply, clients}
  end

  def handle_cast({:send_private_message, nick, to_nick, message}, clients) do
    Logger.info("#{nick} is sending private message to #{to_nick}")

    send_message(Map.get(clients, to_nick), nick, message)
    {:noreply, clients}
  end

  defp broadcast(clients, from, message) do
    Enum.map(clients, fn {_, registered_node} ->
      Task.async(fn ->
        send_message(registered_node, from, message)
      end)
    end) |> Enum.map(&Task.await/1)
  end

  defp send_message(registered_node, from, message) do
    GenServer.cast({:enchatter_client, registered_node}, {:new_message, from, message})
  end
end
