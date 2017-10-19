defmodule QueueBot.ManagerTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, %{channel: make_ref()}}
  end

  describe "#help" do
    test "returns help items", %{channel: channel} do
      name = Application.get_env(:queue_bot, :slack)[:name]
      help_items = QueueBot.Manager.call({channel, {:help}})
      assert Enum.all?(help_items, &(String.starts_with?(&1, "/#{name}")))
    end
  end

  describe "#push" do
    test "adds an item", %{channel: channel} do
      item = "alan"
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == 0
      add_item(channel, item)
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == 1
      assert queue == [item]
    end

    test "with no items in the queue returns new_first? true", %{channel: channel} do
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == 0
      %{new_first?: new_first?} = add_item(channel, "write a song")
      assert new_first? == true
    end

    test "with items in the queue returns new_first? false", %{channel: channel} do
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == 0
      items = ["this", "that", "the other"]
      Enum.each(items, &(add_item(channel, &1)))
      %{new_first?: new_first?} = add_item(channel, "do another task")
      assert new_first? == false
    end
  end

  describe "#display" do
    test "returns the current queue", %{channel: channel} do
      items = ["fruit", "vegetables", "circus peanuts"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == length(items) 
      assert Enum.all?(Enum.zip(items, queue), fn {item, queue_item} -> item == queue_item end)
    end

    test "returns new_first? false", %{channel: channel} do
      items = ["zip", "zap", "zoom"]
      Enum.each(items, &(add_item(channel, &1)))
      %{new_first?: new_first?} = QueueBot.Manager.call({channel, {:display}})
      assert new_first? == false
    end
  end

  describe "#edit" do
    test "returns the current queue, each with an id and item", %{channel: channel} do
      items = ["medicine", "broth"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      assert Enum.all?(Enum.zip(items, queue), fn {item, %{id: _, item: queue_item}} -> item == queue_item end)
    end

    test "returns new_first? false", %{channel: channel} do
      items = ["totally", "radical", "english", "words"]
      Enum.each(items, &(add_item(channel, &1)))
      %{new_first?: new_first?} = QueueBot.Manager.call({channel, {:edit}})
      assert new_first? == false
    end
  end

  describe "#remove" do
    test "removes an item from the queue", %{channel: channel} do
      items = ["do", "re", "mi", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: id} | _] = queue
      QueueBot.Manager.call({channel, {:remove, id}})
      %{queue: queue} = QueueBot.Manager.call({channel, {:display}})
      assert length(queue) == length(items) - 1
    end

    test "with two items, removing the first, returns new_first? true", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: id} | _] = queue
      %{new_first?: new_first?} = QueueBot.Manager.call({channel, {:remove, id}})
      assert new_first? == true
    end

    test "with many items, removing any but the first, returns new_first? false", %{channel: channel} do
      items = ["do", "re", "do"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      %{id: id} = List.last(queue)
      %{new_first?: new_first?} = QueueBot.Manager.call({channel, {:remove, id}})
      assert new_first? == false
    end
  end

  describe "#up" do
    test "moves an item up in the queue", %{channel: channel} do
      items = ["sam", "sausage"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: first_id}, %{id: last_id}] = queue
      assert first_id != last_id
      QueueBot.Manager.call({channel, {:up, last_id}})
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: new_first_id}, %{id: new_last_id}] = queue
      assert new_first_id == last_id
      assert new_last_id == first_id
    end

    test "on the first item returns the same queue and new_first? false", %{channel: channel} do
      items = ["simple", "simon"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{id: id} | _] = queue
      %{queue: new_queue, new_first?: new_first?} = QueueBot.Manager.call({channel, {:up, id}})
      assert queue == new_queue
      assert new_first? == false
    end

    test "on the second, returns new_first? true", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      %{id: id} = Enum.at(queue, 1)
      %{queue: new_queue, new_first?: new_first?} = QueueBot.Manager.call({channel, {:up, id}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end

    test "on the third, returns new_first? false", %{channel: channel} do
      items = ["do", "re", "do"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      %{id: id} = Enum.at(queue, 2)
      %{queue: new_queue, new_first?: new_first?} = QueueBot.Manager.call({channel, {:up, id}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == false
    end
  end

  describe "#down" do
    test "moves an item down in the queue", %{channel: channel} do
      items = ["sam", "sausage"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: first_id}, %{id: last_id}] = queue
      assert first_id != last_id
      QueueBot.Manager.call({channel, {:down, first_id}})
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{id: new_first_id}, %{id: new_last_id}] = queue
      assert new_first_id == last_id
      assert new_last_id == first_id
    end

    test "on the last item returns the same queue and new_first? false", %{channel: channel} do
      items = ["simple", "simon"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      %{id: id} = List.last(queue)
      %{queue: new_queue, new_first?: new_first?} = QueueBot.Manager.call({channel, {:down, id}})
      assert queue == new_queue
      assert new_first? == false
    end

    test "on the second, returns new_first? false", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{queue: queue} = QueueBot.Manager.call({channel, {:edit}})
      %{id: id} = Enum.at(queue, 1)
      %{queue: new_queue, new_first?: new_first?} = QueueBot.Manager.call({channel, {:down, id}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == false
    end
  end

  defp add_item(channel, item) do
    QueueBot.Manager.call({channel, {:push, make_ref(), item}})
  end

  defp equal_contents(queue1, queue2) do
    order_contents(queue1) == order_contents(queue2)
  end

  defp order_contents(queue) do
    Enum.sort_by(queue, fn %{id: id} -> id end)
  end
end
