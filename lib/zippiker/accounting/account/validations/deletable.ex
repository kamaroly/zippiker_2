defmodule Zippiker.Accounting.Account.Validations.Deletable do
  @moduledoc "System accounts and accounts with postings can't be deleted (deactivate them instead)."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    account = Ash.load!(changeset.data, :used?, tenant: changeset.tenant, authorize?: false)

    cond do
      account.system_key -> {:error, message: "automatic postings use this account"}
      account.used? -> {:error, message: "this account has postings; deactivate it instead"}
      true -> :ok
    end
  end
end
