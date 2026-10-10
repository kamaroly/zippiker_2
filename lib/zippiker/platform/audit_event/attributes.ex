defmodule Zippiker.Platform.AuditEvent.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :action, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :impersonation_started,
                    :impersonation_stopped,
                    :workspace_accessed,
                    :plan_changed,
                    :modules_changed,
                    :plan_requested,
                    :billing_invoice_generated,
                    :billing_invoice_paid,
                    :super_admin_changed
                  ]
    end

    attribute :summary, :string, allow_nil?: false, public?: true, constraints: [max_length: 500]
    create_timestamp :inserted_at
  end
end
