defmodule Geomextric.Canvas do
  use GenServer
  @topic "canvas"

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def put(server, x, y, params = %{} \\ %{}) do
    GenServer.cast(server, {:put, UUID.uuid4(), {x, y}, params})
  end

  def put(server, x, y, width, height, params = %{} \\ %{}) do
    GenServer.cast(server, {:put, UUID.uuid4(), {x, y, width, height}, params})
  end

  def clear(server) do
    GenServer.cast(server, :clear)
  end

  def move(server, id, x, y) do
    GenServer.cast(server, {:move, id, {x, y}})
  end

  def delete(server, id) do
    GenServer.cast(server, {:delete, id})
  end

  def delete_box(server, box) do
    GenServer.cast(server, {:delete_box, box})
  end

  def get_all(server) do
    GenServer.call(server, :get_all)
  end

  def get_box(server) do
    GenServer.call(server, :get_box)
  end

  ## Server callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:put, id, {_x, _y} = coords, attrs}, state) do
    new = %{
      pos: coords,
      attrs: %{
        color: Map.get(attrs, "color", "rebeccapurple"),
        radius: Map.get(attrs, "radius", 10)
      }
    }

    {:noreply, Map.put(state, id, new), {:continue, {:broadcast_insert, id, new}}}
  end

  @impl true
  def handle_cast({:put, id, {_x, _y, _width, _height} = coords, attrs}, state) do
    new = %{
      pos: coords,
      attrs: %{
        color: Map.get(attrs, "color", "rebeccapurple"),
        radius: Map.get(attrs, "radius", 0)
      }
    }

    {:noreply, Map.put(state, id, new), {:continue, {:broadcast_insert, id, new}}}
  end

  @impl true
  def handle_cast({:move, id, {x, y} = coords}, state) do
    case state do
      %{^id => old = %{pos: {_old_x, _old_y}}} ->
        {:noreply, %{state | id => %{old | pos: coords}},
         {:continue, {:broadcast_move, id, coords}}}

      %{^id => old = %{pos: {_old_x, _old_y, old_w, old_h}}} ->
        {:noreply, %{state | id => %{old | pos: {x, y, old_w, old_h}}},
         {:continue, {:broadcast_move, id, {x, y, old_w, old_h}}}}

      %{} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:delete, id}, state) do
    {:noreply, Map.delete(state, id), {:continue, {:broadcast_delete, id}}}
  end

  @impl true
  def handle_cast({:delete_box, %{width: bw, height: bh, x: bx, y: by}}, state) do
    {:noreply,
     state
     |> Enum.filter(fn
       {_, %{pos: {x, y}}} -> x < bx || x > bx + bw || y < by || y > by + bh
       {_, %{pos: {x, y, w, h}}} -> x < bx || x + w > bx + bw || y < by || y + h > by + bh
       _ -> true
     end)
     |> Map.new(), {:continue, :broadcast_reload}}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, Map.new(), {:continue, :broadcast_clear}}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_box, _from, state) do
    minX =
      state
      |> Enum.map(fn
        {_, %{pos: {x, _}}} -> x
        {_, %{pos: {x, _, _w, _h}}} -> x
      end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    minY =
      state
      |> Enum.map(fn
        {_, %{pos: {_, y}}} -> y
        {_, %{pos: {_, y, _w, _h}}} -> y
      end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    maxX =
      state
      |> Enum.map(fn
        {_, %{pos: {x, _}}} -> x
        {_, %{pos: {x, _, w, _h}}} -> x + w
      end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    maxY =
      state
      |> Enum.map(fn
        {_, %{pos: {_, y}}} -> y
        {_, %{pos: {_, y, _w, h}}} -> y + h
      end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    {:reply,
     %{
       x: minX,
       y: minY,
       width: maxX - minX,
       height: maxY - minY
     }, state}
  end

  @impl true
  def handle_continue({:broadcast_insert, id, new}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:inserted, id, new}
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue({:broadcast_move, id, coords}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:moved, id, coords}
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue(:broadcast_clear, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      :clear
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue({:broadcast_delete, id}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:delete, id}
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue(:broadcast_reload, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      :reload
    )

    {:noreply, state}
  end
end
