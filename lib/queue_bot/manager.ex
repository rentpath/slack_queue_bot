defmodule QueueBot.Manager do
  use GenServer

  @name Application.get_env(:queue_bot, :slack)[:name] 
  @new_top_items_timout Application.get_env(:queue_bot, :slack)[:new_top_items_timeout]
  @use_redis Application.get_env(:queue_bot, :redis_client)[:use_redis]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [name: :manager])
  end

  def init(_) do
    {:ok, load_state(@use_redis)}
  end

  def call({channel, action}) do
    GenServer.call(:manager, {channel, action})
  end

  def handle_call({channel, command}, from, state) do
    new_state =
      case state[channel] do
        nil -> Map.put(state, channel, %{"queue" => [], "delayed_job_ref" => nil})

        _ -> state
      end

    do_handle_call({channel, command}, from, new_state)
    |> persist_result(@use_redis, channel, new_state)
  end

  defp load_state(true) do
    persisted_channels =
      case Exredis.query(:redis, ["KEYS", "*"]) do
        :no_connection -> []

        nil -> []

        channels -> channels
      end

    Enum.reduce(persisted_channels, %{}, fn channel, acc ->
      channel_state =
        Exredis.query(:redis, ["GET", channel])
        |> Poison.decode!
      Map.put(acc, channel, channel_state)
    end)
  end
  defp load_state(_) do
    %{}
  end

  defp persist_result({_, _, state} = result, true, channel, previous_state) when state != previous_state do

    # run it in the background -- we don't really care if it dies
    Task.start fn ->
      recorded_state = Map.put(state[channel], "delayed_job_ref", nil)
      Exredis.query :redis, ["SET", channel, Poison.encode!(recorded_state)]
    end
    result
  end
  defp persist_result(result, _, _, _) do
    result
  end

  defp do_handle_call({_, {:help}}, _from, state) do
    items = [
      "/#{@name} help: displays this message (privately)",
      "/#{@name} broadcast: displays the current queue to the entire channel",
      "/#{@name} display: displays the current queue privately",
      "/#{@name} edit: remove items from or move items within the queue",
      "/#{@name} pop: removes an item from the top of the queue",
      "/#{@name} <anything else>: adds item to the bottom of the queue"
    ]

    {:reply, items, state}
  end

  defp do_handle_call({channel, {command, _id, _user_name}}, _from, state) when command in [:display, :broadcast] do
    queue = state[channel]["queue"]
    {:reply, %{"queue" => queue, "new_first?" => false}, state}
  end
  defp do_handle_call({channel, {:edit}}, _from, state) do
    queue = state[channel]["queue"]
    {:reply, %{"queue" => queue, "new_first?" => false}, state}
  end
  defp do_handle_call({channel, {:push, id, item}}, _from, state) do
    queue = state[channel]["queue"]
    new_queue = queue ++ [%{"id" => id, "item" => item, "reviewers" => []}]
    new_first? = length(queue) in [0,1]
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:pop, _id, _user_name}}, _from, state) do
    queue = state[channel]["queue"]
    new_first? = length(queue) > 0
    new_queue = Enum.drop(queue, 1)
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:remove, id, _user_name}}, _from, state) do
    queue = state[channel]["queue"]
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1["id"] == id)) do
        nil -> {queue, false}

        0 -> {List.delete_at(queue, 0), true}

        1 -> {List.delete_at(queue, 1), true}

        index -> {List.delete_at(queue, index), false}
      end
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:up, id, _user_name}}, _from, state) do
    queue = state[channel]["queue"]
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1["id"] == id)) do
        nil -> {queue, false}

        0 -> {queue, false}

        1 -> {move_up(queue, 1), true}

        2 -> {move_up(queue, 2), true}

        index -> {move_up(queue, index), false}
      end
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:down, id, _user_name}}, _from, state) do
    queue = state[channel]["queue"]
    last_queue_index = length(queue) - 1
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1["id"] == id)) do
        nil -> {queue, false}

        ^last_queue_index -> {queue, false}

        0 -> {move_down(queue, 0), true}

        1 -> {move_down(queue, 1), true}

        index -> {move_down(queue, index), false}
      end
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:move_to_top, id, _user_name}}, _from, state) do
    queue = state[channel]["queue"]
    {new_queue, new_first?} =
      case Enum.find_index(queue, &(&1["id"] == id)) do
        nil -> {queue, false}

        0 -> {queue, false}

        index -> {move_to_top(queue, index), true}
      end
    {:reply, %{"queue" => new_queue, "new_first?" => new_first?}, put_in(state, [channel, "queue"], new_queue)}
  end
  defp do_handle_call({channel, {:delayed_message, message_sender}}, from, state) do
    case state[channel]["delayed_job_ref"] do
      nil ->
        sender_ref = Process.send_after(self(), {:delayed_response, channel, message_sender}, @new_top_items_timout * 1000)
        {:reply, :ok, put_in(state, [channel, "delayed_job_ref"], sender_ref)}

      sender_ref ->
        Process.cancel_timer(sender_ref)
        do_handle_call({channel, {:delayed_message, message_sender}}, from, put_in(state, [channel, "delayed_job_ref"], nil))
    end
  end

  defp do_handle_call({channel, {:add_review, id, user_name}}, _from, state) do
    queue = state[channel]["queue"]
    item_index = Enum.find_index(queue, &(&1["id"] == id))
    # item_index == nil if an item has been removed and you try to add a review to that item
    cond do
      item_index == nil -> 
        {:reply, %{"queue" => queue, "new_first?" => false}, state}

      reviewer_exists?(queue, item_index, user_name) ->
        {:reply, %{"queue" => queue, "new_first?" => false}, state}

      true ->
        new_queue = add_to_reviewers(queue, item_index, user_name)
        new_state = put_in(state, [channel, "queue"], new_queue)
        {:reply, %{"queue" => new_queue, "new_first?" => false}, new_state}
    end
  end
  
  defp do_handle_call({channel, {:remove_review, id, user_name}}, _from, state) do
    queue = state[channel]["queue"]
    # item_index = nil if an item has been removed and you try to remove a review from that item
    case Enum.find_index(queue, &(&1["id"] == id)) do
      nil -> 
        {:reply, %{"queue" => queue, "new_first?" => false}, state}

      item_index ->
        new_queue = remove_from_reviewers(queue, item_index, user_name)
        {:reply, %{"queue" => new_queue, "new_first?" => false}, put_in(state, [channel, "queue"], new_queue)}
    end
  end

  def handle_info({:delayed_response, channel, message_sender}, state) do
    message_sender.()
    {:noreply, put_in(state, [channel, "delayed_job_ref"], nil)}
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

  defp move_to_top(queue, index) do
    item = Enum.at(queue, index)
    list = List.delete_at(queue, index)
    List.insert_at(list, 0, item)
  end

  defp reviewer_exists?(queue, index, user_name) do
    %{"reviewers" => reviewers} = Enum.at(queue, index)
    user_name in reviewers
  end

  defp add_to_reviewers(queue, index, user_name) do
    new_item =
      queue
      |> Enum.at(index)
      |> Map.update("reviewers", [], &(&1 ++ [user_name]))

    List.replace_at(queue, index, new_item)
  end

  defp remove_from_reviewers(queue, index, user_name) do
    new_item =
      queue
      |> Enum.at(index)
      |> Map.update("reviewers", [], &(&1 -- [user_name]))

    List.replace_at(queue, index, new_item)
  end
end
