defmodule Zippiker.Fixtures do
  @moduledoc "Builders for tests: a user, their organization and a seeded pipeline."

  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email, "user#{System.unique_integer([:positive])}@example.com")

    Zippiker.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  @doc "Returns `{user, organization}` where `user` is the owner with memberships loaded."
  def workspace_fixture(attrs \\ %{}) do
    user = user_fixture()

    organization =
      Zippiker.Accounts.create_organization!(
        Map.merge(%{name: "Acme Inc", currency: "USD"}, attrs),
        actor: user
      )

    user = Ash.load!(user, :memberships, authorize?: false)
    Zippiker.Crm.seed_crm_defaults!(tenant: organization, actor: user)
    {user, organization}
  end

  def member_fixture(organization, role \\ :member) do
    user = user_fixture()

    Zippiker.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      organization_id: organization.id,
      role: role
    })
    |> Ash.create!(authorize?: false)

    Ash.load!(user, :memberships, authorize?: false)
  end

  @doc "A platform super admin (no workspace)."
  def super_admin_fixture do
    user_fixture() |> Zippiker.Accounts.set_super_admin!(true, authorize?: false)
  end

  def plan_fixture(attrs \\ %{}) do
    Zippiker.Platform.Plan
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          code: "plan#{System.unique_integer([:positive])}",
          name: "Growth",
          price_per_seat: Decimal.new(12),
          seat_limit: 10
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  def stage(organization, name) do
    [pipeline | _] = Zippiker.Crm.list_pipelines!(tenant: organization, authorize?: false)
    Enum.find(pipeline.stages, &(&1.name == name))
  end
end
