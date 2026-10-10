defmodule Zippiker.Purchasing do
  @moduledoc """
  Buying: purchase orders to suppliers, receiving goods into stock, supplier
  bills and paying them. Suppliers are `Zippiker.Parties` parties; lines reuse
  the sales document line fields and pricing.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.Purchasing.Rfq do
      define :list_rfqs, action: :search
      define :get_rfq, action: :read, get_by: [:id]
      define :create_rfq, action: :create
      define :update_rfq, action: :update
      define :send_rfq, action: :mark_sent
      define :mark_rfq_quoted, action: :mark_quoted
      define :accept_rfq, action: :accept
      define :decline_rfq, action: :decline
      define :reopen_rfq, action: :reopen
    end

    resource Zippiker.Purchasing.RfqLine

    resource Zippiker.Purchasing.PurchaseOrder do
      define :list_purchase_orders, action: :search
      define :get_purchase_order, action: :read, get_by: [:id]
      define :create_purchase_order, action: :create
      define :order_rfq, action: :from_rfq, args: [:rfq_id]
      define :update_purchase_order, action: :update
      define :place_purchase_order, action: :mark_ordered
      define :receive_purchase_order, action: :receive
      define :cancel_purchase_order, action: :cancel
    end

    resource Zippiker.Purchasing.PurchaseOrderLine

    resource Zippiker.Purchasing.GoodsReceipt do
      define :list_goods_receipts, action: :search
      define :get_goods_receipt, action: :read, get_by: [:id]
      define :record_goods_receipt, action: :record
    end

    resource Zippiker.Purchasing.GoodsReceiptLine

    resource Zippiker.Purchasing.Bill do
      define :list_bills, action: :search
      define :get_bill, action: :read, get_by: [:id]
      define :create_bill, action: :create
      define :bill_purchase_order, action: :from_purchase_order, args: [:purchase_order_id]
      define :update_bill, action: :update
      define :approve_bill, action: :approve
      define :void_bill, action: :void
      define :delete_draft_bill, action: :destroy
    end

    resource Zippiker.Purchasing.BillLine

    resource Zippiker.Purchasing.BillPayment do
      define :record_bill_payment, action: :create
      define :delete_bill_payment, action: :destroy
    end

    resource Zippiker.Purchasing.Reports do
      define :payables_summary, action: :summary
    end
  end
end
