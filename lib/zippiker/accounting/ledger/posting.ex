defmodule Zippiker.Accounting.Ledger.Posting do
  @moduledoc "Shared plumbing for posting rules: post once per source, create the entry."

  require Ash.Query

  alias Zippiker.Accounting.JournalEntry

  @doc "Returns the existing (unreversed original) entry for the source, or runs `fun`."
  def once(source, source_id, opts, fun) do
    case original(source, source_id, opts) do
      nil -> fun.()
      entry -> {:ok, entry}
    end
  end

  @doc "The original entry posted for a source document, if any."
  def original(source, source_id, opts) do
    JournalEntry
    |> Ash.Query.filter(source == ^source and source_id == ^source_id and is_nil(reversal_of_id))
    |> Ash.Query.load(:reversal)
    |> Ash.read_one!(opts)
  end

  @doc "Sums `{account_id, amount}` pairs per account (amounts may be negative)."
  def net_by_account(pairs) do
    pairs
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {account, amounts} ->
      {account, Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2)}
    end)
  end

  @doc "Journal lines from net amounts: positive → debit, negative → credit, zero dropped."
  def lines(nets, description) do
    for {account, amount} <- nets, not Decimal.eq?(amount, 0) do
      if Decimal.gt?(amount, 0),
        do: %{account_id: account, debit: amount, description: description},
        else: %{account_id: account, credit: Decimal.abs(amount), description: description}
    end
  end

  def post(params, opts) do
    JournalEntry
    |> Ash.Changeset.for_create(:post, params, opts)
    |> Ash.create(authorize?: Keyword.get(opts, :authorize?, true))
  end
end
