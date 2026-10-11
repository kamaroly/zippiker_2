defmodule ZippikerWeb.ComplianceLive.Officers do
  @moduledoc "Register of directors and secretaries: appoint, edit, record cessation."
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @roles [:director, :managing_director, :alternate_director, :chairperson, :secretary]

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "Directors & secretaries", roles: @roles)}

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, apply_modal(socket, params)}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :officers, [])

  defp load(socket),
    do:
      assign(
        socket,
        :officers,
        Compliance.officer_register!(socket.assigns.profile.id, ash_opts(socket))
      )

  defp apply_modal(socket, %{"modal" => "appoint"}) do
    form =
      Compliance.Officer
      |> AshPhoenix.Form.for_create(
        :appoint,
        form_opts(socket, %{
          "profile_id" => socket.assigns.profile.id,
          "appointed_on" => Date.to_iso8601(Date.utc_today()),
          "role" => "director"
        })
      )
      |> to_form()

    assign(socket, form: form, officer: nil, ceasing: nil)
  end

  defp apply_modal(socket, %{"modal" => "edit", "id" => id}) do
    officer = Enum.find(socket.assigns.officers, &(&1.id == id))
    form = officer |> AshPhoenix.Form.for_update(:update, form_opts(socket)) |> to_form()
    assign(socket, form: form, officer: officer, ceasing: nil)
  end

  defp apply_modal(socket, %{"modal" => "cease", "id" => id}),
    do:
      assign(socket,
        form: nil,
        officer: nil,
        ceasing: Enum.find(socket.assigns.officers, &(&1.id == id))
      )

  defp apply_modal(socket, _params), do: assign(socket, form: nil, officer: nil, ceasing: nil)

  defp form_opts(socket, params \\ %{}),
    do: [
      as: "officer",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization,
      params: params
    ]

  @impl true
  def handle_event("validate", %{"officer" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"officer" => params}, socket) do
    params =
      if socket.assigns.officer,
        do: params,
        else: Map.put(params, "profile_id", socket.assigns.profile.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(socket.assigns.officer,
             do: "Saved",
             else: "Appointed — the notice to the Registrar is on the filing calendar"
           )
         )
         |> push_patch(to: ~p"/compliance/officers")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("cease", %{"cease" => params}, socket) do
    case Compliance.cease_officer(socket.assigns.ceasing, params, ash_opts(socket)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Cessation recorded — the notice to the Registrar is on the filing calendar"
         )
         |> push_patch(to: ~p"/compliance/officers")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end
end
