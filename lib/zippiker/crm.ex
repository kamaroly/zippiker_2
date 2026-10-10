defmodule Zippiker.Crm do
  @moduledoc """
  Customer relationship management: leads, deals moving through pipelines,
  and the activities and tasks around them. People and companies live in
  `Zippiker.Parties` so later modules (sales, invoicing, ...) share them.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.Crm.Pipeline do
      define :list_pipelines, action: :list
      define :get_pipeline, action: :read, get_by: [:id]
      define :create_pipeline, action: :create
      define :update_pipeline, action: :update
      define :seed_crm_defaults, action: :seed_defaults
    end

    resource Zippiker.Crm.Stage do
      define :list_stages, action: :for_pipeline, args: [:pipeline_id]
      define :create_stage, action: :create
      define :update_stage, action: :update
      define :delete_stage, action: :destroy
    end

    resource Zippiker.Crm.Deal do
      define :list_deals, action: :search
      define :board_deals, action: :board, args: [:pipeline_id]
      define :get_deal, action: :read, get_by: [:id]
      define :create_deal, action: :create
      define :update_deal, action: :update
      define :move_deal, action: :move, args: [:stage_id, :position]
      define :archive_deal, action: :destroy
    end

    resource Zippiker.Crm.Lead do
      define :list_leads, action: :search
      define :get_lead, action: :read, get_by: [:id]
      define :create_lead, action: :create
      define :update_lead, action: :update
      define :convert_lead, action: :convert
      define :archive_lead, action: :destroy
    end

    resource Zippiker.Crm.Activity do
      define :timeline, action: :timeline
      define :log_activity, action: :create
      define :delete_activity, action: :destroy
    end

    resource Zippiker.Crm.Task do
      define :list_tasks, action: :list
      define :get_task, action: :read, get_by: [:id]
      define :create_task, action: :create
      define :update_task, action: :update
      define :complete_task, action: :complete
      define :reopen_task, action: :reopen
      define :delete_task, action: :destroy
    end

    resource Zippiker.Crm.Dashboard do
      define :dashboard_summary, action: :summary
    end
  end
end
