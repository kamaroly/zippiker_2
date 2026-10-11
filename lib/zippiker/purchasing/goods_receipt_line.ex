defmodule Zippiker.Purchasing.GoodsReceiptLine do
  @moduledoc "One item on a goods received note."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Purchasing.GoodsReceiptLine.Attributes,
      Zippiker.Purchasing.GoodsReceiptLine.Relationships,
      Zippiker.Purchasing.GoodsReceiptLine.Actions,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "goods_receipt_lines"
    repo Zippiker.Repo

    references do
      reference :goods_receipt, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :purchase_order_line, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
