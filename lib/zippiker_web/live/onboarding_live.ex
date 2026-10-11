defmodule ZippikerWeb.OnboardingLive do
  @moduledoc "Create a workspace, or join one you were invited to."
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Crm}

  @currencies ~w(USD EUR GBP CAD AUD RWF KES UGX TZS NGN ZAR GHS XOF INR JPY CHF)

  @impl true
  def mount(params, _session, socket) do
    user = Ash.load!(socket.assigns.current_user, :memberships, authorize?: false)

    if user.memberships != [] and params["new"] != "1" do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(page_title: "Create your workspace", currencies: @currencies, switch_to: nil)
       |> assign(:first?, user.memberships == [])
       |> assign(:invitations, Accounts.list_my_invitations!(actor: user))
       |> assign(
         :form,
         to_form(%{"name" => user.name, "workspace" => "", "domain" => "", "currency" => "USD"})
       )}
    end
  end

  @impl true
  def handle_event(
        "save",
        %{"name" => name, "workspace" => workspace, "currency" => currency} = params,
        socket
      ) do
    user = socket.assigns.current_user
    domain = params |> Map.get("domain", "") |> String.trim()

    with {:ok, user} <- Accounts.update_profile(user, %{name: name}, actor: user),
         {:ok, organization} <-
           Accounts.create_organization(
             %{name: workspace, currency: currency, domain: domain},
             actor: user
           ),
         user = Ash.load!(user, :memberships, authorize?: false),
         {:ok, _pipeline} <- Crm.seed_crm_defaults(tenant: organization, actor: user) do
      {:noreply,
       socket
       |> put_flash(:info, "Welcome to #{organization.name}!")
       |> assign(:switch_to, organization.id)}
    else
      {:error, error} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params))
         |> put_flash(:error, error_message(error))}
    end
  end

  def handle_event("join", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    invitation = Enum.find(socket.assigns.invitations, &(&1.id == id))

    case invitation && Accounts.accept_invitation(invitation, actor: user) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "You joined #{invitation.organization.name}")
         |> assign(:switch_to, invitation.organization_id)}

      _ ->
        {:noreply, put_flash(socket, :error, "That invitation is no longer valid")}
    end
  end
end
