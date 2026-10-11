defmodule Zippiker.Portal do
  @moduledoc """
  The customer and supplier portals: outside people (with a
  `Zippiker.Accounts.PortalAccess`) see and act on their own documents. Every
  action checks the actor's access and only ever reads that party's records.
  """
  use Ash.Domain, otp_app: :zippiker

  resources do
    resource Zippiker.Portal.Documents do
      define :portal_overview, action: :overview, args: [:access_id]
      define :portal_document, action: :document, args: [:access_id, :type, :id]

      define :respond_to_quote,
        action: :respond_to_quote,
        args: [:access_id, :quote_id, :decision]

      define :submit_rfq_prices, action: :submit_rfq_prices, args: [:access_id, :rfq_id, :prices]

      define :acknowledge_purchase_order,
        action: :acknowledge_purchase_order,
        args: [:access_id, :purchase_order_id]
    end
  end
end
