defmodule Mix.Tasks.Zippiker.SuperAdmin do
  @shortdoc "Grants (or with --revoke, removes) platform super admin access"

  @moduledoc """
  The first super admin has to be created from the command line; after that,
  super admins manage each other under Platform → Users.

      mix zippiker.super_admin ops@example.com
      mix zippiker.super_admin ops@example.com --revoke

  The user must already have an account.
  """
  use Mix.Task

  require Ash.Query

  @impl true
  def run(args) do
    {opts, emails, _} = OptionParser.parse(args, strict: [revoke: :boolean])
    Mix.Task.run("app.start")

    case emails do
      [email] -> grant(email, !opts[:revoke])
      _ -> Mix.raise("Usage: mix zippiker.super_admin EMAIL [--revoke]")
    end
  end

  defp grant(email, super_admin?) do
    Zippiker.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil ->
        Mix.raise("No user with email #{email}. Ask them to register first.")

      user ->
        Zippiker.Accounts.set_super_admin!(user, super_admin?, authorize?: false)

        Mix.shell().info(
          "#{email} is #{if super_admin?, do: "now", else: "no longer"} a super admin."
        )
    end
  end
end
