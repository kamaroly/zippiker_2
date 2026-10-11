defimpl Ash.ToTenant, for: Zippiker.Accounts.Organization do
  # Schema-per-tenant resources get the team's schema; the few
  # attribute-tenant resources (invitations) and plain lookups get its id.
  def to_tenant(organization, resource) do
    if resource && Ash.Resource.Info.multitenancy_strategy(resource) == :context,
      do: Zippiker.Accounts.Tenant.schema(organization),
      else: organization.id
  end
end
