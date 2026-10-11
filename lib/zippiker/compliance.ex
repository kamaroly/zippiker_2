defmodule Zippiker.Compliance do
  @moduledoc """
  Company secretarial (Kenya Companies Act, 2015): each company's statutory
  profile, its registers (directors and secretaries, members and shares,
  beneficial owners, charges), meetings and resolutions, statutory
  documents, and a filing calendar that fills itself from changes and
  anniversaries. Deadlines are defaults to confirm with your secretary.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Compliance.CompanyProfile do
      define :list_company_profiles, action: :list
      define :get_company_profile, action: :read, get_by: [:id]
      define :create_company_profile, action: :create
      define :update_company_profile, action: :update
    end

    resource Zippiker.Compliance.Officer do
      define :officer_register, action: :register, args: [:profile_id]
      define :get_officer, action: :read, get_by: [:id]
      define :appoint_officer, action: :appoint
      define :update_officer, action: :update
      define :cease_officer, action: :cease
    end

    resource Zippiker.Compliance.ShareClass do
      define :share_classes, action: :for_profile, args: [:profile_id]
      define :create_share_class, action: :create
      define :update_share_class, action: :update
    end

    resource Zippiker.Compliance.Shareholder do
      define :member_register, action: :register, args: [:profile_id]
      define :get_shareholder, action: :read, get_by: [:id]
      define :add_shareholder, action: :create
      define :update_shareholder, action: :update
    end

    resource Zippiker.Compliance.ShareMovement do
      define :allot_shares, action: :allot
      define :transfer_shares, action: :transfer
    end

    resource Zippiker.Compliance.BeneficialOwner do
      define :beneficial_owner_register, action: :register, args: [:profile_id]
      define :get_beneficial_owner, action: :read, get_by: [:id]
      define :add_beneficial_owner, action: :create
      define :update_beneficial_owner, action: :update
      define :cease_beneficial_owner, action: :cease
    end

    resource Zippiker.Compliance.Charge do
      define :charge_register, action: :register, args: [:profile_id]
      define :get_charge, action: :read, get_by: [:id]
      define :create_charge, action: :create
      define :update_charge, action: :update
      define :satisfy_charge, action: :satisfy
    end

    resource Zippiker.Compliance.Meeting do
      define :list_meetings, action: :list, args: [:profile_id]
      define :get_meeting, action: :read, get_by: [:id]
      define :create_meeting, action: :create
      define :update_meeting, action: :update
    end

    resource Zippiker.Compliance.Resolution

    resource Zippiker.Compliance.ComplianceTask do
      define :filing_calendar, action: :calendar, args: [:profile_id]
      define :get_compliance_task, action: :read, get_by: [:id]
      define :add_compliance_task, action: :create
      define :complete_compliance_task, action: :complete
      define :reopen_compliance_task, action: :reopen
    end

    resource Zippiker.Compliance.StatutoryDocument do
      define :statutory_documents, action: :library, args: [:profile_id]
      define :get_statutory_document, action: :read, get_by: [:id]
      define :add_statutory_document, action: :create
      define :delete_statutory_document, action: :destroy
    end

    resource Zippiker.Compliance.Automation do
      define :refresh_filing_calendars, action: :refresh_calendars
    end
  end
end
