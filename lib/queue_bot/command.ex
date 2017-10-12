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

    parsed_command = parse_command(params)

    response =
      Manager.call(parsed_command)
      |> response(parsed_command)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response))
  end

  defp response(result, _) when length(result) == 0 do
    %{
      "text": "Queue is empty",
    }
  end
  defp response(result, {_, type}) when elem(type, 0) in [:edit, :remove, :up, :down] do
    last_result_index = length(result) - 1
    attachments =
      result
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
             index == 0 && length(result) > 1 ->
               possible_actions = [down_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             index == last_result_index && length(result) > 1 ->
               possible_actions = [up_button(id)]
               Map.put(buttons, :actions, buttons.actions ++ possible_actions)
             length(result) > 1 ->
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
  defp response(result, {_, type}) when elem(type, 0) in [:display, :push] do
    attachments =
      result
      |> Enum.with_index()
      |> Enum.map(fn {result, index} -> %{"text" => "#{index + 1}. #{result}"} end)

    %{
      "text": "Current Queue",
      "attachments": attachments
    }
  end

  # button clicks
  defp parse_command(%{"payload" => payload}) do
    parsed_payload = payload |> Poison.decode!
    channel_id = parsed_payload["channel"]["id"]
    %{"name" => action, "value" => id} =
      parsed_payload["actions"]
      |> List.first

    action_atom = action |> String.to_atom

    {channel_id, {action_atom, id}}
  end
  # typed /queue (or whatever app name is) calls
  defp parse_command(%{"text" => text, "channel_id" => channel_id, "trigger_id" => id}) do
    cond do
      text =~ ~r/^\s*edit\s*$/ -> {channel_id, {:edit}}
      text =~ ~r/^\s*display\s*$/ -> {channel_id, {:display}}
      text =~ ~r/^\s*help\s*$/ -> {channel_id, {:help}}
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
end
