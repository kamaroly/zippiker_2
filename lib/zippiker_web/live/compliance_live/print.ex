defmodule ZippikerWeb.ComplianceLive.Print do
  @moduledoc "Printable statutory registers (officers, members, beneficial owners, charges) and minutes."
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @titles %{
    "officers" => "Register of directors and secretaries",
    "members" => "Register of members",
    "owners" => "Register of beneficial owners",
    "charges" => "Register of charges",
    "minutes" => "Minutes"
  }

  @impl true
  def mount(%{"register" => register} = params, _session, socket)
      when is_map_key(@titles, register) do
    socket = Scope.assign_profile(socket, params)
    opts = ash_opts(socket)
    profile = socket.assigns.profile

    rows =
      case {register, profile} do
        {_, nil} -> []
        {"officers", p} -> Compliance.officer_register!(p.id, opts)
        {"members", p} -> Compliance.member_register!(p.id, opts)
        {"owners", p} -> Compliance.beneficial_owner_register!(p.id, opts)
        {"charges", p} -> Compliance.charge_register!(p.id, opts)
        {"minutes", _p} -> [Compliance.get_meeting!(params["id"], opts ++ [load: [:resolutions]])]
      end

    {:ok,
     assign(socket,
       register: register,
       title: Map.fetch!(@titles, register),
       rows: rows,
       page_title: Map.fetch!(@titles, register)
     )}
  end

  def mount(_params, _session, socket), do: {:ok, push_navigate(socket, to: ~p"/compliance")}

  defp back("minutes"), do: ~p"/compliance/meetings"
  defp back("owners"), do: ~p"/compliance/beneficial-owners"
  defp back(register), do: "/compliance/#{register}"

  defp shares(member), do: member.shares_held || 0
end
