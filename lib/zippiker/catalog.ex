defmodule Zippiker.Catalog do
  @moduledoc "What the business sells (and later buys and stocks): products, services and tax rates."
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Catalog.TaxRate do
      define :list_tax_rates, action: :list
      define :get_tax_rate, action: :read, get_by: [:id]
      define :create_tax_rate, action: :create
      define :update_tax_rate, action: :update
      define :archive_tax_rate, action: :destroy
    end

    resource Zippiker.Catalog.Product do
      define :list_products, action: :search
      define :get_product, action: :read, get_by: [:id]
      define :create_product, action: :create
      define :update_product, action: :update
      define :archive_product, action: :destroy
    end
  end
end
