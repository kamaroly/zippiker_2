defmodule ZippikerWeb.AccountingLive.Entry do
  @moduledoc "A journal entry with its lines, source document and reversal."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, load(socket, id)}
  end

  @impl true
  def handle_event("reverse", _params, socket) do
    case Accounting.reverse_journal_entry(socket.assigns.entry.id, ash_opts(socket)) do
      {:ok, reversal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reversed with #{reversal.number}")
         |> push_navigate(to: ~p"/accounting/journal/#{reversal}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket, id) do
    entry =
      Accounting.get_journal_entry!(
        id,
        ash_opts(socket) ++
          [load: [:posted_by, :reversal, :reversal_of, :legal_entity, lines: [:account, :party]]]
      )

    assign(socket, entry: entry, page_title: entry.number)
  end

  # Automatic entries are undone from their document (void the invoice, remove the payment).
  defp reversible?(entry, assigns) do
    can?(assigns, "journal.reverse") and is_nil(entry.reversal) and is_nil(entry.reversal_of_id) and
      entry.source in [:manual, :expense]
  end

  defp source_path(%{source: :invoice, source_id: id}), do: ~p"/invoices/#{id}"
  defp source_path(_entry), do: nil
end
