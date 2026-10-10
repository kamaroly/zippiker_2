defmodule Zippiker.Sales do
  @moduledoc """
  Quotes, invoices and payments. Documents belong to a legal entity, bill a
  party (`Zippiker.Parties`) and can link back to a CRM deal.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.Sales.Quote do
      define :list_quotes, action: :search
      define :get_quote, action: :read, get_by: [:id]
      define :create_quote, action: :create
      define :update_quote, action: :update
      define :send_quote, action: :mark_sent
      define :accept_quote, action: :accept
      define :decline_quote, action: :decline
      define :reopen_quote, action: :reopen
      define :archive_quote, action: :destroy
    end

    resource Zippiker.Sales.QuoteLine

    resource Zippiker.Sales.SalesOrder do
      define :list_sales_orders, action: :search
      define :get_sales_order, action: :read, get_by: [:id]
      define :create_sales_order, action: :create
      define :order_quote, action: :from_quote, args: [:quote_id]
      define :update_sales_order, action: :update
      define :confirm_sales_order, action: :confirm
      define :deliver_sales_order, action: :deliver
      define :cancel_sales_order, action: :cancel
    end

    resource Zippiker.Sales.SalesOrderLine

    resource Zippiker.Sales.Delivery do
      define :list_deliveries, action: :search
      define :get_delivery, action: :read, get_by: [:id]
      define :record_delivery, action: :record
      define :update_delivery, action: :update
      define :confirm_delivery, action: :confirm
    end

    resource Zippiker.Sales.DeliveryLine

    resource Zippiker.Sales.Invoice do
      define :list_invoices, action: :search
      define :get_invoice, action: :read, get_by: [:id]
      define :create_invoice, action: :create
      define :invoice_quote, action: :from_quote, args: [:quote_id]
      define :invoice_sales_order, action: :from_sales_order, args: [:sales_order_id]
      define :update_invoice, action: :update
      define :issue_invoice, action: :issue
      define :void_invoice, action: :void
      define :delete_draft_invoice, action: :destroy
    end

    resource Zippiker.Sales.InvoiceLine

    resource Zippiker.Sales.Payment do
      define :record_payment, action: :create
      define :delete_payment, action: :destroy
    end

    resource Zippiker.Sales.Reports do
      define :sales_summary, action: :summary
    end
  end
end
