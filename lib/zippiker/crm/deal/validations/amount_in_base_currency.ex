defmodule Zippiker.Crm.Deal.Validations.AmountInBaseCurrency do
  @moduledoc """
  Deal amounts use the organization's base currency so pipeline totals can be
  summed in the database. Multi-currency arrives with exchange rates.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    with true <- Ash.Changeset.changing_attribute?(changeset, :amount),
         %Money{currency: currency} <- Ash.Changeset.get_attribute(changeset, :amount),
         {:ok, organization} <-
           Zippiker.Accounts.get_organization(Ash.ToTenant.to_tenant(changeset.tenant, nil),
             authorize?: false
           ),
         false <- to_string(currency) == organization.currency do
      {:error, field: :amount, message: "must be in #{organization.currency}"}
    else
      _ -> :ok
    end
  end
end
