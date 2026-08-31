defmodule Geomextric.CGA2Canvas do
  use GenServer
  alias Galixir.Algebras.CGA2
  @topic "cga2-canvas"

  defstruct [:elements, :future, :past]

  ## Client API

  def subscribe() do
    Phoenix.PubSub.subscribe(Geomextric.PubSub, @topic)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def add_raw(server, %CGA2{} = mv) do
    GenServer.cast(server, {:add, mv})
  end

  @impl true
  def init(elements) when is_list(elements) do
    {:ok, %__MODULE__{elements: elements, future: [], past: []}}
  end

  @impl true
  def handle_cast({:add, raw}, state) do
    {:noreply, state, {:continue, {:broadcast_add, raw}}}
  end

  @impl true
  def handle_continue({:broadcast_add, new}, state) do
    Phoenix.PubSub.broadcast(
      Geomextric.PubSub,
      @topic,
      {:added, new}
    )

    {:noreply, state}
  end
end
