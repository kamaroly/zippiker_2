defmodule ZippikerWeb.Settings.BillingLive do
  @moduledoc """
  The workspace's plan, seats, billing contact and platform invoices.
  Plan changes are requested here and applied by the Zippiker team.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Platform

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Plan & billing")

    if admin?(socket.assigns) do
      {:ok, load(socket)}
    else
      {:ok, assign(socket, subscription: nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"billing" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"billing" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _subscription} ->
        {:noreply, socket |> put_flash(:info, "Billing contact saved") |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("request_plan", %{"id" => id}, socket) do
    case Platform.request_plan(id, ash_opts(socket)) do
      {:ok, _event} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "Thanks! We've let the Zippiker team know; they'll confirm the change by email."
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket) do
    %{current_user: user, current_organization: organization} = socket.assigns
    subscription = Platform.ensure_subscription!(organization.id, actor: user)
    organization = Ash.load!(organization, :members_count, actor: user)

    form =
      subscription
      |> AshPhoenix.Form.for_update(:update_billing_details, as: "billing", actor: user)
      |> to_form()

    socket
    |> assign(subscription: subscription, seats: organization.members_count, form: form)
    |> assign(:plans, Platform.list_plans!(%{active_only?: true}, actor: user))
    |> stream(
      :invoices,
      Platform.list_billing_invoices!(%{organization_id: organization.id}, actor: user),
      reset: true
    )
  end

  defp monthly(plan, seats), do: Decimal.mult(plan.price_per_seat, max(seats, 1))

  defp seat_percent(_seats, nil), do: 0
  defp seat_percent(seats, limit), do: min(100, round(seats / limit * 100))
end
