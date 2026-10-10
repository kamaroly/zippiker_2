defmodule ZippikerWeb.QuoteLive.Show do
  @moduledoc "A quote: the document plus its workflow (send, accept, decline, invoice)."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @loads [
    :legal_entity,
    :lines,
    :contact,
    :deal,
    :invoice,
    :sales_order,
    :owner,
    customer: [:addresses]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Sales.get_quote(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, quote} ->
        {:ok, assign(socket, quote: quote, page_title: quote.number)}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Quote not found") |> push_navigate(to: ~p"/quotes")}
    end
  end

  @impl true
  def handle_event("transition", %{"to" => to}, socket) do
    action =
      %{
        "sent" => &Sales.send_quote/2,
        "accepted" => &Sales.accept_quote/2,
        "declined" => &Sales.decline_quote/2,
        "draft" => &Sales.reopen_quote/2
      }[to]

    case action && action.(socket.assigns.quote, ash_opts(socket)) do
      {:ok, quote} ->
        quote = Ash.load!(quote, @loads, ash_opts(socket))

        {:noreply,
         socket |> assign(:quote, quote) |> put_flash(:info, "Quote marked #{quote.status}")}

      _ ->
        {:noreply, put_flash(socket, :error, "That change isn't allowed right now")}
    end
  end

  def handle_event("invoice", _params, socket) do
    case Sales.invoice_quote(socket.assigns.quote.id, ash_opts(socket)) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft invoice created")
         |> push_navigate(to: ~p"/invoices/#{invoice}")}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, error |> Ash.Error.to_error_class() |> Exception.message())}
    end
  end

  def handle_event("order", _params, socket) do
    case Sales.order_quote(socket.assigns.quote.id, ash_opts(socket)) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft order created")
         |> push_navigate(to: ~p"/orders/#{order}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("archive", _params, socket) do
    case Sales.archive_quote(socket.assigns.quote, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Quote archived") |> push_navigate(to: ~p"/quotes")}

      _ ->
        {:noreply, put_flash(socket, :error, "Only draft or declined quotes can be archived")}
    end
  end
end
