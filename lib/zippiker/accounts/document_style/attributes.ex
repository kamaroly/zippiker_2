defmodule Zippiker.Accounts.DocumentStyle.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :layout, :atom do
      description "classic: name and title apart; modern: a coloured band; compact: dense."
      allow_nil? false
      public? true
      default :classic
      constraints one_of: [:classic, :modern, :compact]
    end

    attribute :accent_color, :string do
      allow_nil? false
      public? true
      default "#1c1917"
      constraints match: ~r/^#[0-9a-fA-F]{6}$/
    end

    attribute :font, :atom do
      allow_nil? false
      public? true
      default :sans
      constraints one_of: [:sans, :serif, :mono]
    end

    attribute :logo_size, :atom do
      allow_nil? false
      public? true
      default :medium
      constraints one_of: [:small, :medium, :large]
    end

    attribute :show_tax_ids?, :boolean, allow_nil?: false, public?: true, default: true
    attribute :show_signatures?, :boolean, allow_nil?: false, public?: true, default: true

    attribute :templates, {:array, Zippiker.Accounts.DocumentTemplate} do
      description "Per document type: title, terms and footer."
      allow_nil? false
      public? true
      default []
    end
  end
end
