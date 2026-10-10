defmodule ZippikerWeb.BillLive.Show do
  @moduledoc "A supplier bill: approve, pay (one or more payments), void or delete a draft."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @loads [
    :purchase_order,
    :owner,
    :amount_due,
    :overdue?,
    :supplier,
    lines: [:expense_account, :product],
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
    case Purchasing.get_bill(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, bill} ->
        {:ok,
         socket
         |> assign(bill: bill, page_title: bill.number, methods: @methods)
         |> assign(:receipts, receipts(bill, socket))}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Bill not found") |> push_navigate(to: ~p"/bills")}
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
  def handle_event("approve", _params, socket),
    do: run(socket, &Purchasing.approve_bill/2, "Bill approved")

  def handle_event("void", _params, socket),
    do: run(socket, &Purchasing.void_bill/2, "Bill voided")

  def handle_event("delete", _params, socket) do
    case Purchasing.delete_draft_bill(socket.assigns.bill, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Draft deleted") |> push_navigate(to: ~p"/bills")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("save_payment", %{"payment" => params}, socket) do
    params =
      params
      |> Map.put("bill_id", socket.assigns.bill.id)
      |> put_money("amount", %{currency: socket.assigns.bill.currency})

    case AshPhoenix.Form.submit(socket.assigns.payment_form, params: params) do
      {:ok, _payment} ->
        {:noreply,
         socket
         |> reload()
         |> put_flash(:info, "Payment recorded")
         |> push_patch(to: ~p"/bills/#{socket.assigns.bill}")}

      {:error, form} ->
        {:noreply, assign(socket, :payment_form, form)}
    end
  end

  def handle_event("delete_payment", %{"id" => id}, socket) do
    payment = Enum.find(socket.assigns.bill.payments, &(&1.id == id))
    if payment, do: Purchasing.delete_bill_payment!(payment, ash_opts(socket))
    {:noreply, socket |> reload() |> put_flash(:info, "Payment removed")}
  end

  defp run(socket, fun, message) do
    case fun.(socket.assigns.bill, ash_opts(socket)) do
      {:ok, _bill} -> {:noreply, socket |> reload() |> put_flash(:info, message)}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  # Goods received for this bill: on its purchase order, or brought in by the bill itself.
  defp receipts(bill, socket) do
    filter =
      if bill.purchase_order_id,
        do: %{purchase_order_id: bill.purchase_order_id},
        else: %{bill_id: bill.id}

    Purchasing.list_goods_receipts!(filter, ash_opts(socket)) |> Enum.sort_by(& &1.number)
  end

  defp reload(socket) do
    bill = Purchasing.get_bill!(socket.assigns.bill.id, ash_opts(socket) ++ [load: @loads])
    assign(socket, bill: bill, receipts: receipts(bill, socket))
  end

  defp assign_payment_form(socket) do
    form =
      Purchasing.BillPayment
      |> AshPhoenix.Form.for_create(:create,
        as: "payment",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "amount" => money_input(socket.assigns.bill.amount_due),
          "paid_on" => Date.to_iso8601(Date.utc_today())
        }
      )
      |> to_form()

    assign(socket, :payment_form, form)
  end
end
