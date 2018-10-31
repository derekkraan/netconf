defmodule Netconf do
  defstruct [:channel, :framing]

  @moduledoc """
  Documentation for Netconf.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Netconf.hello()
      :world

  """
  def rpc(%Netconf{channel: channel, framing: framing}, command) do
    rpc_command = "<rpc>#{command}</rpc>"
    SSHKit.SSH.Channel.send(channel, rpc_command)
    get_message(channel, framing) |> unwrap_reply
  end

  def connect(host, options \\ []) do
    {:ok, conn} = SSHKit.SSH.connect(host, options)
    initialize_netconf(conn)
  end

  def connect(host, options, function) do
    {:ok, conn} = SSHKit.SSH.connect(host, options, function)
    initialize_netconf(conn)
  end

  @hello ~s(   
      <?xml version="1.0" encoding="UTF-8"?>
        <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
          <capabilities>
            <capability>urn:ietf:params:netconf:base:1.1</capability>
          </capabilities>
        </hello>]]>]]>
    )

  def initialize_netconf(conn) do
    {:ok, channel} = SSHKit.SSH.Channel.open(conn)
    :ok = SSHKit.SSH.Channel.subsystem(channel, "netconf")
    :ok = SSHKit.SSH.Channel.send(channel, @hello)

    hello_message = get_message(channel, :eom)
    %Netconf{channel: channel, framing: framing(hello_message)}
  end

  def get_message(channel, :eom, message \\ "") do
    case SSHKit.SSH.Channel.recv(channel, 2000) do
      {:ok, {:data, _channel, 0, next_line}} ->
        if String.contains?(next_line, "]]>]]>") do
          "#{message}#{next_line}"
        else
          get_message(channel, :eom, "#{message}#{next_line}")
        end
    end
  end

  def unwrap_reply(reply) do
    String.replace(reply, ~r(</?rpc-reply[^>]*>), "")
  end

  def framing(hello_message) do
    if String.contains?(hello_message, "urn:ietf:params:netconf:base:1.1") do
      :chunked
    else
      :eom
    end
  end
end
