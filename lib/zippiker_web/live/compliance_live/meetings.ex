defmodule ZippikerWeb.ComplianceLive.Meetings do
  @moduledoc """
  Board and general meetings and written resolutions: notice, agenda,
  attendees, minutes and resolutions. Passed special resolutions of held
  meetings go on the filing calendar.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @kinds [
    {"Board meeting", "board"},
    {"Annual general meeting", "agm"},
    {"Extraordinary general meeting", "egm"},
    {"Written resolution", "written_resolution"}
  ]

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "Meetings", kinds: @kinds)}

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, apply_modal(socket, params)}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :meetings, [])

  defp load(socket),
    do:
      assign(
        socket,
        :meetings,
        Compliance.list_meetings!(socket.assigns.profile.id, ash_opts(socket))
      )

  defp apply_modal(socket, %{"modal" => "new"}) do
    assign(socket,
      meeting: nil,
      editing?: true,
      fields: %{
        "kind" => "board",
        "title" => "",
        "held_on" => Date.to_iso8601(Date.utc_today()),
        "location" => "",
        "notice_sent_on" => "",
        "agenda" => "",
        "attendees" => "",
        "minutes" => "",
        "status" => "planned"
      },
      resolutions: []
    )
  end

  defp apply_modal(socket, %{"modal" => "edit", "id" => id}) do
    meeting = Enum.find(socket.assigns.meetings, &(&1.id == id))

    assign(socket,
      meeting: meeting,
      editing?: true,
      fields:
        Map.new(
          ~w(kind title held_on location notice_sent_on agenda attendees minutes status),
          fn key ->
            {key, meeting |> Map.get(String.to_existing_atom(key)) |> to_field()}
          end
        ),
      resolutions:
        Enum.map(
          meeting.resolutions,
          &%{
            "key" => &1.id,
            "text" => &1.text,
            "kind" => to_string(&1.kind),
            "passed?" => to_string(&1.passed?)
          }
        )
    )
  end

  defp apply_modal(socket, _params), do: assign(socket, meeting: nil, editing?: false)

  defp to_field(nil), do: ""
  defp to_field(%Date{} = date), do: Date.to_iso8601(date)
  defp to_field(value), do: to_string(value)

  @impl true
  def handle_event("change", params, socket), do: {:noreply, assign_params(socket, params)}

  def handle_event("add_resolution", _params, socket) do
    row = %{"key" => Ash.UUID.generate(), "text" => "", "kind" => "ordinary", "passed?" => "true"}
    {:noreply, update(socket, :resolutions, &(&1 ++ [row]))}
  end

  def handle_event("remove_resolution", %{"key" => key}, socket),
    do:
      {:noreply,
       update(socket, :resolutions, fn rows -> Enum.reject(rows, &(&1["key"] == key)) end)}

  def handle_event("save", params, socket) do
    socket = assign_params(socket, params)

    attrs =
      socket.assigns.fields
      |> Map.reject(fn {_key, value} -> value == "" end)
      |> Map.put(
        "resolutions",
        socket.assigns.resolutions
        |> Enum.reject(&(String.trim(&1["text"]) == ""))
        |> Enum.with_index()
        |> Enum.map(fn {row, index} ->
          %{
            "position" => index,
            "text" => row["text"],
            "kind" => row["kind"],
            "passed?" => row["passed?"] == "true"
          }
        end)
      )

    result =
      case socket.assigns.meeting do
        nil ->
          Compliance.create_meeting(
            Map.put(attrs, "profile_id", socket.assigns.profile.id),
            ash_opts(socket)
          )

        meeting ->
          Compliance.update_meeting(meeting, attrs, ash_opts(socket))
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "Meeting saved") |> push_patch(to: ~p"/compliance/meetings")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp assign_params(socket, params) do
    fields = Map.merge(socket.assigns.fields, Map.get(params, "meeting", %{}))
    rows = Map.get(params, "resolutions", %{})

    resolutions =
      Enum.map(socket.assigns.resolutions, fn row ->
        Map.merge(row, Map.take(Map.get(rows, row["key"], %{}), ~w(text kind passed?)))
      end)

    assign(socket, fields: fields, resolutions: resolutions)
  end

  defp kind_label(kind),
    do:
      Enum.find_value(@kinds, to_string(kind), fn {label, key} ->
        key == to_string(kind) && label
      end)
end
