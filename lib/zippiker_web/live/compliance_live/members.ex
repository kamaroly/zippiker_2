defmodule ZippikerWeb.ComplianceLive.Members do
  @moduledoc """
  Register of members and share capital: share classes, members with their
  holdings, allotments (with a return of allotment on the calendar) and
  transfers between members.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Members & shares")}

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, assign(socket, :modal, params["modal"])}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, members: [], classes: [])

  defp load(socket) do
    opts = ash_opts(socket)
    profile_id = socket.assigns.profile.id

    assign(socket,
      members: Compliance.member_register!(profile_id, opts),
      classes: Compliance.share_classes!(profile_id, opts)
    )
  end

  @impl true
  def handle_event("add_class", %{"class" => params}, socket),
    do:
      save(
        socket,
        Compliance.create_share_class(with_profile(socket, params), ash_opts(socket)),
        "Share class added"
      )

  def handle_event("add_member", %{"member" => params}, socket),
    do:
      save(
        socket,
        Compliance.add_shareholder(with_profile(socket, params), ash_opts(socket)),
        "Member added"
      )

  def handle_event("allot", %{"allot" => params}, socket),
    do:
      save(
        socket,
        Compliance.allot_shares(with_profile(socket, params), ash_opts(socket)),
        "Shares allotted — the return of allotment is on the filing calendar"
      )

  def handle_event("transfer", %{"transfer" => params}, socket),
    do:
      save(
        socket,
        Compliance.transfer_shares(with_profile(socket, params), ash_opts(socket)),
        "Transfer recorded"
      )

  defp with_profile(socket, params) do
    params
    |> Map.reject(fn {_key, value} -> value == "" end)
    |> Map.put("profile_id", socket.assigns.profile.id)
  end

  defp save(socket, result, message) do
    case result do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, message) |> push_patch(to: ~p"/compliance/members")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp holdings(member, classes) do
    member.movements
    |> Enum.group_by(& &1.share_class_id)
    |> Enum.map(fn {class_id, movements} ->
      {Enum.find_value(classes, "Shares", &(&1.id == class_id && &1.name)),
       Enum.sum_by(movements, & &1.quantity)}
    end)
    |> Enum.reject(fn {_class, quantity} -> quantity == 0 end)
  end

  defp shareholder_options(members), do: Enum.map(members, &{&1.name, &1.id})
  defp class_options(classes), do: Enum.map(classes, &{&1.name, &1.id})
end
