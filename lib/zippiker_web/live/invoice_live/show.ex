defmodule ZippikerWeb.InvoiceLive.Show do
  @moduledoc "An invoice: the document, issue/void, and the payments received."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @loads [
    :legal_entity,
    :lines,
    :contact,
    :deal,
    :quote,
    :sales_order,
    :owner,
    :amount_due,
    :overdue?,
    customer: [:addresses],
    payments: [:recorded_by]
  ]

  @methods [
    {"Bank transfer", "bank_transfer"},
    {"Card", "card"},
    {"Cash", "cash"},
    {"Mobile money", "mobile_money"},
    {"Cheque", "cheque"},
    {"Other", "other"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Sales.get_invoice(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, invoice} ->
        {:ok,
         assign(socket,
           deliveries: deliveries(invoice, socket),
           invoice: invoice,
           page_title: invoice.number || "Draft invoice",
           methods: @methods
         )}

      {:error, _} ->
        {:ok,
         socket |> put_flash(:error, "Invoice not found") |> push_navigate(to: ~p"/invoices")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     if(socket.assigns.live_action == :payment,
       do: assign_payment_form(socket),
       else: assign(socket, :payment_form, nil)
     )}
  end

  @impl true
  def handle_event("issue", _params, socket),
    do: run(socket, &Sales.issue_invoice/2, "Invoice issued")

  def handle_event("void", _params, socket),
    do: run(socket, &Sales.void_invoice/2, "Invoice voided")

  def handle_event("delete", _params, socket) do
    case Sales.delete_draft_invoice(socket.assigns.invoice, ash_opts(socket)) do
      :ok ->
        {:noreply,
         socket |> put_flash(:info, "Draft deleted") |> push_navigate(to: ~p"/invoices")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, message(error))}
    end
  end

  def handle_event("save_payment", %{"payment" => params}, socket) do
    params =
      params
      |> Map.put("invoice_id", socket.assigns.invoice.id)
      |> put_money("amount", %{currency: socket.assigns.invoice.currency})

    case AshPhoenix.Form.submit(socket.assigns.payment_form, params: params) do
      {:ok, _payment} ->
        {:noreply,
         socket
         |> reload()
         |> put_flash(:info, "Payment recorded")
         |> push_patch(to: ~p"/invoices/#{socket.assigns.invoice}")}

      {:error, form} ->
        {:noreply, assign(socket, :payment_form, form)}
    end
  end

  def handle_event("delete_payment", %{"id" => id}, socket) do
    payment = Enum.find(socket.assigns.invoice.payments, &(&1.id == id))
    if payment, do: Sales.delete_payment!(payment, ash_opts(socket))
    {:noreply, socket |> reload() |> put_flash(:info, "Payment removed")}
  end

  defp run(socket, fun, message) do
    case fun.(socket.assigns.invoice, ash_opts(socket)) do
      {:ok, _invoice} -> {:noreply, socket |> reload() |> put_flash(:info, message)}
      {:error, error} -> {:noreply, put_flash(socket, :error, message(error))}
    end
  end

  defp reload(socket) do
    invoice = Sales.get_invoice!(socket.assigns.invoice.id, ash_opts(socket) ++ [load: @loads])

    assign(socket,
      invoice: invoice,
      deliveries: deliveries(invoice, socket),
      page_title: invoice.number || "Draft invoice"
    )
  end

  # Notes for this invoice, and for the order it bills.
  defp deliveries(invoice, socket) do
    [
      %{invoice_id: invoice.id},
      invoice.sales_order_id && %{sales_order_id: invoice.sales_order_id}
    ]
    |> Enum.filter(& &1)
    |> Enum.flat_map(&Sales.list_deliveries!(&1, ash_opts(socket)))
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.number)
  end

  defp assign_payment_form(socket) do
    due = socket.assigns.invoice.amount_due

    form =
      Sales.Payment
      |> AshPhoenix.Form.for_create(:create,
        as: "payment",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"amount" => money_input(due), "paid_on" => Date.to_iso8601(Date.utc_today())}
      )
      |> to_form()

    assign(socket, :payment_form, form)
  end

  defp message(error), do: error |> Ash.Error.to_error_class() |> Exception.message()
end
