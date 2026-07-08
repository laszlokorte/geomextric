defmodule Geomextric.Canvas do
  use GenServer
  @topic "canvas"

  defstruct [:layers, :future, :past]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def put(server, x, y, params = %{}) when is_number(x) and is_number(y) do
    GenServer.cast(server, {:put, UUID.uuid4(), {x, y}, params})
  end

  def put(server, {x1, y1}, {x2, y2}, params = %{}) do
    GenServer.cast(server, {:put, UUID.uuid4(), {{x1, y1}, {x2, y2}}, params})
  end

  def put(server, x, y, width, height, params = %{} \\ %{}) do
    GenServer.cast(server, {:put, UUID.uuid4(), {x, y, width, height}, params})
  end

  def clear(server) do
    GenServer.cast(server, :clear)
  end

  def reset(server) do
    GenServer.cast(server, :reset)
  end

  def undo(server) do
    GenServer.cast(server, :undo)
  end

  def redo(server) do
    GenServer.cast(server, :redo)
  end

  def move(server, id, x, y) do
    GenServer.cast(server, {:move, id, {x, y}})
  end

  def delete(server, id) do
    GenServer.cast(server, {:delete, id})
  end

  def delete_all(server, ids) do
    GenServer.cast(server, {:delete_all, ids})
  end

  def delete_box(server, box) do
    GenServer.cast(server, {:delete_box, box})
  end

  def select_box(server, box) do
    GenServer.call(server, {:select_box, box})
  end

  def get_all(server) do
    GenServer.call(server, :get_all)
  end

  def get_history(server) do
    GenServer.call(server, :get_history)
  end

  def get_box(server) do
    GenServer.call(server, :get_box)
  end

  ## Server callbacks

  @impl true
  def init(layers) when is_list(layers) do
    {:ok, %__MODULE__{layers: layers, future: [], past: []}}
  end

  defp insert_layer(%__MODULE__{layers: layers, future: _fut, past: past}, layer) do
    %__MODULE__{layers: [layer | layers], future: [], past: [layers | past]}
  end

  defp update_layer(%__MODULE__{layers: old_layers, future: _fut, past: past}, id, attr, fun) do
    for l <- old_layers, reduce: {:ok, []} do
      :err ->
        :err

      {:ok, layers, new_value} ->
        {:ok, [l | layers], new_value}

      {:ok, layers} ->
        case l do
          %{:id => ^id} ->
            new_attr = fun.(Map.get(l, attr))
            {:ok, [%{l | attr => new_attr} | layers], new_attr}

          _ ->
            {:ok, [l | layers]}
        end
    end
    |> case do
      {:ok, new_layers, new_value} ->
        {:ok,
         %__MODULE__{layers: new_layers |> Enum.reverse(), future: [], past: [old_layers | past]},
         new_value}

      _ ->
        :err
    end
  end

  defp delete_layers(%__MODULE__{layers: layers, future: _fut, past: past}, ids) do
    %__MODULE__{
      layers: layers |> Enum.reject(&Enum.member?(ids, Map.get(&1, :id))),
      future: [],
      past: [layers | past]
    }
  end

  defp filter_layers(%__MODULE__{layers: layers, future: _fut, past: past}, fun) do
    %__MODULE__{
      layers: layers |> Enum.filter(fun),
      future: [],
      past: [layers | past]
    }
  end

  defp clear_layers(%__MODULE__{layers: layers, future: _fut, past: past}) do
    %__MODULE__{
      layers: [],
      future: [],
      past: [layers | past]
    }
  end

  @impl true
  def handle_cast({:put, id, {{x1, y1}, {x2, y2}} = coords, attrs}, state)
      when is_number(x1) and is_number(y1) and is_number(x2) and is_number(y2) do
    new = %{
      id: id,
      pos: coords,
      attrs: %{
        color: Map.get(attrs, "color", "rebeccapurple"),
        thickness: Map.get(attrs, "thickness", 1),
        source_tip: Map.get(attrs, "source_tip", false),
        target_tip: Map.get(attrs, "target_tip", false)
      }
    }

    {:noreply, insert_layer(state, new), {:continue, {:broadcast_insert, new}}}
  end

  @impl true
  def handle_cast({:put, id, {x, y} = coords, attrs}, state) when is_number(x) and is_number(y) do
    new = %{
      id: id,
      pos: coords,
      attrs: %{
        color: Map.get(attrs, "color", "rebeccapurple"),
        radius: Map.get(attrs, "radius", 10)
      }
    }

    {:noreply, insert_layer(state, new), {:continue, {:broadcast_insert, new}}}
  end

  @impl true
  def handle_cast({:put, id, {_x, _y, _width, _height} = coords, attrs}, state) do
    new = %{
      id: id,
      pos: coords,
      attrs: %{
        color: Map.get(attrs, "color", "rebeccapurple"),
        radius: Map.get(attrs, "radius", 10)
      }
    }

    {:noreply, insert_layer(state, new), {:continue, {:broadcast_insert, new}}}
  end

  @impl true
  def handle_cast({:move, id, {x, y} = coords}, state) do
    update_layer(state, id, :pos, fn
      {old_x, old_y} when is_number(old_x) and is_number(old_y) ->
        coords

      {_old_x, _old_y, old_w, old_h} ->
        {x, y, old_w, old_h}

      {{old_x1, old_y1}, {old_x2, old_y2}} ->
        {{x, y}, {x - old_x1 + old_x2, y - old_y1 + old_y2}}

      %{} ->
        nil
    end)
    |> case do
      {:ok, new_state, new_coord} ->
        {:noreply, new_state, {:continue, {:broadcast_move, id, new_coord}}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:delete, id}, state) do
    {:noreply, delete_layers(state, [id]), {:continue, {:broadcast_delete, id}}}
  end

  @impl true
  def handle_cast({:delete_all, ids}, state) do
    {:noreply, delete_layers(state, ids), {:continue, :broadcast_delete}}
  end

  @impl true
  def handle_cast(:reset, _state) do
    {:noreply, %__MODULE__{layers: [], future: [], past: []}, {:continue, :broadcast_clear}}
  end

  @impl true
  def handle_cast(:clear, state) do
    {:noreply, clear_layers(state), {:continue, :broadcast_clear}}
  end

  @impl true
  def handle_cast(:undo, %{layers: cur, future: fut, past: [prev | new_past]}) do
    {:noreply, %__MODULE__{layers: prev, future: [cur | fut], past: new_past},
     {:continue, :broadcast_undo}}
  end

  @impl true
  def handle_cast(:undo, state = %{past: []}) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:redo, %{layers: cur, past: past, future: [fut | new_fut]}) do
    {:noreply, %__MODULE__{layers: fut, past: [cur | past], future: new_fut},
     {:continue, :broadcast_redo}}
  end

  @impl true
  def handle_cast(:redo, state = %{future: []}) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_box, %{width: bw, height: bh, x: bx, y: by}}, state) do
    {:noreply,
     state
     |> filter_layers(fn
       {_, %{pos: {{x1, y1}, {x2, y2}}}} ->
         x1 < bx || x1 > bx + bw || y1 < by || y1 > by + bh ||
           x2 < bx || x2 > bx + bw || y2 < by || y2 > by + bh

       {_, %{pos: {x, y}}} ->
         x < bx || x > bx + bw || y < by || y > by + bh

       {_, %{pos: {x, y, w, h}}} ->
         x < bx || x + w > bx + bw || y < by || y + h > by + bh

       _ ->
         true
     end), {:continue, :broadcast_reload}}
  end

  @impl true
  def handle_call({:select_box, %{width: bw, height: bh, x: bx, y: by}}, _from, state) do
    {:reply,
     state.layers
     |> Enum.reject(fn
       %{pos: {{x1, y1}, {x2, y2}}} ->
         x1 < bx || x1 > bx + bw || y1 < by || y1 > by + bh ||
           x2 < bx || x2 > bx + bw || y2 < by || y2 > by + bh

       %{pos: {x, y}} ->
         x < bx || x > bx + bw || y < by || y > by + bh

       %{pos: {x, y, w, h}} ->
         x < bx || x + w > bx + bw || y < by || y + h > by + bh

       _ ->
         true
     end)
     |> Enum.map(& &1.id), state}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state.layers, state}
  end

  @impl true
  def handle_call(:get_history, _from, state = %{future: f, past: p}) do
    {:reply, {Enum.count(p), Enum.count(f)}, state}
  end

  @impl true
  def handle_call(:get_box, _from, state) do
    minX =
      state.layers
      |> Enum.map(fn
        %{pos: {{x1, _}, {x2, _}}} -> min(x1, x2)
        %{pos: {x, _}} -> x
        %{pos: {x, _, _w, _h}} -> x
      end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    minY =
      state.layers
      |> Enum.map(fn
        %{pos: {{_, y1}, {_, y2}}} -> min(y1, y2)
        %{pos: {_, y}} -> y
        %{pos: {_, y, _w, _h}} -> y
      end)
      |> Enum.min(fn -> 0 end)
      |> then(&(&1 - 500))
      |> min(-500)

    maxX =
      state.layers
      |> Enum.map(fn
        %{pos: {{x1, _}, {x2, _}}} -> max(x1, x2)
        %{pos: {x, _}} -> x
        %{pos: {x, _, w, _h}} -> x + w
      end)
      |> Enum.max(fn -> 0 end)
      |> then(&(&1 + 500))
      |> max(500)

    maxY =
      state.layers
      |> Enum.map(fn
        %{pos: {{_, y1}, {_, y2}}} -> max(y1, y2)
        %{pos: {_, y}} -> y
        %{pos: {_, y, _w, h}} -> y + h
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
  def handle_continue({:broadcast_insert, new}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:inserted, new}
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
  def handle_continue(:broadcast_delete, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      :reload
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

  @impl true
  def handle_continue(:broadcast_undo, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      :reload
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue(:broadcast_redo, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      :reload
    )

    {:noreply, state}
  end
end
