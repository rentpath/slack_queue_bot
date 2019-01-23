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

  describe "#pop" do
    test "removes the top item", %{channel: channel} do
      items = ["so", "ti", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert get_item_texts(queue) == ["so", "ti", "fa"]
      %{"queue" => new_queue} = QueueBot.Manager.call({channel, {:pop, 100, "llama"}})
      assert get_item_texts(new_queue) == ["ti", "fa"]
    end

    test "with no items in the queue returns new_first? false", %{channel: channel} do
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 0
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:pop, 100, "llama"}})
      assert new_first? == false
    end

    test "with any items in the queue returns new_first? true", %{channel: channel} do
      items = ["Alan", "Chris", "Toulson"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 3
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:pop, 100, "llama"}})
      assert length(new_queue) == 2
      assert new_first? == true
    end
  end

  describe "#push" do
    test "adds an item", %{channel: channel} do
      item = "alan"
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 0
      add_item(channel, item)
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 1
      assert get_item_texts(queue) == [item]
    end

    test "with no items in the queue returns new_first? true", %{channel: channel} do
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 0
      %{"new_first?" => new_first?} = add_item(channel, "write a song")
      assert new_first? == true
    end

    test "with one item in the queue returns new_first? true", %{channel: channel} do
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 0
      %{"new_first?" => new_first?} = add_item(channel, "write a song")
      assert new_first? == true
      %{"new_first?" => new_first?} = add_item(channel, "write another song")
      assert new_first? == true
    end

    test "with items in the queue returns new_first? false", %{channel: channel} do
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == 0
      items = ["this", "that", "the other"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"new_first?" => new_first?} = add_item(channel, "do another task")
      assert new_first? == false
    end
  end

  describe "#display" do
    test "returns the current queue", %{channel: channel} do
      items = ["fruit", "vegetables", "circus peanuts"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == length(items)
      item_texts = get_item_texts(queue) 
      assert Enum.all?(Enum.zip(items, item_texts), fn {item, queue_item} -> item == queue_item end)
    end

    test "returns new_first? false", %{channel: channel} do
      items = ["zip", "zap", "zoom"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert new_first? == false
    end
  end

  describe "#broadcast" do
    test "returns the current queue", %{channel: channel} do
      items = ["lemons", "limes", "limons"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:broadcast, 100, "llama"}})
      assert length(queue) == length(items) 
      item_texts = get_item_texts(queue) 
      assert Enum.all?(Enum.zip(items, item_texts), fn {item, queue_item} -> item == queue_item end)
    end

    test "returns new_first? false", %{channel: channel} do
      items = ["coke", "pepsi", "shasta"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:broadcast, 100, "llama"}})
      assert new_first? == false
    end
  end

  describe "#edit" do
    test "returns the current queue, each with an id and item", %{channel: channel} do
      items = ["medicine", "broth"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      assert Enum.all?(Enum.zip(items, queue), fn {item, %{"id" => _, "item" => queue_item}} -> item == queue_item end)
    end

    test "returns new_first? false", %{channel: channel} do
      items = ["totally", "radical", "english", "words"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:edit}})
      assert new_first? == false
    end
  end

  describe "#remove" do
    test "removes an item from the queue", %{channel: channel} do
      items = ["do", "re", "mi", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => id} | _] = queue
      QueueBot.Manager.call({channel, {:remove, id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:display, 100, "llama"}})
      assert length(queue) == length(items) - 1
    end

    test "removes the second item correctly in a two item queue", %{channel: channel} do
      items = ["pi", "co"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => id1, "item" => item1}, %{"id" => id2}] = queue
      QueueBot.Manager.call({channel, {:remove, id2, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"id" => new_id1, "item" => new_item1}] = queue
      assert length(queue) == length(items) - 1
      assert new_id1 == id1
      assert new_id1 != id2
      assert new_item1 == item1
    end

    test "with multiple items, removing the first, returns new_first? true", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => id} | _] = queue
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:remove, id, "llama"}})
      assert new_first? == true
    end

    test "with multiple items, removing the second, returns new_first? true", %{channel: channel} do
      items = ["la", "mi", "fa", "do"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      %{"id" => id} = Enum.at(queue, 1)
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:remove, id, "llama"}})
      assert new_first? == true
    end

    test "with many items, removing any but the first two, returns new_first? false", %{channel: channel} do
      items = ["do", "re", "do"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      %{"id" => id} = List.last(queue)
      %{"new_first?" => new_first?} = QueueBot.Manager.call({channel, {:remove, id, "llama"}})
      assert new_first? == false
    end
  end

  describe "#up" do
    test "moves an item up in the queue", %{channel: channel} do
      items = ["sam", "sausage"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => first_id}, %{"id" => last_id}] = queue
      assert first_id != last_id
      QueueBot.Manager.call({channel, {:up, last_id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => new_first_id}, %{"id" => new_last_id}] = queue
      assert new_first_id == last_id
      assert new_last_id == first_id
    end

    test "on the first item returns the same queue and new_first? false", %{channel: channel} do
      items = ["simple", "simon"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"id" => id} | _] = queue
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:up, id, "llama"}})
      assert queue == new_queue
      assert new_first? == false
    end

    test "on the second, returns new_first? true", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 1)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:up, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end

    test "on the third, returns new_first? true", %{channel: channel} do
      items = ["do", "re", "do"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 2)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:up, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end

    test "on the fourth, returns new_first? false", %{channel: channel} do
      items = ["mi", "do", "re", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 3)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:up, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == false
    end
  end

  describe "#move_to_top" do
    test "moves an item to the top of the queue", %{channel: channel} do
      items = ["simmy", "swanny", "samsonite"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => first_id}, %{"id" => middle_id}, %{"id" => last_id}] = queue
      assert first_id != last_id
      QueueBot.Manager.call({channel, {:move_to_top, last_id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => new_first_id}, %{"id" => new_middle_id}, %{"id" => new_last_id}] = queue
      assert new_first_id == last_id
      assert new_middle_id == first_id
      assert new_last_id == middle_id
    end

    test "on the first item returns the same queue and new_first? false", %{channel: channel} do
      items = ["simple", "simon", "pieman"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"id" => id} | _] = queue
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:move_to_top, id, "llama"}})
      assert queue == new_queue
      assert new_first? == false
    end

    test "on any other, returns new_first? true", %{channel: channel} do
      items = ["p", "q", "m", "n"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 2)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:move_to_top, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end
  end

  describe "#down" do
    test "moves an item down in the queue", %{channel: channel} do
      items = ["sam", "sausage"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => first_id}, %{"id" => last_id}] = queue
      assert first_id != last_id
      QueueBot.Manager.call({channel, {:down, first_id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => new_first_id}, %{"id" => new_last_id}] = queue
      assert new_first_id == last_id
      assert new_last_id == first_id
    end

    test "on the last item returns the same queue and new_first? false", %{channel: channel} do
      items = ["m", "o"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = List.last(queue)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:down, id, "llama"}})
      assert queue == new_queue
      assert new_first? == false
    end

    test "on the first, returns new_first? true", %{channel: channel} do
      items = ["x", "y", "a", "b"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"id" => id} | _] = queue
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:down, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end

    test "on the second, returns new_first? true", %{channel: channel} do
      items = ["o", "p", "q", "r"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 1)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:down, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == true
    end

    test "on the third, returns new_first? false", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      %{"id" => id} = Enum.at(queue, 2)
      %{"queue" => new_queue, "new_first?" => new_first?} = QueueBot.Manager.call({channel, {:down, id, "llama"}})
      assert queue != new_queue
      assert equal_contents(queue, new_queue)
      assert new_first? == false
    end
  end

  describe "#add_review" do
    test "adds review to item in queue", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => first_id}| _] = queue
      QueueBot.Manager.call({channel, {:add_review, first_id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"reviewers" => reviewers}| _] = queue
      assert reviewers == ["llama"]
    end

    test "adds only one review to item in queue per username", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [_, %{"id" => second_id}| _] = queue
      QueueBot.Manager.call({channel, {:add_review, second_id, "llama"}})
      QueueBot.Manager.call({channel, {:add_review, second_id, "llama"}})
      QueueBot.Manager.call({channel, {:add_review, second_id, "alpaca"}})
      QueueBot.Manager.call({channel, {:add_review, second_id, "llama"}})
      QueueBot.Manager.call({channel, {:add_review, second_id, "alpaca"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [_, %{"reviewers" => reviewers}| _] = queue
      assert reviewers == ["llama", "alpaca"]
    end
  end

  describe "#remove_review" do
    test "removes single review in queue", %{channel: channel} do
      items = ["so", "do", "la", "fa"]
      Enum.each(items, &(add_item(channel, &1)))
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      assert length(queue) == length(items)
      [%{"id" => first_id}, %{"id" => second_id}| _] = queue
      QueueBot.Manager.call({channel, {:add_review, first_id, "llama"}})
      QueueBot.Manager.call({channel, {:add_review, second_id, "llama"}})
      %{"queue" => queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"reviewers" => first_reviewers}, %{"reviewers" => second_reviewers}| _] = queue
      assert first_reviewers == ["llama"]
      assert second_reviewers == ["llama"]
      QueueBot.Manager.call({channel, {:remove_review, first_id, "llama"}})
      %{"queue" => updated_queue} = QueueBot.Manager.call({channel, {:edit}})
      [%{"reviewers" => updated_first_reviewers}, %{"reviewers" => updated_second_reviewers}| _] = updated_queue
      assert updated_first_reviewers == []
      assert updated_second_reviewers == ["llama"]
    end
  end


  defp add_item(channel, item) do
    QueueBot.Manager.call({channel, {:push, make_ref(), item}})
  end

  def get_item_texts(queue) do	
    Enum.map(queue, &(&1["item"]))	
  end
  defp equal_contents(queue1, queue2) do
    order_contents(queue1) == order_contents(queue2)
  end

  defp order_contents(queue) do
    Enum.sort_by(queue, fn %{"id" => id} -> id end)
  end
end
