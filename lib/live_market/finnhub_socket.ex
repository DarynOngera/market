defmodule LiveMarket.FinnhubSocket do
  use WebSockex
  require Logger

  @url"wss://ws.finnhub.io?token=d61e601r01quq5pfvdlgd61e601r01quq5pfvdm0"

  def start_link(_) do
    WebSockex.start_link(@url, __MODULE__, %{},name: __MODULE__)
  end

  def subscribe(symbol) do
    send_frame(%{type: "subscribe", symbol: symbol})
  end

  def unsubscribe(symbol) do
    send_frame(%{type: "unsubscribe", symbol: symbol})
  end

  def handle_frame({:text, msg}, state) do
    Logger.debug("WS message: #{msg}")

    Phoenix.PubSub.broadcast(
      LiveMarket.PubSub,
      "finnhub:stream",
      {:finnhub_msg, msg}
    )

    {:ok, state}
  end 

  def handle_disconnect(reason, state) do
    Logger.error("Finnhub WS was disconected: #{inspect(reason)}")

    {:reconnect, state}
  end

  defp send_frame(payload) do
    WebSockex.send_frame(
      __MODULE__,
      {:text, Jason.encode!(payload)}
    )
  end
end
