defmodule Zippiker.Accounts.LegalEntity.Validations.OwnLogo do
  @moduledoc "A logo path must be one stored for this workspace's logos."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    path = Ash.Changeset.get_argument(changeset, :logo_path) || ""
    organization_id = Zippiker.Accounts.Tenant.organization_id(changeset.tenant)

    if String.starts_with?(path, "#{organization_id}/logos/") and not String.contains?(path, ".."),
      do: :ok,
      else: {:error, field: :logo_path, message: "is not a logo of this workspace"}
  end
end
