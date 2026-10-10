defmodule Zippiker.Platform.BillingInvoice do
  @moduledoc """
  What the platform bills a workspace for one period: seats × plan price.
  Numbered from a global sequence (`ZPK-000001`).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Platform.BillingInvoice.Attributes,
      Zippiker.Platform.BillingInvoice.Relationships,
      Zippiker.Platform.BillingInvoice.Actions,
      Zippiker.Platform.BillingInvoice.Policies
    ]

  postgres do
    table "billing_invoices"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_period: "status != 'void'"

    references do
      reference :organization, on_delete: :delete
    end

    custom_statements do
      statement :billing_invoice_numbers do
        up "CREATE SEQUENCE IF NOT EXISTS billing_invoice_numbers"
        down "DROP SEQUENCE IF EXISTS billing_invoice_numbers"
      end
    end
  end

  identities do
    identity :unique_number, [:number]
    identity :unique_period, [:organization_id, :period_start], where: expr(status != :void)
  end
end
