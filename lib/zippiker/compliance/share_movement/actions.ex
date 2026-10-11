defmodule Zippiker.Compliance.ShareMovement.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :allot do
      description "Issues new shares to a member."

      accept [
        :profile_id,
        :shareholder_id,
        :share_class_id,
        :quantity,
        :date,
        :consideration,
        :certificate_number,
        :notes
      ]

      validate compare(:quantity, greater_than: 0)
      change set_attribute(:kind, :allotment)
      change {Zippiker.Compliance.Changes.AddFiling, event: :allotted}
    end

    create :record do
      description "One side of a transfer, or a cancellation (signed quantity)."

      accept [
        :profile_id,
        :shareholder_id,
        :share_class_id,
        :quantity,
        :date,
        :consideration,
        :certificate_number,
        :notes,
        :kind
      ]
    end

    action :transfer, :map do
      description "Moves shares from one member to another (both sides recorded)."
      transaction? true
      argument :profile_id, :uuid, allow_nil?: false
      argument :from_id, :uuid, allow_nil?: false
      argument :to_id, :uuid, allow_nil?: false
      argument :share_class_id, :uuid, allow_nil?: false
      argument :quantity, :integer, allow_nil?: false, constraints: [min: 1]
      argument :date, :date
      argument :consideration, :decimal
      argument :certificate_number, :string
      run Zippiker.Compliance.ShareMovement.Actions.Transfer
    end
  end
end
