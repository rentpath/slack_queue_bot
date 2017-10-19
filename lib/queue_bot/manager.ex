defmodule QueueBot.Manager do
  use GenServer

  @name Application.get_env(:queue_bot, :slack)[:name] 

  def start_link() do
    GenServer.start_link(__MODULE__, nil, [name: :manager])
  end

  def init(_) do
    {:ok, %{}}
  end

  def call({channel, action}) do
    GenServer.call(:manager, {channel, action})
  end

  def handle_call({_, {:help}}, _from, state) do
    items = [
      "/#{@name} help : displays this message",
      "/#{@name} display : displays the current @name",
      "/#{@name} edit : remove items from or move items within the @name"
    ]

    {:reply, items, state}
  end
  def handle_call({channel, {:display}}, _from, state) do
    items =
      List.wrap(state[channel])
      |> get_item_texts()
    {:reply, %{queue: items, new_first?: false}, state}
  end
  def handle_call({channel, {:edit}}, _from, state) do
    queue = List.wrap(state[channel])
    {:reply, %{queue: queue, new_first?: false}, state}
  end
  def handle_call({channel, {:push, id, item}}, _from, state) do
    queue = List.wrap(state[channel])
    new_queue = queue ++ [%{id: id, item: item}]
    items = get_item_texts(new_queue)
    new_first? = length(queue) == 0
    {:reply, %{queue: items, new_first?: new_first?}, Map.put(state, channel, new_queue)}
  end
  def handle_call({channel, {:remove, id}}, _from, state) do
    queue = List.wrap(state[channel])
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        0 -> {List.delete_at(queue, 0), true}
        index -> {List.delete_at(queue, index), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, Map.put(state, channel, new_queue)}
  end
  def handle_call({channel, {:up, id}}, _from, state) do
    queue = List.wrap(state[channel])
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        0 -> {queue, false}
        1 -> {move_up(queue, 1), true}
        index -> {move_up(queue, index), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, Map.put(state, channel, new_queue)}
  end
  def handle_call({channel, {:down, id}}, _from, state) do
    queue = List.wrap(state[channel])
    last_queue_index = length(queue) - 1
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        ^last_queue_index -> {queue, false}
        index ->
          item = Enum.at(queue, index)
          list = List.delete_at(queue, index)
          {List.insert_at(list, index + 1, item), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, Map.put(state, channel, new_queue)}
  end

  def get_item_texts(queue) do
    Enum.map(queue, &(&1.item))
  end

  defp move_up(queue, index) do
    item = Enum.at(queue, index)
    list = List.delete_at(queue, index)
    List.insert_at(list, index - 1, item)
  end
end
