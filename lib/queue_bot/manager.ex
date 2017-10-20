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

  def handle_call({channel, command}, from, state) do
    new_state =
      case state[channel] do
        nil -> Map.put(state, channel, %{queue: [], delayed_job_ref: nil})
        _ -> state
      end

    do_handle_call({channel, command}, from, new_state)
  end

  defp do_handle_call({_, {:help}}, _from, state) do
    items = [
      "/#{@name} help : displays this message (privately)",
      "/#{@name} display : displays the current queue (privately)",
      "/#{@name} broadcast: displays the current queue, but broadcasts to channel",
      "/#{@name} edit : remove items from or move items within the @name",
    ]

    {:reply, items, state}
  end
  defp do_handle_call({channel, command}, _from, state) when command in [{:display}, {:broadcast}] do
    items =
      state[channel][:queue]
      |> get_item_texts()
    {:reply, %{queue: items, new_first?: false}, state}
  end
  defp do_handle_call({channel, {:edit}}, _from, state) do
    queue = state[channel][:queue]
    {:reply, %{queue: queue, new_first?: false}, state}
  end
  defp do_handle_call({channel, {:push, id, item}}, _from, state) do
    queue = state[channel][:queue]
    new_queue = queue ++ [%{id: id, item: item}]
    items = get_item_texts(new_queue)
    new_first? = length(queue) in [0,1]
    {:reply, %{queue: items, new_first?: new_first?}, put_in(state, [channel, :queue], new_queue)}
  end
  defp do_handle_call({channel, {:remove, id}}, _from, state) do
    queue = state[channel][:queue]
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        0 -> {List.delete_at(queue, 0), true}
        1 -> {List.delete_at(queue, 0), true}
        index -> {List.delete_at(queue, index), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, put_in(state, [channel, :queue], new_queue)}
  end
  defp do_handle_call({channel, {:up, id}}, _from, state) do
    queue = state[channel][:queue]
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        0 -> {queue, false}
        1 -> {move_up(queue, 1), true}
        2 -> {move_up(queue, 2), true}
        index -> {move_up(queue, index), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, put_in(state, [channel, :queue], new_queue)}
  end
  defp do_handle_call({channel, {:down, id}}, _from, state) do
    queue = state[channel][:queue]
    last_queue_index = length(queue) - 1
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1.id == id)) do
        nil -> {queue, false}
        ^last_queue_index -> {queue, false}
        0 -> {move_down(queue, 0), true}
        1 -> {move_down(queue, 1), true}
        index -> {move_down(queue, index), false}
      end
    {:reply, %{queue: new_queue, new_first?: new_first?}, put_in(state, [channel, :queue], new_queue)}
  end
  defp do_handle_call({channel, {:delayed_message, url, body}}, from, state) do
    case state[channel][:delayed_job_ref] do
      nil ->
        sender_ref = Process.send_after(self(), {:delayed_response, channel, url, body}, 30 * 1000)
        {:reply, :ok, put_in(state, [channel, :delayed_job_ref], sender_ref)}
      sender_ref ->
        Process.cancel_timer(sender_ref)
        do_handle_call({channel, {:delayed_message, url, body}}, from, put_in(state, [channel, :delayed_job_ref], nil))
    end
  end

  def handle_info({:delayed_response, channel, url, body}, state) do
    HTTPoison.post url, body
    {:noreply, put_in(state, [channel, :delayed_job_ref], nil)}
  end

  def get_item_texts(queue) do
    Enum.map(queue, &(&1.item))
  end

  defp move_up(queue, index) do
    item = Enum.at(queue, index)
    list = List.delete_at(queue, index)
    List.insert_at(list, index - 1, item)
  end

  defp move_down(queue, index) do
    item = Enum.at(queue, index)
    list = List.delete_at(queue, index)
    List.insert_at(list, index + 1, item)
  end
end
