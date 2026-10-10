defmodule Zippiker.Platform do
  @moduledoc """
  The SaaS layer above the workspaces: plans, each workspace's subscription
  and platform invoices, the audit log, and the super admin overview.
  Everything here is global (not tenant-scoped).
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Platform.Plan do
      define :list_plans, action: :list
      define :get_plan, action: :read, get_by: [:id]
      define :create_plan, action: :create
      define :update_plan, action: :update
    end

    resource Zippiker.Platform.Subscription do
      define :ensure_subscription, action: :ensure, args: [:organization_id]
      define :list_subscriptions, action: :list
      define :change_plan, action: :change_plan
      define :update_billing_details, action: :update_billing_details
    end

    resource Zippiker.Platform.BillingInvoice do
      define :list_billing_invoices, action: :list
      define :get_billing_invoice, action: :read, get_by: [:id]
      define :generate_billing_invoice, action: :generate, args: [:organization_id]
      define :mark_billing_invoice_paid, action: :mark_paid
      define :void_billing_invoice, action: :void
    end

    resource Zippiker.Platform.AuditEvent do
      define :log_event, action: :log
      define :list_audit_events, action: :recent
      define :request_plan, action: :request_plan, args: [:plan_id]
    end

    resource Zippiker.Platform.Reports do
      define :platform_overview, action: :overview
    end
  end
end
