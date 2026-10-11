defmodule ZippikerWeb.Settings.DocumentsLive do
  @moduledoc """
  Documents & branding: each legal entity's logo and the look of its
  printed documents (layout, colour, font), plus a title, terms and footer
  per document type, with a live preview.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts
  alias Zippiker.Accounts.{DocumentStyle, DocumentTemplate}

  @sales_kinds [:quote, :sales_order, :invoice, :rfq, :purchase_order]

  @impl true
  def mount(_params, _session, socket) do
    entities = Accounts.list_legal_entities!(ash_opts(socket))

    {:ok,
     socket
     |> assign(page_title: "Documents & branding", entities: entities, kind: :invoice)
     |> allow_upload(:logo,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: 1_000_000
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    entity =
      Enum.find(socket.assigns.entities, &(&1.id == params["entity"])) ||
        hd(socket.assigns.entities)

    {:noreply, socket |> assign(:entity, entity) |> reset_draft()}
  end

  defp reset_draft(socket) do
    style = ZippikerWeb.DocumentComponents.style(socket.assigns.entity)
    assign(socket, draft: style, dirty?: false)
  end

  @impl true
  def handle_event("pick_entity", %{"entity" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/settings/documents?entity=#{id}")}
  end

  def handle_event("kind", %{"kind" => kind}, socket) do
    kind = Enum.find(DocumentTemplate.kinds(), &(to_string(&1) == kind)) || :invoice
    {:noreply, assign(socket, :kind, kind)}
  end

  def handle_event("change", %{"style" => params} = all, socket) do
    draft = socket.assigns.draft

    templates =
      case all["template"] do
        %{} = template -> put_template(draft.templates, socket.assigns.kind, template)
        _ -> draft.templates
      end

    draft = %{
      draft
      | layout: atom(params["layout"], [:classic, :modern, :compact], draft.layout),
        accent_color: color(params["accent_color"], draft.accent_color),
        font: atom(params["font"], [:sans, :serif, :mono], draft.font),
        logo_size: atom(params["logo_size"], [:small, :medium, :large], draft.logo_size),
        show_tax_ids?: params["show_tax_ids?"] == "true",
        show_signatures?: params["show_signatures?"] == "true",
        templates: templates
    }

    {:noreply, assign(socket, draft: draft, dirty?: true)}
  end

  def handle_event("swatch", %{"color" => value}, socket) do
    draft = %{
      socket.assigns.draft
      | accent_color: color(value, socket.assigns.draft.accent_color)
    }

    {:noreply, assign(socket, draft: draft, dirty?: true)}
  end

  def handle_event("save", _params, socket) do
    draft = socket.assigns.draft

    style = %{
      layout: draft.layout,
      accent_color: draft.accent_color,
      font: draft.font,
      logo_size: draft.logo_size,
      show_tax_ids?: draft.show_tax_ids?,
      show_signatures?: draft.show_signatures?,
      templates:
        for template <- draft.templates,
            Enum.any?([template.title, template.terms, template.footer], &(&1 not in [nil, ""])) do
          Map.take(template, [:kind, :title, :terms, :footer])
        end
    }

    case Accounts.update_document_style(
           socket.assigns.entity,
           %{document_style: style},
           ash_opts(socket)
         ) do
      {:ok, entity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Document design saved")
         |> replace_entity(entity)
         |> reset_draft()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("discard", _params, socket), do: {:noreply, reset_draft(socket)}

  def handle_event("validate_logo", _params, socket), do: {:noreply, socket}

  def handle_event("upload_logo", _params, socket) do
    organization = socket.assigns.current_organization

    paths =
      consume_uploaded_entries(socket, :logo, fn %{path: path}, entry ->
        {:ok, ZippikerWeb.Uploads.store(path, organization.id, "logos", entry.client_name)}
      end)

    case paths do
      [path] ->
        case Accounts.set_logo(socket.assigns.entity, path, ash_opts(socket)) do
          {:ok, entity} ->
            {:noreply, socket |> put_flash(:info, "Logo uploaded") |> replace_entity(entity)}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, error_message(error))}
        end

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_logo", _params, socket) do
    case Accounts.remove_logo(socket.assigns.entity, ash_opts(socket)) do
      {:ok, entity} ->
        {:noreply, socket |> put_flash(:info, "Logo removed") |> replace_entity(entity)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp upload_error(:too_large), do: "Over 1 MB"
  defp upload_error(:not_accepted), do: "Use PNG, JPG or WebP"
  defp upload_error(:too_many_files), do: "One logo at a time"
  defp upload_error(_error), do: "Can't use this file"

  defp replace_entity(socket, entity) do
    entities = Enum.map(socket.assigns.entities, &if(&1.id == entity.id, do: entity, else: &1))
    assign(socket, entities: entities, entity: entity)
  end

  defp put_template(templates, kind, params) do
    template = %DocumentTemplate{
      kind: kind,
      title: blank(params["title"]),
      terms: blank(params["terms"]),
      footer: blank(params["footer"])
    }

    [template | Enum.reject(templates || [], &(&1.kind == kind))]
  end

  defp current_template(draft, kind) do
    Enum.find(draft.templates || [], &(&1.kind == kind)) || %DocumentTemplate{kind: kind}
  end

  defp blank(value) when value in [nil, ""], do: nil
  defp blank(value), do: value

  defp atom(value, allowed, default),
    do: Enum.find(allowed, &(to_string(&1) == value)) || default

  defp color(value, default) do
    if is_binary(value) and Regex.match?(~r/^#[0-9a-fA-F]{6}$/, value), do: value, else: default
  end

  defp preview_entity(entity, %DocumentStyle{} = draft), do: %{entity | document_style: draft}

  # Sample documents for the preview.
  defp sales_kind?(kind), do: kind in @sales_kinds

  defp sample_document(entity, kind) do
    currency = entity.currency || "USD"
    money = &Money.new!(currency, &1)
    party_key = if kind in [:rfq, :purchase_order], do: :supplier, else: :customer

    party = %{
      id: "sample",
      name: if(party_key == :supplier, do: "Acme Supplies Ltd", else: "Globex Corporation"),
      tax_id: "P051234567X",
      addresses: [
        %{
          kind: :billing,
          line1: "14 Moi Avenue",
          line2: nil,
          city: "Nairobi",
          region: nil,
          postal_code: "00100",
          country: "KE"
        }
      ]
    }

    line = fn description, quantity, price ->
      subtotal = Decimal.mult(Decimal.new(quantity), Decimal.new(price))

      %{
        description: description,
        quantity: Decimal.new(quantity),
        unit: "pcs",
        unit_price: Decimal.new(price),
        discount_percent: Decimal.new(0),
        tax_percent: Decimal.new(16),
        subtotal: subtotal
      }
    end

    %{
      number: "#{String.upcase(to_string(kind)) |> String.slice(0, 3)}-2026-0042",
      legal_entity: entity,
      contact: nil,
      currency: currency,
      issued_on: Date.utc_today(),
      due_on: Date.add(Date.utc_today(), 30),
      valid_until: Date.add(Date.utc_today(), 14),
      expected_on: Date.add(Date.utc_today(), 7),
      lines: [line.("Office chairs", "4", "120"), line.("Installation", "1", "150")],
      subtotal: money.(630),
      tax_total: money.("100.80"),
      total: money.("730.80"),
      amount_paid: money.(0),
      notes: nil
    }
    |> Map.put(party_key, party)
  end

  defp sample_lines do
    [
      %{description: "Office chairs", sku: "CH-100", quantity: Decimal.new(4), unit: "pcs"},
      %{description: "Desk lamps", sku: "LP-020", quantity: Decimal.new(6), unit: "pcs"}
    ]
  end

  defp sample_party do
    %{
      name: "Globex Corporation",
      phone: "+254 700 000 000",
      addresses: [
        %{
          kind: :shipping,
          line1: "14 Moi Avenue",
          line2: nil,
          city: "Nairobi",
          region: nil,
          postal_code: "00100",
          country: "KE"
        }
      ]
    }
  end
end
