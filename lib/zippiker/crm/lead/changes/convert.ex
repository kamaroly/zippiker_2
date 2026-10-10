defmodule Zippiker.Crm.Lead.Changes.Convert do
  @moduledoc """
  Converts a lead inside the action's transaction:

    1. matches an existing company by name, or creates one
    2. creates the contact, employed by that company
    3. optionally creates a deal in the first open stage
    4. moves the lead's activities and tasks onto the new contact
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Zippiker.Crm.{Activity, Deal, Stage, Task}
  alias Zippiker.Parties

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.before_action(&convert(&1, context))
    |> Ash.Changeset.after_action(&move_history(&1, &2, context))
  end

  defp convert(changeset, context) do
    opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]
    create_deal? = Ash.Changeset.get_argument(changeset, :create_deal?)

    case create_deal? && first_open_stage(opts) do
      nil ->
        Ash.Changeset.add_error(changeset,
          field: :create_deal?,
          message: "add an open pipeline stage before creating deals"
        )

      stage ->
        do_convert(changeset, stage, opts)
    end
  end

  defp do_convert(changeset, stage, opts) do
    lead = changeset.data
    company = find_or_create_company(lead, opts)

    person =
      Parties.create_party!(
        %{
          kind: :person,
          first_name: lead.first_name,
          last_name: lead.last_name,
          email: lead.email,
          phone: lead.phone,
          job_title: lead.job_title,
          employer_id: company && company.id,
          owner_id: lead.owner_id,
          roles: [:lead]
        },
        opts
      )

    if stage, do: create_deal!(changeset, stage, lead, person, company, opts)

    Ash.Changeset.force_change_attributes(changeset, %{
      status: :converted,
      converted_at: DateTime.utc_now(),
      party_id: person.id,
      company_id: company && company.id
    })
  end

  defp first_open_stage(opts) do
    Stage
    |> Ash.Query.filter(kind == :open)
    |> Ash.Query.sort(pipeline_id: :asc, position: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(opts)
  end

  defp find_or_create_company(%{company_name: name}, _opts) when name in [nil, ""], do: nil

  defp find_or_create_company(lead, opts) do
    name = String.trim(lead.company_name)

    Parties.Party
    |> Ash.Query.filter(
      kind == :organization and fragment("lower(?)", name) == ^String.downcase(name)
    )
    |> Ash.Query.limit(1)
    |> Ash.read_one!(opts)
    |> case do
      nil ->
        Parties.create_party!(
          %{kind: :organization, name: name, owner_id: lead.owner_id, roles: [:lead]},
          opts
        )

      company ->
        company
    end
  end

  defp create_deal!(changeset, stage, lead, person, company, opts) do
    Deal
    |> Ash.Changeset.for_create(
      :create,
      %{
        title: Ash.Changeset.get_argument(changeset, :deal_title) || default_title(lead),
        amount: amount(Ash.Changeset.get_argument(changeset, :deal_amount), changeset.tenant),
        stage_id: stage.id,
        party_id: person.id,
        company_id: company && company.id,
        owner_id: lead.owner_id,
        lead_id: lead.id
      },
      opts
    )
    |> Ash.create!()
  end

  defp default_title(%{company_name: company}) when company not in [nil, ""],
    do: "#{company} deal"

  defp default_title(lead), do: "#{lead.name} deal"

  defp amount(nil, _tenant), do: nil

  defp amount(value, tenant) do
    organization =
      Zippiker.Accounts.get_organization!(Ash.ToTenant.to_tenant(tenant, nil), authorize?: false)

    Money.new!(organization.currency, value)
  end

  defp move_history(changeset, lead, context) do
    opts = [
      tenant: changeset.tenant,
      actor: context.actor,
      authorize?: false,
      strategy: [:atomic, :stream]
    ]

    for resource <- [Activity, Task] do
      resource
      |> Ash.Query.filter(lead_id == ^lead.id)
      |> Ash.bulk_update!(:reassign, %{party_id: lead.party_id}, opts)
    end

    {:ok, lead}
  end
end
