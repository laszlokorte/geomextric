defmodule Geomextric.Canvas do
  use GenServer
  @topic "canvas"

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def put(server, x, y) do
    GenServer.cast(server, {:put, UUID.uuid4(), {x, y}})
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

  def get_all(server) do
    GenServer.call(server, :get_all)
  end

  ## Server callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:put, id, {x, y} = coords}, state) do
    {:noreply, Map.put(state, id, coords), {:continue, {:broadcast_insert, id, coords}}}
  end

  @impl true
  def handle_cast({:move, id, {x, y} = coords}, state) do
    {:noreply, Map.replace(state, id, {x, y}), {:continue, {:broadcast_move, id, coords}}}
  end

  @impl true
  def handle_cast({:delete, id}, state) do
    {:noreply, Map.delete(state, id), {:continue, {:broadcast_delete, id}}}
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
  def handle_continue({:broadcast_insert, id, coords}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:inserted, id, coords}
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
end
