defmodule Zippiker.HR.Employee.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.Employee.{Changes, Validations}

  @fields [
    :user_id,
    :department_id,
    :manager_id,
    :leave_policy_id,
    :job_title,
    :employment_type,
    :hire_date,
    :salary,
    :pay_frequency,
    :date_of_birth,
    :national_id,
    :emergency_contact_name,
    :emergency_contact_phone,
    :notes,
    :custom_fields
  ]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :department_id, :uuid
      argument :manager_id, :uuid
      argument :status, :atom, constraints: [one_of: [:active, :terminated]]
      prepare Zippiker.HR.Employee.Preparations.Search

      prepare build(
                sort: [hire_date: :asc],
                load: [:name, :email, :on_leave_today?, :department, manager: [:name]]
              )

      pagination offset?: true, countable: true, default_limit: 50, required?: false
    end

    read :mine do
      description "The actor's own employee record."
      get? true
      filter expr(user_id == ^actor(:id))
    end

    create :create do
      primary? true
      accept [:legal_entity_id, :party_id | @fields]
      argument :first_name, :string, constraints: [max_length: 100]
      argument :last_name, :string, constraints: [max_length: 100]
      argument :email, :ci_string
      argument :phone, :string, constraints: [max_length: 40]

      change Zippiker.Sales.Changes.SetLegalEntity
      change Changes.CreateParty

      change {Zippiker.Sales.Changes.AssignNumber,
              document_type: :employee,
              prefix: "EMP",
              yearly?: false,
              number_field: :employee_number}

      validate Validations.ManagerChain
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:legal_entity_id | @fields]
      argument :first_name, :string, constraints: [max_length: 100]
      argument :last_name, :string, constraints: [max_length: 100]
      argument :email, :ci_string
      argument :phone, :string, constraints: [max_length: 40]

      validate Validations.ManagerChain
      change Changes.UpdateParty
    end

    update :set_leave_policy do
      accept [:leave_policy_id]
    end

    update :terminate do
      require_atomic? false
      accept [:termination_date, :termination_reason]
      validate attribute_equals(:status, :active), message: "already left"
      change set_attribute(:status, :terminated)
      change set_new_attribute(:termination_date, &Date.utc_today/0)
    end

    update :rehire do
      require_atomic? false
      validate attribute_equals(:status, :terminated), message: "still employed"
      change set_attribute(:status, :active)
      change set_attribute(:termination_date, nil)
      change set_attribute(:termination_reason, nil)
    end
  end
end
