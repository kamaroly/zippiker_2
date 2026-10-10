defmodule Zippiker.Parties do
  @moduledoc """
  The shared directory of people and organizations. CRM contacts and companies
  today; customers, suppliers and employees as more modules are added. Modules
  keep their role-specific data in their own resources pointing at a party.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.Parties.Party do
      define :list_parties, action: :search, args: [:kind]
      define :get_party, action: :read, get_by: [:id]
      define :create_party, action: :create
      define :update_party, action: :update
      define :archive_party, action: :destroy
    end

    resource Zippiker.Parties.Address do
      define :list_addresses, action: :for_party, args: [:party_id]
      define :create_address, action: :create
      define :update_address, action: :update
      define :delete_address, action: :destroy
    end
  end
end
