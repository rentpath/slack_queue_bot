defmodule QueueBot.Command do
  alias QueueBot.Manager
  import Plug.Conn
  require Poison

  def init(options) do
    options
  end

  def call(conn, _) do
    {:ok, body, _} = Plug.Conn.read_body(conn)
    params = Plug.Conn.Query.decode(body)

    {response_url, {channel, _} = parsed_command} = parse_command(params)

    manager_result = Manager.call(parsed_command)
    response =  response(manager_result, parsed_command)
    additional_actions(channel, manager_result, response_url)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response))
  end

  defp additional_actions(channel, %{queue: queue, new_first?: true}, url) do
    attachments =
      Enum.map(Enum.zip(Enum.take(queue, 2), ["good", "warning"]),
        fn {%{item: item}, color} -> %{"text": item, "color": color}
           {item, color} -> %{"text": item, "color": color}
           _ -> IO.puts "didn't match on anything"
        end)

    body = %{
      "response_type": "in_channel",
      "text": "*bold* Next in queue:",
      "attachments": attachments
    }

    Manager.call({channel, {:delayed_message, url, Poison.encode!(body)}})
  end
  defp additional_actions(_, _, _), do: nil

  defp response(%{queue: []}, _) do
    %{
      "text": "Queue is empty",
    }
  end
  defp response(%{queue: queue}, {_, type}) when elem(type, 0) in [:edit, :remove, :up, :down] do
    last_index = length(queue) - 1
    attachments =
      queue
      |> Enum.with_index()
      |> Enum.map(fn {%{id: id, item: item}, index} ->
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
               possible_actions = [up_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             length(queue) > 1 ->
               possible_actions = [up_button(id), down_button(id)]
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
  defp response(%{queue: queue}, {_, type}) when elem(type, 0) in [:display, :push, :broadcast, :pop] do
    attachments =
      queue
      |> Enum.with_index()
      |> Enum.map(fn {queue, index} -> %{"text" => "#{index + 1}. #{queue}"} end)

    base_message =
      %{
        "text": "Current Queue",
        "attachments": attachments
      }

    case elem(type, 0) do
      :broadcast -> Map.put(base_message, :"response_type", "in_channel")
      _ -> base_message
    end
  end

  # button clicks
  defp parse_command(%{"payload" => payload}) do
    parsed_payload = payload |> Poison.decode!
    channel_id = parsed_payload["channel"]["id"]
    %{"name" => action, "value" => id} =
      parsed_payload["actions"]
      |> List.first

    response_url = parsed_payload["response_url"]
    action_atom = action |> String.to_atom

    {response_url, {channel_id, {action_atom, id}}}
  end
  # typed /queue (or whatever app name is) calls
  defp parse_command(%{"text" => text, "channel_id" => channel_id, "trigger_id" => id, "response_url" => response_url}) do
    cond do
      text =~ ~r/^\s*help\s*$/ -> {response_url, {channel_id, {:help}}}
      text =~ ~r/^\s*broadcast\s*$/ -> {response_url, {channel_id, {:broadcast}}}
      text =~ ~r/^\s*display\s*$/ -> {response_url, {channel_id, {:display}}}
      text =~ ~r/^\s*edit\s*$/ -> {response_url, {channel_id, {:edit}}}
      text =~ ~r/^\s*pop\s*$/ -> {response_url, {channel_id, {:pop}}}
      text =~ ~r/^\s*$/ -> {response_url, {channel_id, {:help}}}
      true -> {response_url, {channel_id, {:push, id, text}}}
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
end
