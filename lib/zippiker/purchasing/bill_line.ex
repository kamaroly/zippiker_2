defmodule Zippiker.Purchasing.BillLine do
  @moduledoc """
  A line on a bill. `expense_account_id` says what was bought (rent,
  software…) for lines that aren't stock; lines copied from a purchase order
  carry `received_unit_cost`.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Purchasing.BillLine.Attributes,
      Zippiker.Purchasing.BillLine.Relationships,
      Zippiker.Purchasing.BillLine.Actions,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "bill_lines"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :bill, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
      reference :expense_account, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
