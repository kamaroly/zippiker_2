defimpl Ash.ToTenant, for: Zippiker.Accounts.Organization do
  def to_tenant(%{id: id}, _resource), do: id
end
