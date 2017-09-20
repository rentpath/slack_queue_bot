defmodule QueueBot.Manager do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, [name: name])
  end

  def init(_) do
    {:ok, %{}}
  end

  def call({name, action}) do
    GenServer.call(:manager, {name, action})
  end

  def handle_call({name, {:edit}}, _from, state) do
    queue = List.wrap(state[name])
    {:reply, queue, state}
  end
  def handle_call({_, {:help}}, _from, state) do
    items = [
      "/queue help : displays this message",
      "/queue display : displays the current queue",
      "/queue edit : remove items from or move items within the queue"
    ]

    {:reply, items, state}
  end
  def handle_call({name, {:display}}, _from, state) do
    queue = List.wrap(state[name])
    items = Enum.map(queue, &(&1.item))
    {:reply, items, state}
  end
  def handle_call({name, {:push, id, item}}, _from, state) do
    queue = List.wrap(state[name])
    new_queue = queue ++ [%{id: id, item: item}]
    items = Enum.map(new_queue, &(&1.item))
    {:reply, items, Map.put(state, name, new_queue)}
  end
  def handle_call({name, {:remove, id}}, _from, state) do
    queue = List.wrap(state[name])
    new_queue =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> queue
        index -> List.delete_at(queue, index)
      end
    {:reply, new_queue, Map.put(state, name, new_queue)}
  end
  def handle_call({name, {:up, id}}, _from, state) do
    queue = List.wrap(state[name])
    new_queue =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> queue
        0 -> queue
        index ->
          item = Enum.at(queue, index)
          list = List.delete_at(queue, index)
          List.insert_at(list, index - 1, item)
      end
    {:reply, new_queue, Map.put(state, name, new_queue)}
  end
  def handle_call({name, {:down, id}}, _from, state) do
    queue = List.wrap(state[name])
    queue_length = length(queue) - 1
    new_queue =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> queue
        ^queue_length -> queue
        index ->
          item = Enum.at(queue, index)
          list = List.delete_at(queue, index)
          List.insert_at(list, index + 1, item)
      end
    {:reply, new_queue, Map.put(state, name, new_queue)}
  end
end
