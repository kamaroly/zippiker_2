defmodule ZippikerWeb.InvitationLive do
  @moduledoc "Accept an invitation from its email link."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    invitation =
      case Accounts.get_invitation_by_token(token, actor: socket.assigns.current_user) do
        {:ok, invitation} -> invitation
        _ -> nil
      end

    {:ok, assign(socket, page_title: "Join workspace", invitation: invitation, switch_to: nil)}
  end

  @impl true
  def handle_event("accept", _params, socket) do
    case Accounts.accept_invitation(socket.assigns.invitation, actor: socket.assigns.current_user) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "You joined #{invitation.organization.name}")
         |> assign(:switch_to, invitation.organization_id)}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, error |> Ash.Error.to_error_class() |> Exception.message())}
    end
  end
end
