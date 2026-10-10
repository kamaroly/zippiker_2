defmodule Zippiker.Inventory do
  @moduledoc """
  Stock: warehouses and stock operations (receipts, deliveries, adjustments)
  made of signed movements. Products keep a weighted average cost, and every
  operation posts its value to the books (`Zippiker.Accounting`).
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Inventory.Warehouse do
      define :list_warehouses, action: :list
      define :get_warehouse, action: :read, get_by: [:id]
      define :create_warehouse, action: :create
      define :update_warehouse, action: :update
      define :default_warehouse, action: :default
    end

    resource Zippiker.Inventory.StockOperation do
      define :list_stock_operations, action: :search
      define :get_stock_operation, action: :read, get_by: [:id]
      define :record_stock_operation, action: :record
      define :adjust_stock, action: :adjust
      define :reverse_stock_operation, action: :reverse, args: [:operation_id]
    end

    resource Zippiker.Inventory.StockMovement do
      define :product_movements, action: :for_product, args: [:product_id]
    end

    resource Zippiker.Inventory.Reports do
      define :inventory_summary, action: :summary
      define :stock_levels, action: :levels
    end
  end
end
