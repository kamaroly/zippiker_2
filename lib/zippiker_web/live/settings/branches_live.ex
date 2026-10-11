defmodule ZippikerWeb.Settings.BranchesLive do
  @moduledoc """
  Branches (head office, shops, depots) and the switch for businesses with
  several of them: when on, documents, employees and warehouses get a
  branch picker and reports can be run per branch.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts

  @impl true
  def mount(_params, _session, socket) do
    Accounts.default_branch!(ash_opts(socket))

    {:ok,
     socket
     |> assign(:page_title, "Branches")
     |> assign(:members, member_options(socket.assigns))
     |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Accounts.Branch
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> to_form()

    assign(socket, form: form, branch: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    branch = Accounts.get_branch!(id, ash_opts(socket))
    form = branch |> AshPhoenix.Form.for_update(:update, form_opts(socket)) |> to_form()
    assign(socket, form: form, branch: branch)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, branch: nil)

  defp form_opts(socket),
    do: [
      as: "branch",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]

  @impl true
  def handle_event("toggle_multi_branch", params, socket) do
    case Accounts.set_multi_branch(
           socket.assigns.current_organization,
           %{multi_branch?: params["multi_branch"] == "true"},
           actor: socket.assigns.current_user
         ) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> assign(:current_organization, organization)
         |> put_flash(
           :info,
           if(organization.multi_branch?,
             do: "Branches are on: pick a branch on documents and filter reports by branch",
             else: "Branches are off: everything uses the default branch"
           )
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("validate", %{"branch" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"branch" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _branch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Branch saved")
         |> load()
         |> push_patch(to: ~p"/settings/branches")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    branch = Accounts.get_branch!(id, ash_opts(socket))

    case Accounts.delete_branch(branch, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "#{branch.name} deleted") |> load()}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{branch.name} is used on records; untick Active to retire it"
         )}
    end
  end

  defp load(socket),
    do: stream(socket, :branches, Accounts.list_branches!(ash_opts(socket)), reset: true)
end
