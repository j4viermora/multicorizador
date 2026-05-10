# frozen_string_literal: true

SimpleForm.setup do |config|
  # ── Default wrapper (DaisyUI) ──
  config.wrappers :default, class: "form-control w-full mb-4" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "label label-text text-sm font-medium"
    b.use :input, class: "input input-bordered w-full",
                  error_class: "input-error"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-base-content/50" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-error" }
  end

  # ── Boolean wrapper (DaisyUI) ──
  config.wrappers :boolean, class: "form-control mb-4" do |b|
    b.use :html5
    b.optional :readonly

    b.wrapper tag: :label, class: "label cursor-pointer justify-start gap-2" do |ba|
      ba.use :input, class: "checkbox checkbox-sm"
      ba.use :label_text, class: "label-text"
    end
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-base-content/50" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-error" }
  end

  # ── Auth wrapper (Devise pages with hero panel) ──
  config.wrappers :auth, class: "form-control w-full" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :readonly

    b.use :label, class: "label label-text text-xs uppercase tracking-widest text-base-content/40"
    b.use :input, class: "input input-bordered w-full",
                  error_class: "input-error"
    b.use :hint,  wrap_with: { tag: :div, class: "label" }, class: "label-text-alt text-base-content/30"
    b.use :error, wrap_with: { tag: :div, class: "label" }, class: "label-text-alt text-error"
  end

  config.default_wrapper = :default
  config.boolean_style = :inline

  config.wrapper_mappings = { boolean: :boolean }

  config.button_class = "btn btn-neutral"

  config.error_notification_tag = :div
  config.error_notification_class = "alert alert-error mb-4 text-sm"

  config.browser_validations = false

  config.label_class = nil
  config.input_class = nil

  config.input_field_error_class = "input-error"
end
