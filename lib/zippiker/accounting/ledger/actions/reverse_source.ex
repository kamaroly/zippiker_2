defmodule Zippiker.Accounting.Ledger.Actions.ReverseSource do
  @moduledoc "Invoice voided or payment removed: reverse its entry (once)."
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.Posting

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    case Posting.original(input.arguments.source, input.arguments.source_id, opts) do
      %{reversal: nil} = entry ->
        with {:ok, _reversal} <-
               Zippiker.Accounting.reverse_journal_entry(entry.id, opts ++ [actor: context.actor]) do
          :ok
        end

      _nothing_to_reverse ->
        :ok
    end
  end
end
