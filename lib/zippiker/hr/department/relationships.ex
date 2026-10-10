defmodule Zippiker.HR.Department.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :parent, Zippiker.HR.Department, public?: true
    belongs_to :head, Zippiker.HR.Employee, public?: true

    has_many :children, Zippiker.HR.Department do
      destination_attribute :parent_id
    end

    has_many :employees, Zippiker.HR.Employee
  end
end
