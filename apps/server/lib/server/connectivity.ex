defmodule Server.Connectivity do
  def try_make_accessible do
    case Node.alive? do
      true -> {:ok, true}
      false ->
        name = System.get_env("ENCHATTER_SEVER_NAME") || "server"
        location = System.get_env("ENCHATTER_SEVER_LOCATION") || "127.0.0.1"
        Node.start(:"#{name}@#{location}")
    end
  end
end
