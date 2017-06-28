defmodule Client.Connectivity do
  def nick do
    case Node.alive? do
      true ->
        to_string(Node.self()) |> String.split("@") |> List.first
      false ->
        try_make_online_and_get_nick()
    end
  end

  def connect_to_server_node(server_location) do
    server_name = System.get_env("ENCHATTER_SERVER_NAME") || "server"

    Node.connect(:"#{server_name}@#{server_location}") ||
    Node.connect(:"#{server_name}_slave_one@#{server_location}") ||
    Node.connect(:"#{server_name}_slave_two@#{server_location}")
  end

  defp try_make_online_and_get_nick do
    nick = System.get_env("ENCHATTER_NICK") || random_nick()
    location = System.get_env("ENCHATTER_CLIENT_LOCATION") || "127.0.0.1"

    case Node.start(:"#{nick}@#{location}") do
      {:ok, pid} when is_pid(pid) -> nick
      _ -> nil
    end
  end

  defp random_nick do
    letters = ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)

    (1..10)
    |> Enum.reduce([], fn(_, acc) -> [Enum.random(letters) | acc] end)
    |> Enum.join("")
  end
end
