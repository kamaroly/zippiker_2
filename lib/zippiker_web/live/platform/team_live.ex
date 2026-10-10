defmodule ZippikerWeb.Platform.TeamLive do
  @moduledoc """
  One workspace from the platform side: subscription and plan, modules and
  seat limit, platform invoices, members (with impersonation), usage and
  its audit trail. "Open workspace" enters it as an admin.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Platform}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, socket |> assign(:team_id, id) |> load()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :subscription) do
    form =
      socket.assigns.subscription
      |> AshPhoenix.Form.for_update(:change_plan,
        as: "subscription",
        actor: socket.assigns.current_user
      )
      |> to_form()

    plans = Platform.list_plans!(actor: socket.assigns.current_user)
    assign(socket, form: form, plan_options: Enum.map(plans, &{plan_label(&1), &1.id}))
  end

  defp apply_action(socket, :show), do: assign(socket, :form, nil)

  @impl true
  def handle_event("validate", %{"subscription" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save_subscription", %{"subscription" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, subscription} ->
        subscription = Ash.load!(subscription, :plan, actor: socket.assigns.current_user)

        log(
          socket,
          :plan_changed,
          "#{subscription.plan.name} plan, #{Format.humanize(subscription.status)}"
        )

        {:noreply,
         socket
         |> put_flash(:info, "Subscription updated")
         |> load()
         |> push_patch(to: ~p"/platform/teams/#{socket.assigns.team_id}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("save_limits", params, socket) do
    modules =
      for key <- List.wrap(params["modules"]),
          module <- ZippikerWeb.Modules.all(),
          to_string(module.key) == key,
          do: module.key

    seat_limit =
      case Integer.parse(params["seat_limit"] || "") do
        {limit, ""} when limit > 0 -> limit
        _ -> nil
      end

    case Accounts.set_plan_limits(
           socket.assigns.team,
           %{enabled_modules: modules, seat_limit: seat_limit},
           actor: socket.assigns.current_user
         ) do
      {:ok, _team} ->
        names = Enum.map_join(modules, ", ", &ZippikerWeb.Modules.name/1)
        log(socket, :modules_changed, "Modules: #{names}; seats: #{seat_limit || "unlimited"}")
        {:noreply, socket |> put_flash(:info, "Modules and seats saved") |> load()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("generate_invoice", _params, socket) do
    case Platform.generate_billing_invoice(socket.assigns.team_id,
           actor: socket.assigns.current_user
         ) do
      {:ok, invoice} ->
        log(socket, :billing_invoice_generated, "Billed #{invoice.number}")
        {:noreply, socket |> put_flash(:info, "Invoice #{invoice.number} created") |> load()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    actor = [actor: socket.assigns.current_user]

    invoice =
      id
      |> Platform.get_billing_invoice!(actor)
      |> Platform.mark_billing_invoice_paid!(%{}, actor)

    log(socket, :billing_invoice_paid, "#{invoice.number} paid")
    {:noreply, socket |> put_flash(:info, "#{invoice.number} marked paid") |> load()}
  end

  def handle_event("void_invoice", %{"id" => id}, socket) do
    actor = [actor: socket.assigns.current_user]
    id |> Platform.get_billing_invoice!(actor) |> Platform.void_billing_invoice!(actor)
    {:noreply, socket |> put_flash(:info, "Invoice voided") |> load()}
  end

  defp load(socket) do
    actor = [actor: socket.assigns.current_user]
    id = socket.assigns.team_id
    team = Accounts.get_organization!(id, actor ++ [load: [:members_count]])
    tenant = [tenant: team, authorize?: false]

    usage = [
      {"Contacts & companies", Ash.count!(Zippiker.Parties.Party, tenant)},
      {"Deals", Ash.count!(Zippiker.Crm.Deal, tenant)},
      {"Invoices", Ash.count!(Zippiker.Sales.Invoice, tenant)},
      {"Journal entries", Ash.count!(Zippiker.Accounting.JournalEntry, tenant)}
    ]

    socket
    |> assign(page_title: team.name, team: team, usage: usage)
    |> assign(:subscription, Platform.ensure_subscription!(id, actor))
    |> stream(:members, Accounts.list_members!(id, actor), reset: true)
    |> stream(:invoices, Platform.list_billing_invoices!(%{organization_id: id}, actor),
      reset: true
    )
    |> stream(
      :events,
      Platform.list_audit_events!(%{organization_id: id}, actor ++ [page: [limit: 10]]).results,
      reset: true
    )
  end

  defp log(socket, action, summary) do
    Platform.log_event!(
      %{action: action, summary: summary, organization_id: socket.assigns.team_id},
      actor: socket.assigns.current_user
    )
  end

  defp plan_label(plan) do
    price = amount(plan.price_per_seat, plan.currency)
    if plan.active?, do: "#{plan.name} · #{price}/seat", else: "#{plan.name} (retired)"
  end
end
