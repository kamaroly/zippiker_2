defmodule ZippikerWeb.Platform.BillingLive do
  @moduledoc "Every platform invoice across workspaces; collect (mark paid) or void."
  use ZippikerWeb, :live_view

  alias Zippiker.Platform

  @statuses ~w(open paid void)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Billing")}

  @impl true
  def handle_params(params, _url, socket) do
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Platform.list_billing_invoices!(%{status: status},
        actor: socket.assigns.current_user,
        page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]
      )

    {:noreply,
     socket
     |> assign(status: status, page: page)
     |> stream(:invoices, page.results, reset: true)}
  end

  @impl true
  def handle_event("mark_paid", %{"id" => id}, socket) do
    actor = [actor: socket.assigns.current_user]

    invoice =
      id
      |> Platform.get_billing_invoice!(actor)
      |> Platform.mark_billing_invoice_paid!(%{}, actor)

    Platform.log_event!(
      %{
        action: :billing_invoice_paid,
        summary: "#{invoice.number} paid",
        organization_id: invoice.organization_id
      },
      actor
    )

    {:noreply,
     socket
     |> put_flash(:info, "#{invoice.number} marked paid")
     |> stream_insert(:invoices, Ash.load!(invoice, :organization, actor))}
  end

  defp billing_path(params), do: query_path(~p"/platform/billing", params)
end
