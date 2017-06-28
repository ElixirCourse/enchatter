defmodule Server.WorkerTest do
  use ExUnit.Case
  doctest Server.Worker

  describe "start_link" do
    test "starts the server process" do
      {:ok, pid} = Server.Worker.start_link("name")

      assert Process.alive?(pid)
    end

    test "registers the passed name globally" do
      {:ok, _} = Server.Worker.start_link("name")

      assert Process.alive?(:global.whereis_name("name"))
    end
  end

  setup do
    {:ok, _} = Server.Worker.start_link(:test_server)
    :ok
  end

  describe "handle_call({:connect, nick_name}, ..)" do
    test "returns {:connected, [list_of_connected_nicks]} on success" do
      reply = GenServer.call({:global, :test_server}, {:connect, "meddle"})

      assert reply == {:connected, ["meddle"]}
    end

    test "returns :nick_taken if the nick is already taken" do
      GenServer.call({:global, :test_server}, {:connect, "meddle"})
      reply = GenServer.call({:global, :test_server}, {:connect, "meddle"})

      assert reply == :nick_taken
    end
  end

  describe "handle_call({:disconnect, nick_name}, ..)" do
    test "returns :disconnected if the client is successfully disconnected" do
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "meddle"})
      reply = GenServer.call({:global, :test_server}, {:disconnect, "meddle"})

      assert reply == :disconnected
    end

    test "returns {:not_connected} if the client is not connected" do
      reply = GenServer.call({:global, :test_server}, {:disconnect, "meddle"})

      assert reply == :not_connected
    end
  end

  describe "handle_call(:list_connected, ..)" do
    test "returns a list of the connected clients" do
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "meddle"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "valo"})
      reply = GenServer.call({:global, :test_server}, :list_connected)

      assert reply == ~w(meddle valo)
    end
  end

  defmodule TestClient do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, nil, name: :enchatter_client)
    end

    def init(_), do: {:ok, []}

    def handle_cast({:new_message, from, message}, state) do
      {:noreply, [{from, message} | state]}
    end

    def handle_call(:get, _, state), do: {:reply, state, state}
  end

  describe "handle_cast({:send_message, nick_name, message}, ..)" do
    setup do
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "meddle"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "valo"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "slavi"})
      :ok
    end

    test """
    broadcasts the message to all the connected clients except the sender
    """ do
      TestClient.start_link()
      GenServer.cast({:global, :test_server}, {:send_message, "meddle", "YO!"})

      :sys.get_state(:global.whereis_name(:test_server))

      received = GenServer.call(:enchatter_client, :get)
      assert [{"meddle", "YO!"}, {"meddle", "YO!"}] == received
    end
  end

  describe "handle_cast({:send_private_message, nick, to_nick, message}, ..)" do
    setup do
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "meddle"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "valo"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "slavi"})
      {:connected, _} =
        GenServer.call({:global, :test_server}, {:connect, "andi"})
      :ok
    end

    test "sends a message only to only one client" do
      TestClient.start_link()
      GenServer.cast(
        {:global, :test_server},
        {:send_private_message, "meddle", "valo", "pssst"}
      )

      :sys.get_state(:global.whereis_name(:test_server))

      received = GenServer.call(:enchatter_client, :get)
      assert [{"meddle", "pssst"}] == received
    end
  end
end
