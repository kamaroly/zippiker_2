defmodule Zippiker.Purchasing.BillPayment.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Purchasing.BillPayment.{Changes, Validations}
  alias Zippiker.Purchasing.Changes.PostToLedger

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:bill_id, :amount, :paid_on, :method, :reference]
      change relate_actor(:recorded_by, allow_nil?: true)
      validate Validations.FitsBill
      change Changes.UpdateBill
      change {PostToLedger, event: :payment_recorded}
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change Changes.UpdateBill
      change {PostToLedger, event: :payment_removed}
    end
  end
end
