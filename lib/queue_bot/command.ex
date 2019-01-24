defmodule QueueBot.Command do
  alias QueueBot.Manager
  import Plug.Conn
  require Poison

  @slack_qubot_url "https://slack.com/api/chat.postMessage"
  @edit_actions [:edit, :remove, :up, :down, :move_to_top]
  @non_edit_actions [:display, :push, :pop, :add_review, :remove_review]

  def init(options) do
    options
  end

  def call(conn, _) do
    {:ok, body, _} = Plug.Conn.read_body(conn)
    params = Plug.Conn.Query.decode(body)

    {channel, _} = parsed_command = parse_command(params)

    manager_result = Manager.call(parsed_command)
    response =  response(manager_result, parsed_command)
    additional_actions(channel, manager_result)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response))
  end

  defp additional_actions(channel, %{"queue" => queue, "new_first?" => true}) do
    token = Application.get_env(:queue_bot, :slack)[:token]

    if token do
      attachments =
        case queue do
          [] -> [%{"text": "Queue is now empty"}]
          queue ->
            Enum.take(queue, 2)
            |> Enum.zip(["good", "warning"])
            |> Enum.map(&make_item_attachment/1)
        end

      message_sender = fn ->
        HTTPoison.post @slack_qubot_url, {:form, [
          {"token", token},
          {"channel", channel},
          {"text", "*Next in queue*"},
          {"attachments", Poison.encode!(attachments)}
        ]}
      end

      Manager.call({channel, {:delayed_message, message_sender}})
    end
  end
  defp additional_actions(_, _), do: nil

  defp make_item_attachment({%{"item" => item}, color}), do: %{"text": item, "color": color}
  defp make_item_attachment({item, color}), do: %{"text": item, "color": color}

  defp response(%{"queue" => []}, _) do
    %{
      "text": "*Queue is empty*",
    }
  end
  defp response(%{"queue" => queue}, {_, type}) when elem(type, 0) in @edit_actions do
    last_index = length(queue) - 1
    attachments =
      queue
      |> Enum.with_index()
      |> Enum.map(fn {%{"id" => id, "item" => item}, index} ->
           buttons = %{
             "text": "#{index + 1}. #{item}",
             "callback_id": "edit_queue",
             "attachment_type": "default",
             "actions": [
               %{
                 "name": "remove",
                 "text": "Remove",
                 "type": "button",
                 "value": id,
                 "confirm": %{
                   "title": "Are you sure?",
                   "text": "This will remove the item from the queue and is irreversible.",
                   "ok_text": "Yes",
                   "dismiss_text": "No"
                 }
               }
             ]
           }

           cond do
             index == 0 && length(queue) > 1 ->
               possible_actions = [down_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             index == last_index && length(queue) > 1 ->
               possible_actions = [move_to_top_button(id), up_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             length(queue) > 1 ->
               possible_actions = [move_to_top_button(id), up_button(id), down_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             true ->
               buttons
           end
         end)

    %{
      "text": "Edit the queue",
      "attachments": attachments
    }
  end
  defp response(result, {_, {:help}}) do
    attachments = Enum.map(result, &(%{"text" => &1}))

    %{
      "text": "Available Actions",
      "attachments": attachments
    }
  end
  defp response(%{"queue" => queue}, {_, {:broadcast, _id, user}}) do
    attachments =
      queue
      |> Enum.with_index()
      |> Enum.map(fn {%{"id" => id, "item" => item, "reviewers" => reviewers}, index} ->
        text =
          case length(reviewers) > 0 do
            false -> 
              "#{index + 1}. #{item}"
    
            true ->
              reviewer_list = Enum.join(reviewers, ", ")
              "#{index + 1}. #{item} *Reviewers:* #{reviewer_list}"
          end
  
          buttons = %{
            "text": text,
            "callback_id": "edit_queue",
            "attachment_type": "default",
            "actions": []
          }
        end)
    %{
      "text": "Current Queue",
      "attachments": attachments,
      "response_type": "in_channel"
    }
  end
  defp response(%{"queue" => queue}, {_, {action, _id, user}})
  when action in @non_edit_actions do
    attachments = text_with_review_buttons(queue, user)
    %{
      "text": "Current Queue",
      "attachments": attachments
    }
  end

  defp text_with_review_buttons(queue, user) do
    queue
    |> Enum.with_index()
    |> Enum.map(fn(queue_with_index) -> text_with_review_button(queue_with_index, user) end)
  end

  defp text_with_review_button({%{"id" => id, "item" => item, "reviewers" => reviewers}, index}, user) do
    text =
      case length(reviewers) > 0 do
        false -> 
          "#{index + 1}. #{item}"

        true ->
          reviewer_list = Enum.join(reviewers, ", ")
          "#{index + 1}. #{item} *Reviewers:* #{reviewer_list}"
      end

    buttons = %{
      "actions": [],
      "attachment_type": "default",
      "callback_id": "edit_queue",
      "text": text
    }

    case Enum.member?(reviewers, user) do
      false -> Map.update!(buttons, :actions, &[review_button(id) | &1])

      true -> Map.update!(buttons, :actions, &[remove_review_button(id) | &1])
    end
  end
  # button clicks
  defp parse_command(%{"payload" => payload}) do
    parsed_payload = payload |> Poison.decode!
    channel_id = parsed_payload["channel"]["id"]
    user_name = get_in(parsed_payload, ["user", "name"])

    %{"name" => action, "value" => id} =
      parsed_payload["actions"]
      |> List.first

    action_atom = action |> String.to_atom

    {channel_id, {action_atom, id, user_name}}
  end
  # typed /queue (or whatever app name is) calls
  defp parse_command(%{"text" => text, "channel_id" => channel_id, "trigger_id" => id, "user_name" => user_name}) do
    cond do
      text =~ ~r/^\s*help\s*$/ -> {channel_id, {:help}}
      text =~ ~r/^\s*broadcast\s*$/ -> {channel_id, {:broadcast, nil, user_name}}
      text =~ ~r/^\s*display\s*$/ -> {channel_id, {:display, nil, user_name}}
      text =~ ~r/^\s*edit\s*$/ -> {channel_id, {:edit}}
      text =~ ~r/^\s*pop\s*$/ -> {channel_id, {:pop, nil, user_name}}
      text =~ ~r/^\s*$/ -> {channel_id, {:help}}
      true -> {channel_id, {:push, id, text}}
    end
  end

  defp down_button(id) do
    %{
      "name": "down",
      "text": "Move Down",
      "type": "button",
      "value": id
    }
  end

  defp up_button(id) do
    %{
      "name": "up",
      "text": "Move up",
      "type": "button",
      "value": id
    }
  end

  defp move_to_top_button(id) do
    %{
      "name": "move_to_top",
      "text": "Move to top",
      "type": "button",
      "value": id
    }
  end

  defp review_button(id) do
    %{
      "name": "add_review",
      "text": "Review",
      "type": "button",
      "value": id
    }
  end

  defp remove_review_button(id) do
    %{
      "name": "remove_review",
      "text": "Remove Review",
      "type": "button",
      "value": id
    }
  end

end
