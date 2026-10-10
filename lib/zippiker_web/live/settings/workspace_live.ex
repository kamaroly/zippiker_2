defmodule ZippikerWeb.Settings.WorkspaceLive do
  @moduledoc "Workspace name, members, roles and invitations."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts

  @impl true
  def mount(_params, _session, socket) do
    organization = socket.assigns.current_organization

    form =
      organization
      |> AshPhoenix.Form.for_update(:update, as: "workspace", actor: socket.assigns.current_user)
      |> to_form()

    {:ok,
     socket
     |> assign(page_title: "Workspace", form: form)
     |> assign_invite_form()
     |> load_members()
     |> load_invitations()}
  end

  @impl true
  def handle_event("validate", %{"workspace" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"workspace" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: Map.take(params, ["name"])) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> assign(:current_organization, organization)
         |> put_flash(:info, "Workspace saved")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("invite", %{"invitation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.invite_form, params: params) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{invitation.email}")
         |> assign_invite_form()
         |> load_invitations()}

      {:error, form} ->
        {:noreply, assign(socket, :invite_form, form)}
    end
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    invitation = Enum.find(socket.assigns.invitations, &(&1.id == id))
    if invitation, do: Accounts.revoke_invitation!(invitation, opts)
    {:noreply, socket |> put_flash(:info, "Invitation revoked") |> load_invitations()}
  end

  def handle_event("role", %{"membership_id" => id, "role" => role}, socket) do
    membership = Enum.find(socket.assigns.members, &(&1.id == id))

    case membership && Accounts.update_membership(membership, %{role: role}, ash_opts(socket)) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Role updated") |> load_members()}
      _ -> {:noreply, put_flash(socket, :error, "Could not change that role")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    membership = Enum.find(socket.assigns.members, &(&1.id == id))

    case membership && Accounts.remove_member(membership, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Member removed") |> load_members()}
      _ -> {:noreply, put_flash(socket, :error, "Could not remove that member")}
    end
  end

  defp assign_invite_form(socket) do
    form =
      Accounts.Invitation
      |> AshPhoenix.Form.for_create(:create,
        as: "invitation",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"role" => "member"}
      )
      |> to_form()

    assign(socket, :invite_form, form)
  end

  defp load_members(socket) do
    members =
      Accounts.list_members!(socket.assigns.current_organization.id,
        actor: socket.assigns.current_user
      )

    socket |> assign(:members, members) |> stream(:members, members, reset: true)
  end

  defp load_invitations(socket) do
    invitations =
      if admin?(socket.assigns),
        do: Accounts.list_pending_invitations!(ash_opts(socket)),
        else: []

    socket |> assign(:invitations, invitations) |> stream(:invitations, invitations, reset: true)
  end
end
