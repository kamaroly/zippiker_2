defmodule Zippiker.Accounting.JournalEntry.Changes.BuildExpense do
  @moduledoc """
  Turns the expense form (expense account, paid from, amount) into two lines:
  debit the expense, credit the cash/bank (or card liability) account.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    opts = [tenant: changeset.tenant, authorize?: false]
    expense_id = Ash.Changeset.get_argument(changeset, :expense_account_id)
    paid_from_id = Ash.Changeset.get_argument(changeset, :paid_from_account_id)
    amount = Ash.Changeset.get_argument(changeset, :amount)

    with {:expense, {:ok, %{type: :expense}}} <-
           {:expense, Zippiker.Accounting.get_account(expense_id, opts)},
         {:paid_from, {:ok, %{type: type}}} when type in [:asset, :liability] <-
           {:paid_from, Zippiker.Accounting.get_account(paid_from_id, opts)} do
      memo = Ash.Changeset.get_attribute(changeset, :memo)

      changeset
      |> Ash.Changeset.force_change_attribute(:source, :expense)
      |> Ash.Changeset.force_set_argument(:lines, [
        %{
          account_id: expense_id,
          debit: amount,
          credit: 0,
          description: memo,
          party_id: Ash.Changeset.get_argument(changeset, :party_id)
        },
        %{account_id: paid_from_id, debit: 0, credit: amount, description: memo}
      ])
    else
      {:expense, _} ->
        Ash.Changeset.add_error(changeset,
          field: :expense_account_id,
          message: "pick an expense account"
        )

      {:paid_from, _} ->
        Ash.Changeset.add_error(changeset,
          field: :paid_from_account_id,
          message: "pick a cash, bank or card account"
        )
    end
  end
end
