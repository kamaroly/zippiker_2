defmodule Zippiker.Compliance.Officer.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]

    attribute :role, :atom do
      allow_nil? false
      public? true
      default :director

      constraints one_of: [
                    :director,
                    :managing_director,
                    :alternate_director,
                    :chairperson,
                    :secretary
                  ]
    end

    attribute :nationality, :string, public?: true, constraints: [max_length: 60]
    attribute :id_number, :string, public?: true, constraints: [max_length: 40]
    attribute :kra_pin, :string, public?: true, constraints: [max_length: 20]
    attribute :date_of_birth, :date, public?: true
    attribute :occupation, :string, public?: true, constraints: [max_length: 100]
    attribute :email, :string, public?: true, constraints: [max_length: 160]
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :residential_address, :string, public?: true, constraints: [max_length: 300]
    attribute :service_address, :string, public?: true, constraints: [max_length: 300]
    attribute :appointed_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :ceased_on, :date, public?: true
    attribute :cessation_reason, :string, public?: true, constraints: [max_length: 200]
    timestamps()
  end

  calculations do
    calculate :active?, :boolean, expr(is_nil(ceased_on)), public?: true
  end
end
