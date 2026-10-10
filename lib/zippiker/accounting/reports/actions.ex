defmodule Zippiker.Accounting.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounting.Reports.Actions

  actions do
    action :overview, :map do
      description "Cash, receivables, tax owed, this month's profit and a six month trend."
      run Actions.Overview
    end

    action :trial_balance, :map do
      description "Debit and credit balance of every account on a date. Totals must match."
      argument :as_of, :date
      run Actions.TrialBalance
    end

    action :profit_and_loss, :map do
      description "Income minus expenses over a period."
      argument :from, :date
      argument :to, :date
      run Actions.ProfitAndLoss
    end

    action :balance_sheet, :map do
      description "Assets = liabilities + equity (including earnings to date) on a date."
      argument :as_of, :date
      run Actions.BalanceSheet
    end
  end
end
