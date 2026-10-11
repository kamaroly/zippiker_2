defmodule Zippiker.HR.LeavePolicy.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]
    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :default?, :boolean do
      description "Covers everyone without a policy of their own for this leave type."
      allow_nil? false
      public? true
      default false
    end

    attribute :effective_date, :date do
      description "When the policy starts applying; accruals count from here."
      allow_nil? false
      public? true
      default &Date.utc_today/0
    end

    attribute :category, :atom do
      description """
      fixed: `days_per_year` every calendar year (with carry-over);
      accrual: `accrual_days` every `accrual_frequency`, up to `accrual_cap`;
      manual: only what admins add (adjustments) and approved claims;
      unlimited: no balance.
      """

      allow_nil? false
      public? true
      default :fixed
      constraints one_of: [:fixed, :accrual, :manual, :unlimited]
    end

    attribute :days_per_year, :decimal, public?: true, constraints: [min: 0]

    attribute :carry_over_days, :decimal do
      description "Most unused days that roll into the next year (fixed allowance)."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :accrual_days, :decimal, public?: true, constraints: [min: 0]

    attribute :accrual_frequency, :atom do
      public? true
      default :monthly
      constraints one_of: [:weekly, :monthly, :quarterly, :yearly]
    end

    attribute :accrual_cap, :decimal do
      description "Accruals stop while the balance is at this many days (empty = no cap)."
      public? true
      constraints min: 0
    end

    attribute :review_threshold_days, :integer do
      description "Days a request may wait for review before `overdue_action` applies."
      public? true
      constraints min: 1
    end

    attribute :overdue_action, :atom do
      description "What happens to a request still pending after the review threshold."
      allow_nil? false
      public? true
      default :none
      constraints one_of: [:none, :approve, :reject]
    end

    attribute :requires_attachment?, :boolean, allow_nil?: false, public?: true, default: false

    attribute :count_weekends_and_holidays?, :boolean do
      description "Count every calendar day instead of working days only."
      allow_nil? false
      public? true
      default false
    end

    attribute :allow_backdated?, :boolean, allow_nil?: false, public?: true, default: true

    attribute :claimable?, :boolean do
      description "People can claim days of this leave (e.g. time off in lieu of overtime)."
      allow_nil? false
      public? true
      default false
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
