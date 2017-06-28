defmodule Server.ConnectivityTest do
  use ExUnit.Case
  doctest Server.Worker

  describe "try_make_accessible" do
    test "returns {:ok true} if the node is alive" do
      {:ok, _pid} = Node.start(:very_testing_server@localhost)

      assert Server.Connectivity.try_make_accessible() == {:ok, true}

      Node.stop()
    end

    test "it starts the Node if it is not started using system vars" do
      System.put_env("ENCHATTER_SEVER_NAME", "very_very_testing_server")
      System.put_env("ENCHATTER_SEVER_LOCATION", "localhost")

      assert Node.alive? == false

      {:ok, _pid} = Server.Connectivity.try_make_accessible()

      assert Node.alive? == true
      assert Node.self() == :very_very_testing_server@localhost

      Node.stop()
    end

    test "returns {:error, reason} if it could't start the node" do
      System.put_env("ENCHATTER_SEVER_NAME", "does_not_matter")
      System.put_env("ENCHATTER_SEVER_LOCATION", "stuff@@")

      assert Node.alive? == false

      {:error, _reason} = Server.Connectivity.try_make_accessible()

      assert Node.alive? == false
    end
  end
end
