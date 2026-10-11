defmodule ZippikerWeb.ComplianceLive.Charges do
  @moduledoc "Register of charges: security over the company's assets, registration and satisfaction."
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Charges")}

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, assign(socket, modal: params["modal"], selected: params["id"])}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :charges, [])

  defp load(socket),
    do:
      assign(
        socket,
        :charges,
        Compliance.charge_register!(socket.assigns.profile.id, ash_opts(socket))
      )

  @impl true
  def handle_event("add", %{"charge" => params}, socket) do
    params =
      params
      |> Map.reject(fn {_key, value} -> value == "" end)
      |> Map.put("profile_id", socket.assigns.profile.id)

    respond(
      socket,
      Compliance.create_charge(params, ash_opts(socket)),
      "Charge recorded — its registration is on the filing calendar"
    )
  end

  def handle_event("register", %{"charge" => params}, socket),
    do:
      respond(
        socket,
        Compliance.update_charge(selected(socket), params, ash_opts(socket)),
        "Registration recorded"
      )

  def handle_event("satisfy", %{"charge" => params}, socket),
    do:
      respond(
        socket,
        Compliance.satisfy_charge(selected(socket), params, ash_opts(socket)),
        "Charge satisfied"
      )

  defp selected(socket),
    do: Enum.find(socket.assigns.charges, &(&1.id == socket.assigns.selected))

  defp respond(socket, result, message) do
    case result do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, message) |> push_patch(to: ~p"/compliance/charges")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp amount(%{amount_secured: nil}), do: "—"
  defp amount(charge), do: Format.money(Money.new!(charge.currency, charge.amount_secured))
end
