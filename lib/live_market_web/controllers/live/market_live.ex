defmodule LiveMarketWeb.MarketLive do
  use LiveMarketWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    default_symbol = "BINANCE:BTCUSDT"

    if connected?(socket) do
      :timer.send_interval(1000, self(), :flush)
      Phoenix.PubSub.subscribe(LiveMarket.PubSub, "finnhub:stream")
      LiveMarket.FinnhubSocket.subscribe(default_symbol)
    end

    {:ok,
     assign(socket,
       current_symbol: default_symbol,
       price_series: [],
       trades: [],
       volume_series: [],
       last_price: nil
     )}
  end

  @impl true
  def handle_info({:finnhub_msg, raw}, socket) do
    case Jason.decode(raw) do
      {:ok, %{"type" => "ping"}} ->
        {:noreply, socket}

      {:ok, %{"data" => ticks}} when is_list(ticks) ->
        socket =
          Enum.reduce(ticks, socket, fn t, acc ->
            process_tick(acc, t)
          end)

        {:noreply, socket}

      {:ok, %{"type" => type}} ->
        IO.inspect(type, label: "Unhandled type")
        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to decode Finnhub Message")

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:flush, socket) do
    IO.inspect(
      %{
        last_price: socket.assigns.last_price,
        price_series_len: length(socket.assigns.price_series),
        volume_series_len: length(socket.assigns.volume_series)
      },
      label: "FLUSH ASSIGNS"
    )

    socket =
      socket
      |> push_event("price_update", %{prices: socket.assigns.price_series})
      |> push_event("volume_update", %{volumes: socket.assigns.volume_series})
      |> push_event("spark_update", %{prices: socket.assigns.price_series})

    {:noreply, socket}
  end

  @impl true
  def handle_event("subscribe", %{"symbol" => symbol}, socket) do
    previous_symbol = socket.assigns.current_symbol

    if previous_symbol != symbol do
      LiveMarket.FinnhubSocket.unsubscribe(previous_symbol)
      LiveMarket.FinnhubSocket.subscribe(symbol)
    end

    {:noreply,
     assign(socket,
       current_symbol: symbol,
       price_series: [],
       volume_series: [],
       trades: [],
       last_price: nil
     )}
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
