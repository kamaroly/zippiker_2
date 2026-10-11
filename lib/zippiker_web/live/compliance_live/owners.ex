defmodule ZippikerWeb.ComplianceLive.Owners do
  @moduledoc """
  Register of beneficial owners: natural persons who own or control the
  company. Additions and cessations put an update to lodge on the calendar.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, :page_title, "Beneficial owners")}

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, assign(socket, modal: params["modal"], selected: params["id"])}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :owners, [])

  defp load(socket),
    do:
      assign(
        socket,
        :owners,
        Compliance.beneficial_owner_register!(socket.assigns.profile.id, ash_opts(socket))
      )

  @impl true
  def handle_event("add", %{"owner" => params}, socket) do
    params =
      params
      |> Map.reject(fn {_key, value} -> value == "" end)
      |> Map.put("profile_id", socket.assigns.profile.id)

    respond(
      socket,
      Compliance.add_beneficial_owner(params, ash_opts(socket)),
      "Beneficial owner added — lodge the update (see the filing calendar)"
    )
  end

  def handle_event("cease", %{"cease" => params}, socket) do
    owner = Enum.find(socket.assigns.owners, &(&1.id == socket.assigns.selected))

    respond(
      socket,
      Compliance.cease_beneficial_owner(owner, params, ash_opts(socket)),
      "Cessation recorded"
    )
  end

  defp respond(socket, result, message) do
    case result do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, message) |> push_patch(to: ~p"/compliance/beneficial-owners")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp control(owner) do
    [
      owner.shares_percent && "#{Decimal.normalize(owner.shares_percent)}% shares",
      owner.voting_percent && "#{Decimal.normalize(owner.voting_percent)}% votes",
      owner.appoints_directors? && "appoints directors",
      owner.significant_influence? && "significant influence"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end
end
