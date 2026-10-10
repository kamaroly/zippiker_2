defmodule ZippikerWeb.AuthOverrides do
  @moduledoc """
  Restyles the AshAuthentication screens (sign in, register, reset, confirm)
  with the app's design tokens. See
  https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html
  """
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{Components, ConfirmLive, ResetLive, SignInLive}

  @page "grid min-h-screen place-items-center bg-canvas px-4"
  @card "w-full max-w-sm rounded-2xl border border-line bg-surface p-8 shadow-card"
  @title "mb-6 text-xl font-semibold tracking-tight text-ink"
  @input "block h-10 w-full rounded-lg border border-line bg-surface px-3 text-sm text-ink shadow-card placeholder:text-muted focus:border-brand focus:outline-none focus:ring-3 focus:ring-brand/15"
  @submit "mt-4 inline-flex h-10 w-full items-center justify-center rounded-lg bg-brand text-sm font-medium text-brand-ink shadow-card transition hover:brightness-105 active:scale-[0.99]"

  override SignInLive do
    set :root_class, @page
  end

  override ResetLive do
    set :root_class, @page
  end

  override ConfirmLive do
    set :root_class, @page
  end

  override Components.SignIn do
    set :root_class, @card
    set :strategy_class, "w-full"

    set :authentication_error_container_class,
        "mb-4 rounded-lg bg-danger-soft px-3 py-2 text-center text-sm text-danger"
  end

  override Components.Reset do
    set :root_class, @card
    set :strategy_class, "w-full"
  end

  override Components.Confirm do
    set :root_class, @card
    set :strategy_class, "w-full"
  end

  override Components.Banner do
    set :root_class, "mb-6 flex justify-center"
    set :image_url, nil
    set :dark_image_url, nil
    set :text_class, "text-2xl font-bold tracking-tight text-ink"
    set :text, "zippiker"
  end

  override Components.Password do
    set :interstitial_class, "mt-4 flex flex-row justify-between text-sm"
    set :toggler_class, "text-brand hover:underline"
  end

  override Components.Password.SignInForm do
    set :label_class, @title
  end

  override Components.Password.RegisterForm do
    set :label_class, @title
  end

  override Components.Password.ResetForm do
    set :label_class, @title
  end

  override Components.Reset.Form do
    set :label_class, @title
  end

  override Components.Password.Input do
    set :field_class, "mb-3"
    set :label_class, "mb-1.5 block text-xs font-medium text-ink-soft"
    set :input_class, @input
    set :input_class_with_error, @input <> " border-danger"
    set :submit_class, @submit
    set :checkbox_label_class, "text-sm text-ink-soft"
    set :remember_me_class, "mt-2 flex items-center gap-2"
    set :checkbox_class, "accent-brand"
  end

  override Components.Confirm.Input do
    set :submit_class, @submit
  end

  override Components.HorizontalRule do
    set :hr_inner_class, "w-full border-t border-line"
    set :text_inner_class, "bg-surface px-2 text-muted"
  end
end
