defmodule Zippiker.Parties.Party.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Parties.Party.{Changes, Validations}

  @fields [
    :kind,
    :name,
    :first_name,
    :last_name,
    :job_title,
    :email,
    :phone,
    :website,
    :industry,
    :tax_id,
    :description,
    :roles,
    :tags,
    :employer_id,
    :owner_id,
    :custom_fields
  ]

  actions do
    defaults [:read]

    destroy :destroy do
      # Atomic unless maker-checker holds the change (see MakerChecker).
      require_atomic? false
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :contacts}
      primary? true
    end

    read :search do
      argument :kind, :atom, allow_nil?: false, constraints: [one_of: [:person, :organization]]
      argument :query, :string
      argument :role, :atom
      argument :employer_id, :uuid
      argument :custom_fields, :map

      filter expr(kind == ^arg(:kind))
      prepare Zippiker.Parties.Party.Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [name: :asc], load: [:employer, :owner])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept @fields
      change Changes.SetPersonName
      validate Validations.EmployerIsOrganization
    end

    update :update do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :contacts}
      primary? true
      accept @fields -- [:kind]
      require_atomic? false
      change Changes.SetPersonName
      validate Validations.EmployerIsOrganization
    end

    update :add_role do
      argument :role, :atom, allow_nil?: false
      change Changes.AddRole
    end
  end
end
