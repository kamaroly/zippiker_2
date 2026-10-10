defmodule Zippiker.Crm.Stage.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    attribute :probability, :integer do
      description "Win likelihood in percent, used for weighted forecasts."
      allow_nil? false
      public? true
      default 10
      constraints min: 0, max: 100
    end

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :open
      constraints one_of: [:open, :won, :lost]
    end

    attribute :color, :atom do
      allow_nil? false
      public? true
      default :slate
      constraints one_of: [:slate, :blue, :violet, :amber, :emerald, :rose, :orange, :teal]
    end

    timestamps()
  end
end
