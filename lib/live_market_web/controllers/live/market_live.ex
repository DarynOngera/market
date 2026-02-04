defmodule LiveMarketWeb.MarketLive do
  use LiveMarketWeb, :live_view
  
  @impl true 
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(500, self(), :flush)
      Phoenix.PubSub.subscribe(LiveMarket.PubSub, "finnhub:stream")

      LiveMarket.FinnhubSocket.subscribe("AAPL")
      LiveMarket.FinnhubSocket.subscribe("BINANCE:BTCUSDT")
      LiveMarket.FinnhubSocket.subscribe("IC MARKETS:1")
    end

    {:ok,
      assign(socket,
        price_series: [],
        trades: [],
        volume_series: [],
        last_price: nil
      )}

  end

  @impl true
  def handle_info({:finnhub_msg, raw}, socket) do
  {:ok, %{"data" => ticks}} = Jason.decode(raw)

  socket =
    Enum.reduce(ticks, socket, fn t, acc ->
      process_tick(acc, t)
    end)

  {:noreply, socket}
end

  def handle_info(:flush, socket) do
    socket
    |> push_event("price_update", %{prices: socket.assigns.price_series})
    |> push_event("volume_update", %{volumes: socket.assigns.volume_series})
    |> push_event("spark_update", %{prices: socket.assigns.price_series})
    

    {:noreply, socket}
  end



  @impl true 
  def handle_event("unsubscribe", %{"symbol" => symbol}, socket) do
    LiveMarket.FinnhubSocket.unsubscribe(symbol)
    {:noreply, socket }
  end

  defp process_tick(socket, %{"p" => price, "v" => vol, "t" => ts}) do
    socket
      |> assign(:last_price, price)
      |> update(:price_series, &append_price(&1, ts, price))
      |> update(:volume_series, &aggregate_volume(&1, ts, vol))
      |> update(:trades, &append_trade(&1, price, vol, ts))
  end

  defp append_price(series, ts, price) do
    series
      |> Kernel.++([%{ts: ts, price: price}])
      |> Enum.take(-200)
  end

  defp aggregate_volume(series, ts, vol) do
    bucket = div(ts, 1_000) * 1_000

    case List.last(series) do
        %{ts: ^bucket} = 
          last ->
            List.replace_at(series, -1, %{last | volume: last.volume + vol})
          _ ->
            (series ++ [%{ts: bucket, volume: vol}])
            |> Enum.take(-60)
    end
  end

  defp append_trade(trades, price, vol, ts) do
    [%{price: price, volume: vol, ts: ts} | trades]
    |> Enum.take(20)
  end

end 
