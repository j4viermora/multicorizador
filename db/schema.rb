# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_10_002936) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "commission_contracts", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.integer "producer_id"
    t.decimal "provider_commission_rate", precision: 5, scale: 4, null: false
    t.decimal "producer_share_rate", precision: 5, scale: 4, null: false
    t.date "valid_from", null: false
    t.date "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["producer_id"], name: "index_commission_contracts_on_producer_id"
    t.index ["provider_id", "producer_id"], name: "index_commission_contracts_on_provider_and_producer", unique: true, where: "producer_id IS NOT NULL"
    t.index ["provider_id"], name: "index_commission_contracts_default", unique: true, where: "producer_id IS NULL"
    t.index ["provider_id"], name: "index_commission_contracts_on_provider_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "ARS", null: false
  end

  create_table "insurance_plans", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "name", null: false
    t.text "description"
    t.json "coverage_details", default: {}
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_insurance_plans_on_provider_id"
  end

  create_table "links", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "quote_id", null: false
    t.string "token", null: false
    t.string "purpose", default: "quote_share", null: false
    t.datetime "expires_at"
    t.integer "access_count", default: 0, null: false
    t.datetime "last_accessed_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_links_on_company_id"
    t.index ["quote_id"], name: "index_links_on_quote_id"
    t.index ["token"], name: "index_links_on_token", unique: true
  end

  create_table "platform_invoices", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.integer "total_commission_cents", default: 0, null: false
    t.string "total_commission_currency", default: "USD", null: false
    t.string "status", default: "draft", null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_platform_invoices_on_provider_id"
  end

  create_table "policies", force: :cascade do |t|
    t.integer "quote_result_id", null: false
    t.integer "company_id", null: false
    t.string "policy_number", null: false
    t.string "status", default: "active", null: false
    t.datetime "issued_at"
    t.date "starts_at"
    t.date "ends_at"
    t.integer "premium_cents", default: 0, null: false
    t.string "premium_currency", default: "USD", null: false
    t.integer "total_cents", default: 0, null: false
    t.string "total_currency", default: "USD", null: false
    t.integer "provider_commission_cents", default: 0, null: false
    t.string "provider_commission_currency", default: "USD", null: false
    t.integer "platform_commission_cents", default: 0, null: false
    t.string "platform_commission_currency", default: "USD", null: false
    t.integer "producer_commission_cents", default: 0, null: false
    t.string "producer_commission_currency", default: "USD", null: false
    t.string "producer_commission_status", default: "pending", null: false
    t.datetime "producer_commission_paid_at"
    t.json "webhook_payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_policies_on_company_id"
    t.index ["policy_number"], name: "index_policies_on_policy_number"
    t.index ["quote_result_id"], name: "index_policies_on_quote_result_id"
  end

  create_table "producer_invoice_policies", force: :cascade do |t|
    t.integer "producer_invoice_id", null: false
    t.integer "policy_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_producer_invoice_policies_on_policy_id"
    t.index ["producer_invoice_id", "policy_id"], name: "idx_on_producer_invoice_id_policy_id_afd3703730", unique: true
    t.index ["producer_invoice_id"], name: "index_producer_invoice_policies_on_producer_invoice_id"
  end

  create_table "producer_invoices", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "producer_id", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.integer "total_commission_cents", default: 0, null: false
    t.string "total_commission_currency", default: "USD", null: false
    t.string "status", default: "draft", null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_producer_invoices_on_company_id"
    t.index ["producer_id"], name: "index_producer_invoices_on_producer_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.json "config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_providers_on_slug", unique: true
  end

  create_table "quote_results", force: :cascade do |t|
    t.integer "quote_id", null: false
    t.integer "provider_id", null: false
    t.integer "insurance_plan_id"
    t.string "external_quote_id"
    t.json "raw_response", default: {}
    t.string "status", default: "pending", null: false
    t.integer "price_cents", default: 0, null: false
    t.string "price_currency", default: "USD", null: false
    t.integer "provider_commission_cents", default: 0, null: false
    t.string "provider_commission_currency", default: "USD", null: false
    t.integer "platform_commission_cents", default: 0, null: false
    t.string "platform_commission_currency", default: "USD", null: false
    t.integer "producer_commission_cents", default: 0, null: false
    t.string "producer_commission_currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["insurance_plan_id"], name: "index_quote_results_on_insurance_plan_id"
    t.index ["provider_id"], name: "index_quote_results_on_provider_id"
    t.index ["quote_id"], name: "index_quote_results_on_quote_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "producer_id", null: false
    t.integer "traveler_id"
    t.string "status", default: "draft", null: false
    t.string "public_token"
    t.string "origin", null: false
    t.string "destination", null: false
    t.date "departure_date", null: false
    t.date "return_date"
    t.integer "travelers_count", default: 1, null: false
    t.string "trip_type", default: "single", null: false
    t.json "metadata", default: {}
    t.datetime "completed_at"
    t.string "created_by", default: "producer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_quotes_on_company_id"
    t.index ["producer_id"], name: "index_quotes_on_producer_id"
    t.index ["public_token"], name: "index_quotes_on_public_token", unique: true
    t.index ["traveler_id"], name: "index_quotes_on_traveler_id"
  end

  create_table "travelers", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "producer_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "document"
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_travelers_on_company_id"
    t.index ["producer_id"], name: "index_travelers_on_producer_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_superuser", default: false, null: false
    t.integer "company_id", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "commission_contracts", "providers"
  add_foreign_key "commission_contracts", "users", column: "producer_id"
  add_foreign_key "insurance_plans", "providers"
  add_foreign_key "links", "companies"
  add_foreign_key "links", "quotes"
  add_foreign_key "platform_invoices", "providers"
  add_foreign_key "policies", "companies"
  add_foreign_key "policies", "quote_results"
  add_foreign_key "producer_invoice_policies", "policies"
  add_foreign_key "producer_invoice_policies", "producer_invoices"
  add_foreign_key "producer_invoices", "companies"
  add_foreign_key "producer_invoices", "users", column: "producer_id"
  add_foreign_key "quote_results", "insurance_plans"
  add_foreign_key "quote_results", "providers"
  add_foreign_key "quote_results", "quotes"
  add_foreign_key "quotes", "companies"
  add_foreign_key "quotes", "travelers"
  add_foreign_key "quotes", "users", column: "producer_id"
  add_foreign_key "travelers", "companies"
  add_foreign_key "travelers", "users", column: "producer_id"
  add_foreign_key "users", "companies"
end
