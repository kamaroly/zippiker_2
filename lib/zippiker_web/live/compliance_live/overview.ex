defmodule ZippikerWeb.ComplianceLive.Overview do
  @moduledoc """
  Company secretarial home: the company's statutory details (set up or
  edit), what's overdue or due soon on the filing calendar, and the state
  of its registers.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Compliance}
  alias ZippikerWeb.ComplianceLive.Scope

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, :page_title, "Company secretarial")}

  @impl true
  def handle_params(params, _url, socket) do
    socket = Scope.assign_profile(socket, params)

    {:noreply,
     socket
     |> load()
     |> assign(:editing?, params["edit"] == "1" or is_nil(socket.assigns.profile))}
  end

  defp load(%{assigns: %{profile: nil}} = socket) do
    opts = ash_opts(socket)

    assign(socket,
      form: profile_form(socket, nil),
      entities: Enum.map(Accounts.list_legal_entities!(opts), &{&1.name, &1.id})
    )
  end

  defp load(%{assigns: %{profile: profile}} = socket) do
    opts = ash_opts(socket)
    tasks = Compliance.filing_calendar!(profile.id, %{open_only?: true}, opts)

    assign(socket,
      form: profile_form(socket, profile),
      entities: [],
      attention: Enum.filter(tasks, &(&1.state in [:overdue, :due_soon])),
      upcoming: tasks |> Enum.filter(&(&1.state == :upcoming)) |> Enum.take(5),
      directors: Compliance.officer_register!(profile.id, %{active_only?: true}, opts),
      members: Enum.filter(Compliance.member_register!(profile.id, opts), &(&1.shares_held > 0)),
      owners:
        Enum.filter(
          Compliance.beneficial_owner_register!(profile.id, opts),
          &is_nil(&1.ceased_on)
        ),
      charges: Enum.filter(Compliance.charge_register!(profile.id, opts), & &1.outstanding?)
    )
  end

  defp profile_form(socket, nil) do
    Compliance.CompanyProfile
    |> AshPhoenix.Form.for_create(:create,
      as: "company",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization,
      params: %{"legal_entity_id" => Accounts.default_legal_entity!(ash_opts(socket)).id}
    )
    |> to_form()
  end

  defp profile_form(socket, profile) do
    profile
    |> AshPhoenix.Form.for_update(:update,
      as: "company",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    )
    |> to_form()
  end

  @impl true
  def handle_event("validate", %{"company" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"company" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company details saved")
         |> push_patch(to: ~p"/compliance?company=#{profile.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp missing(assigns) do
    profile = assigns.profile

    [
      is_nil(profile.registration_number) && "Registration number",
      is_nil(profile.incorporation_date) && "Incorporation date (needed for annual returns)",
      (profile.secretary_required? and not Enum.any?(assigns.directors, &(&1.role == :secretary))) &&
        "A company secretary (required for this company)",
      assigns.directors |> Enum.count(&(&1.role in [:director, :managing_director, :chairperson])) ==
        0 &&
        "At least one director",
      assigns.owners == [] && "Beneficial owners (the register must be kept and lodged)"
    ]
    |> Enum.filter(& &1)
  end
end
