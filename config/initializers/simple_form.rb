# frozen_string_literal: true

SimpleForm.setup do |config|
  # ── Default wrapper (Flowbite) ──
  config.wrappers :default, class: "w-full mb-4" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "label-text"
    b.use :input, class: "input w-full",
                  error_class: "input-error"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  # ── Select wrapper (Flowbite) ──
  config.wrappers :select, class: "w-full mb-4" do |b|
    b.use :html5
    b.optional :readonly

    b.use :label, class: "label-text"
    b.use :input, class: "select w-full",
                  error_class: "select-error"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  # ── Boolean wrapper (Flowbite) ──
  config.wrappers :boolean, class: "w-full mb-4" do |b|
    b.use :html5
    b.optional :readonly

    b.wrapper tag: :div, class: "flex items-center gap-2" do |ba|
      ba.use :input, class: "checkbox"
      ba.use :label_text, class: "text-sm text-gray-700"
    end
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  # ── Auth wrapper (Devise hero pages — compact labels) ──
  config.wrappers :auth, class: "w-full" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :readonly

    b.use :label, class: "label-text text-xs uppercase tracking-widest text-gray-500"
    b.use :input, class: "input w-full",
                  error_class: "input-error"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  # ── Quote bar wrapper (cotizador en una sola pantalla) ──
  # La caja .qbar-field dibuja el borde; el input va sin chrome propio.
  config.wrappers :qbar, class: "qbar-field" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :readonly

    b.use :label, class: "qbar-label"
    b.use :input, error_class: "qbar-invalid"
  end

  # ── Input pelado, para agrupar varios bajo una misma etiqueta :qbar ──
  config.wrappers :qbar_plain, class: "qbar-plain" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :readonly

    b.use :input, error_class: "qbar-invalid"
  end

  config.default_wrapper = :default
  config.boolean_style = :inline

  config.wrapper_mappings = { boolean: :boolean, select: :select, collection_select: :select }

  # Prevent SimpleForm from adding input type classes (e.g. "select") to wrapper divs,
  # which would collide with our .select component class.
  config.generate_additional_classes_for = [ :input ]

  config.button_class = "btn btn-neutral"

  config.error_notification_tag = :div
  config.error_notification_class = "alert alert-error mb-4 text-sm"

  config.browser_validations = false

  config.label_class = nil
  config.input_class = nil

  config.input_field_error_class = "input-error"
end
