defmodule Zippiker.HR do
  @moduledoc """
  People: departments, employees (each a `Zippiker.Parties` person, optionally
  linked to a workspace user), reporting lines, leave types and leave requests
  approved by the employee's manager.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.HR.Department do
      define :list_departments, action: :list
      define :get_department, action: :read, get_by: [:id]
      define :create_department, action: :create
      define :update_department, action: :update
      define :delete_department, action: :destroy
    end

    resource Zippiker.HR.Employee do
      define :list_employees, action: :search
      define :get_employee, action: :read, get_by: [:id]
      define :my_employee_record, action: :mine
      define :hire_employee, action: :create
      define :update_employee, action: :update
      define :terminate_employee, action: :terminate
      define :rehire_employee, action: :rehire
    end

    resource Zippiker.HR.LeaveType do
      define :list_leave_types, action: :list
      define :get_leave_type, action: :read, get_by: [:id]
      define :create_leave_type, action: :create
      define :update_leave_type, action: :update
      define :delete_leave_type, action: :destroy
    end

    resource Zippiker.HR.LeavePolicy do
      define :list_leave_policies, action: :list
      define :get_leave_policy, action: :read, get_by: [:id]
      define :create_leave_policy, action: :create
      define :update_leave_policy, action: :update
      define :assign_leave_policy, action: :assign
      define :delete_leave_policy, action: :destroy
    end

    resource Zippiker.HR.LeavePolicyAssignment

    resource Zippiker.HR.LeaveBalanceEntry do
      define :leave_balance_entries, action: :for_employee, args: [:employee_id]
      define :adjust_leave_balance, action: :adjust
    end

    resource Zippiker.HR.LeaveClaim do
      define :list_leave_claims, action: :search
      define :get_leave_claim, action: :read, get_by: [:id]
      define :claim_leave, action: :create
      define :approve_leave_claim, action: :approve
      define :reject_leave_claim, action: :reject
      define :cancel_leave_claim, action: :cancel
    end

    resource Zippiker.HR.Holiday do
      define :list_holidays, action: :list
      define :get_holiday, action: :read, get_by: [:id]
      define :create_holiday, action: :create
      define :update_holiday, action: :update
      define :delete_holiday, action: :destroy
    end

    resource Zippiker.HR.Automation do
      define :run_leave_accruals, action: :run_accruals
      define :review_overdue_leave, action: :review_overdue
    end

    resource Zippiker.HR.LeaveRequest do
      define :list_leave_requests, action: :search
      define :get_leave_request, action: :read, get_by: [:id]
      define :request_leave, action: :create
      define :approve_leave, action: :approve
      define :reject_leave, action: :reject
      define :cancel_leave, action: :cancel
    end

    resource Zippiker.HR.Reports do
      define :hr_summary, action: :summary
      define :leave_balances, action: :balances, args: [:employee_id]
      define :org_chart, action: :org_chart
    end
  end
end
