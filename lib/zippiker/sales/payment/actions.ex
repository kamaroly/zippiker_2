defmodule Zippiker.Sales.Payment.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Payment.{Changes, Validations}

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:invoice_id, :amount, :paid_on, :method, :reference]
      change relate_actor(:recorded_by, allow_nil?: true)
      validate Validations.FitsInvoice
      change Changes.UpdateInvoice
      change {Zippiker.Sales.Changes.PostToLedger, event: :payment_recorded}
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change Changes.UpdateInvoice
      change {Zippiker.Sales.Changes.PostToLedger, event: :payment_removed}
    end
  end
end
