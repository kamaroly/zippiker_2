defmodule Zippiker.Extensibility do
  @moduledoc """
  Tenant-defined custom fields for any resource using the
  `Zippiker.Extensibility.CustomFields` extension.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Extensibility.CustomFieldDefinition do
      define :list_custom_fields, action: :for_entity, args: [:entity]
      define :list_all_custom_fields, action: :read
      define :get_custom_field, action: :read, get_by: [:id]
      define :create_custom_field, action: :create
      define :update_custom_field, action: :update
      define :archive_custom_field, action: :destroy
    end
  end
end
