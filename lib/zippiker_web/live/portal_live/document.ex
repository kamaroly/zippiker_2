defmodule ZippikerWeb.PortalLive.Document do
  @moduledoc """
  One document in the portal: customers accept or decline quotes and see
  orders and invoices; suppliers price requests for quotation, acknowledge
  purchase orders and follow their bills.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Portal

  @types ~w(quote sales_order invoice rfq purchase_order bill)

  @impl true
  def mount(%{"access_id" => access_id, "type" => type, "id" => id}, _session, socket) do
    access = Enum.find(socket.assigns.portal_accesses, &(&1.id == access_id))

    with true <- type in @types and not is_nil(access),
         type = String.to_existing_atom(type),
         {:ok, document} <-
           Portal.portal_document(access_id, type, id, actor: socket.assigns.current_user) do
      {:ok,
       assign(socket, access: access, type: type, document: document, page_title: document.number)}
    else
      _ ->
        {:ok, socket |> put_flash(:error, "Document not found") |> push_navigate(to: ~p"/portal")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("respond", %{"decision" => decision}, socket)
      when decision in ["accept", "decline"] do
    %{access: access, document: quote} = socket.assigns

    case Portal.respond_to_quote(access.id, quote.id, String.to_existing_atom(decision),
           actor: socket.assigns.current_user
         ) do
      {:ok, _quote} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(decision == "accept", do: "Quote accepted — thank you!", else: "Quote declined")
         )
         |> reload()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("submit_prices", %{"prices" => prices} = params, socket) do
    %{access: access, document: rfq} = socket.assigns

    case Portal.submit_rfq_prices(access.id, rfq.id, prices, %{reference: params["reference"]},
           actor: socket.assigns.current_user
         ) do
      {:ok, _rfq} -> {:noreply, socket |> put_flash(:info, "Your prices were sent") |> reload()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("acknowledge", _params, socket) do
    %{access: access, document: order} = socket.assigns

    case Portal.acknowledge_purchase_order(access.id, order.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _order} -> {:noreply, socket |> put_flash(:info, "Order acknowledged") |> reload()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp reload(socket) do
    %{access: access, type: type, document: document} = socket.assigns

    assign(
      socket,
      :document,
      Portal.portal_document!(access.id, type, document.id, actor: socket.assigns.current_user)
    )
  end

  defp price(%{unit_price: %Decimal{} = price}), do: Decimal.to_string(price, :normal)
  defp price(_line), do: ""
end
