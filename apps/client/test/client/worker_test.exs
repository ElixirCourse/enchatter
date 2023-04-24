defmodule Client.WorkerTest do
  use ExUnit.Case
  doctest Client.Worker

  alias Client.Worker

  describe "start_link" do
    test "starts the client process" do
      {:ok, pid} = Worker.start_link(nick: "meddle", name: :name)

      assert Process.alive?(pid)
    end

    test "registers the passed name" do
      {:ok, pid} = Worker.start_link(nick: "valo", name: :name)

      assert Process.whereis(:name) == pid
    end
  end

  defmodule TestServer do
    use GenServer

    @server_name Application.compile_env(:client, :server_name, :test_enchatter_server)

    def init(state), do: {:ok, state}

    def server_name, do: @server_name

    def start_link do
      state = %{clients: [], messages: []}
      IO.inspect(@server_name, label: "SERVER NAME")
      GenServer.start_link(__MODULE__, state, name: {:global, server_name()})
    end

    def handle_call({:connect, nick}, _, state) do
      new_state = %{state | clients: [nick | state[:clients]]}
      {:reply, {:connected, new_state}, new_state}
    end

    def handle_call({:disconnect, nick}, _, state) do
      new_state = %{state | clients: List.delete(state[:clients], nick)}
      {:reply, :disconnected, new_state}
    end

    def handle_call(:list_connected, _, state) do
      {:reply, state[:clients], state}
    end

    def handle_cast({:send_message, nick, message}, state) do
      {:noreply, %{state | messages: [{nick, :all, message} |state[:messages]]}}
    end

    def handle_cast({:send_private_message, nick, to, message}, state) do
      {:noreply, %{state | messages: [{nick, to, message} |state[:messages]]}}
    end
  end

  setup do
    {:ok, _} = TestServer.start_link()
    true = is_pid(:global.whereis_name(:test_enchatter_server))

    {:ok, _} = Worker.start_link(nick: "valo", name: :valo_test_client)
    {:ok, _} = Worker.start_link(nick: "slavi", name: :slavi_test_client)
    {:ok, _} = Worker.start_link(nick: "meddle", name: :meddle_test_client)
    :ok
  end

  describe "init" do
    test "sets the state to map, containing the nick passed to start_link" do
      state = :sys.get_state(Process.whereis(:slavi_test_client))

      assert state[:nick] == "slavi"
    end

    test "sets the state to map, containing connection_ref set to nil" do
      state = :sys.get_state(Process.whereis(:slavi_test_client))

      assert state[:connection_ref] == nil
    end
  end

  describe "handle_call(:connect, ...)" do
    test """
    connects to the server via GenServer.call(<server>, {:connect, nick})
    """ do
      {:connected, state} = GenServer.call(:valo_test_client, :connect)

      assert state[:clients] == ["valo"]
    end

    test """
    starts monitoring the server process and sets the connection_ref in the
    state to the monitoring reference
    """ do
      GenServer.call(:valo_test_client, :connect)
      state = :sys.get_state(Process.whereis(:valo_test_client))

      assert not is_nil(state[:connection_ref])
    end

    test "if the server can't be connected, the state is not changed" do
      Process.flag(:trap_exit, true)
      Process.exit(:global.whereis_name(TestServer.server_name()), :kill)

      :server_unreachable = GenServer.call(:valo_test_client, :connect)

      state = :sys.get_state(Process.whereis(:valo_test_client))

      assert is_nil(state[:connection_ref])
    end
  end

  describe "handle_call(:disconnect, ...)" do
    setup do
      {:connected, _} = GenServer.call(:slavi_test_client, :connect)
      :ok
    end

    test """
    disconnects the client by calling
    GenServer.call(<server>, {:disconnect, nick})
    """ do
      :disconnected = GenServer.call(:slavi_test_client, :disconnect)
      state = :sys.get_state(:global.whereis_name(TestServer.server_name()))

      assert state[:clients] == []
    end

    test """
    removes the monitor to the server process stored in the state
    under the :connection_ref key
    """ do
      :disconnected = GenServer.call(:slavi_test_client, :disconnect)
      state = :sys.get_state(Process.whereis(:slavi_test_client))

      assert is_nil(state[:connection_ref])
    end
  end

  describe "handle_call(:list_users, ...)" do
    setup do
      {:connected, _} = GenServer.call(:slavi_test_client, :connect)
      {:connected, _} = GenServer.call(:meddle_test_client, :connect)
      {:connected, _} = GenServer.call(:valo_test_client, :connect)
      :ok
    end

    test """
    returns a list of the connected users using GenServer.call(<server>, :list_connected)
    """ do
      connected = GenServer.call(:meddle_test_client, :list_users)

      assert connected == ~w(valo meddle slavi)
    end
  end

  describe "handle_call({:send_message, <message>}, ...)" do
    setup do
      {:connected, _} = GenServer.call(:slavi_test_client, :connect)
      {:connected, _} = GenServer.call(:meddle_test_client, :connect)
      {:connected, _} = GenServer.call(:valo_test_client, :connect)
      :ok
    end

    test """
    sends message to all the users via GenServer.cast(<server>, {:send_message, nick, message})
    """ do
      GenServer.cast(:valo_test_client, {:send_message, "Hey!"})
      :sys.get_state(Process.whereis(:valo_test_client))

      %{messages: messages} =
        :sys.get_state(:global.whereis_name(TestServer.server_name()))

        assert messages == [{"valo", :all, "Hey!"}]
    end
  end

  describe "handle_call({:send_private_message, <to>, <message>}, ...)" do
    setup do
      {:connected, _} = GenServer.call(:slavi_test_client, :connect)
      {:connected, _} = GenServer.call(:meddle_test_client, :connect)
      {:connected, _} = GenServer.call(:valo_test_client, :connect)
      :ok
    end

    test """
    sends private message to the specified user via
    GenServer.cast(<server>, {:send_private_message, nick, to_nick, message})
    """ do
      GenServer.cast(:slavi_test_client, {:send_private_message, "valo", "YO"})
      :sys.get_state(Process.whereis(:slavi_test_client))

      %{messages: messages} =
        :sys.get_state(:global.whereis_name(TestServer.server_name()))

        assert messages == [{"slavi", "valo", "YO"}]
    end
  end

  describe "reconnecting behaviour" do
    setup do
      {:connected, _} = GenServer.call(:slavi_test_client, :connect)
      {:connected, _} = GenServer.call(:meddle_test_client, :connect)
      {:connected, _} = GenServer.call(:valo_test_client, :connect)

      Process.flag(:trap_exit, true)

      server_pid = :global.whereis_name(TestServer.server_name())
      Process.exit(server_pid, :kill)
      :ok
    end

    test "when the server process goes down, the client tries to reconnect" do
      {:ok, _} = TestServer.start_link()
      Process.sleep(1000)

      connected = GenServer.call(:meddle_test_client, :list_users)
      assert Enum.member?(connected, "meddle")
      assert Enum.member?(connected, "slavi")
      assert Enum.member?(connected, "valo")
    end
  end
end
