defmodule Zippiker.Accounts.DocumentTemplate.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :kind, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :quote,
                    :sales_order,
                    :invoice,
                    :delivery_note,
                    :rfq,
                    :purchase_order,
                    :goods_receipt,
                    :stock_note,
                    :job_card
                  ]
    end

    attribute :title, :string, public?: true, constraints: [max_length: 60]
    attribute :terms, :string, public?: true, constraints: [max_length: 2_000]
    attribute :footer, :string, public?: true, constraints: [max_length: 1_000]
  end
end
