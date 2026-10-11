defmodule Zippiker.Purchasing.GoodsReceipt do
  @moduledoc """
  A goods received note (`GRN-2026-0001`): what arrived from a supplier, when,
  into which warehouse, against which purchase order (or bill) and with the
  supplier's delivery note number. Created whenever goods are received, in
  full or in part; stock-tracked lines also move stock (`stock_operation`).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Purchasing.GoodsReceipt.Attributes,
      Zippiker.Purchasing.GoodsReceipt.Relationships,
      Zippiker.Purchasing.GoodsReceipt.Actions,
      Zippiker.Purchasing.GoodsReceipt.Policies
    ]

  postgres do
    table "goods_receipts"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :restrict
      reference :supplier, on_delete: :restrict
      reference :purchase_order, on_delete: :nilify
      reference :bill, on_delete: :nilify
      reference :warehouse, on_delete: :nilify
      reference :received_by, on_delete: :nilify
      reference :stock_operation, on_delete: :nilify
    end

    custom_indexes do
      index [:received_on]
      index [:purchase_order_id]
    end
  end

  multitenancy do
    strategy :context
  end
end
