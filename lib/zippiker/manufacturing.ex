defmodule Zippiker.Manufacturing do
  @moduledoc """
  Production: work centers (where work happens, at an hourly rate), bills of
  materials (what a product is made of and the operations to make it) and
  production orders that consume components from stock and receive the
  finished goods at cost (components + labour/overhead), in one or more runs.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Manufacturing.WorkCenter do
      define :list_work_centers, action: :list
      define :get_work_center, action: :read, get_by: [:id]
      define :create_work_center, action: :create
      define :update_work_center, action: :update
      define :delete_work_center, action: :destroy
    end

    resource Zippiker.Manufacturing.BillOfMaterials do
      define :list_boms, action: :search
      define :get_bom, action: :read, get_by: [:id]
      define :create_bom, action: :create
      define :update_bom, action: :update
      define :delete_bom, action: :destroy
    end

    resource Zippiker.Manufacturing.BomComponent
    resource Zippiker.Manufacturing.BomOperation

    resource Zippiker.Manufacturing.ProductionOrder do
      define :list_production_orders, action: :search
      define :get_production_order, action: :read, get_by: [:id]
      define :create_production_order, action: :create
      define :update_production_order, action: :update
      define :confirm_production_order, action: :confirm
      define :record_production, action: :record_output, args: [:quantity]
      define :finish_production_order, action: :finish
      define :cancel_production_order, action: :cancel
    end
  end
end
