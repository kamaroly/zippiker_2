defmodule Zippiker.Accounts do
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Accounts.Token

    resource Zippiker.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :update_profile, action: :update_profile
      define :platform_users, action: :platform_search
      define :set_super_admin, action: :set_super_admin, args: [:super_admin?]
    end

    resource Zippiker.Accounts.Organization do
      define :create_organization, action: :create
      define :update_organization, action: :update
      define :set_maker_checker, action: :set_maker_checker
      define :set_multi_branch, action: :set_multi_branch
      define :get_organization, action: :read, get_by: [:id]
      define :platform_organizations, action: :platform_search
      define :set_plan_limits, action: :set_plan_limits
    end

    resource Zippiker.Accounts.Membership do
      define :list_my_memberships, action: :mine
      define :list_members, action: :for_organization, args: [:organization_id]
      define :update_membership, action: :update_role
      define :remove_member, action: :destroy
      define :set_member_roles, action: :set_roles, args: [:role_ids]
    end

    resource Zippiker.Accounts.Role do
      define :list_roles, action: :list
      define :get_role, action: :read, get_by: [:id]
      define :create_role, action: :create
      define :update_role, action: :update
      define :reset_role, action: :reset
      define :delete_role, action: :destroy
      define :seed_default_roles, action: :seed_defaults, args: [:organization_id]
    end

    resource Zippiker.Accounts.MembershipRole

    resource Zippiker.Accounts.LegalEntity do
      define :list_legal_entities, action: :list
      define :get_legal_entity, action: :read, get_by: [:id]
      define :default_legal_entity, action: :default
      define :create_legal_entity, action: :create
      define :update_legal_entity, action: :update
    end

    resource Zippiker.Accounts.PortalAccess do
      define :invite_to_portal, action: :invite
      define :portal_accesses_for_party, action: :for_party, args: [:party_id]
      define :my_portals, action: :mine
      define :portal_invitation, action: :by_token, args: [:token], get?: true
      define :accept_portal_invitation, action: :accept
      define :revoke_portal_access, action: :revoke
    end

    resource Zippiker.Accounts.Branch do
      define :list_branches, action: :list
      define :get_branch, action: :read, get_by: [:id]
      define :default_branch, action: :default
      define :create_branch, action: :create
      define :update_branch, action: :update
      define :delete_branch, action: :destroy
    end

    resource Zippiker.Accounts.NumberSequence do
      define :next_document_number,
        action: :next_number,
        args: [:legal_entity_id, :document_type, :prefix]
    end

    resource Zippiker.Accounts.Invitation do
      define :invite, action: :create
      define :list_pending_invitations, action: :pending
      define :list_my_invitations, action: :for_me
      define :get_invitation_by_token, action: :by_token, args: [:token]
      define :accept_invitation, action: :accept
      define :revoke_invitation, action: :destroy
    end
  end
end
