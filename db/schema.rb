# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_05_13_134003) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "banks", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "c_tags", force: :cascade do |t|
    t.string "name"
    t.string "path"
    t.integer "parent_id"
    t.boolean "is_parent", default: false
    t.boolean "disabled", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["parent_id"], name: "index_c_tags_on_parent_id"
  end

  create_table "call_records", force: :cascade do |t|
    t.string "name"
    t.string "company"
    t.string "title"
    t.string "phone"
    t.integer "number_of_calls"
    t.string "status"
    t.string "memo"
    t.bigint "created_by"
    t.bigint "operator_id"
    t.bigint "user_channel_id"
    t.bigint "project_id"
    t.bigint "candidate_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "category"
    t.bigint "project_requirement_id"
    t.string "department"
    t.string "rec_status"
    t.string "rec_description"
    t.bigint "project_task_id"
    t.string "nickname"
    t.string "gender"
    t.string "title1"
    t.string "academic_field"
    t.string "remark"
    t.jsonb "memo_logs", default: []
    t.string "email"
    t.string "city"
    t.index ["candidate_id"], name: "index_call_records_on_candidate_id"
    t.index ["project_id"], name: "index_call_records_on_project_id"
  end

  create_table "candidate_access_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "candidate_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["candidate_id"], name: "index_candidate_access_logs_on_candidate_id"
    t.index ["user_id"], name: "index_candidate_access_logs_on_user_id"
  end

  create_table "candidate_comments", force: :cascade do |t|
    t.bigint "created_by"
    t.bigint "candidate_id"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "is_top", default: false
    t.index ["candidate_id"], name: "index_candidate_comments_on_candidate_id"
  end

  create_table "candidate_experiences", force: :cascade do |t|
    t.bigint "candidate_id"
    t.string "category"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "org_cn"
    t.string "org_en"
    t.string "department"
    t.string "title"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "org_id"
    t.bigint "dep_id"
    t.string "title1"
    t.index ["candidate_id"], name: "index_candidate_experiences_on_candidate_id"
    t.index ["dep_id"], name: "index_candidate_experiences_on_dep_id"
    t.index ["org_id"], name: "index_candidate_experiences_on_org_id"
  end

  create_table "candidate_payment_infos", force: :cascade do |t|
    t.bigint "candidate_id"
    t.string "category"
    t.bigint "created_by"
    t.string "bank"
    t.string "sub_branch"
    t.string "account"
    t.string "username"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "id_number"
    t.index ["candidate_id"], name: "index_candidate_payment_infos_on_candidate_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.string "category"
    t.string "data_source"
    t.bigint "created_by"
    t.bigint "company_id"
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.string "nickname"
    t.string "city"
    t.string "email"
    t.string "email1"
    t.string "phone"
    t.string "phone1"
    t.string "industry"
    t.string "title"
    t.datetime "date_of_birth"
    t.string "gender"
    t.text "description"
    t.boolean "is_available"
    t.decimal "cpt", precision: 10, scale: 2
    t.string "currency"
    t.jsonb "property", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "recommender_id"
    t.string "data_channel"
    t.bigint "user_channel_id"
    t.string "file"
    t.text "expertise"
    t.integer "inquiry"
    t.string "job_status"
    t.string "category2"
    t.string "department"
    t.string "address"
    t.boolean "is_kol", default: false
    t.decimal "coef", precision: 4, scale: 2, default: "0.0"
    t.string "sign_file"
    t.boolean "is_yibao", default: false
    t.boolean "cpt_taxed", default: true
    t.index ["coef"], name: "index_candidates_on_coef"
    t.index ["company_id"], name: "index_candidates_on_company_id"
    t.index ["recommender_id"], name: "index_candidates_on_recommender_id"
    t.index ["user_channel_id"], name: "index_candidates_on_user_channel_id"
  end

  create_table "card_templates", force: :cascade do |t|
    t.string "category"
    t.string "name"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_channel_id"
    t.string "group"
    t.index ["user_channel_id"], name: "index_card_templates_on_user_channel_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "category"
    t.bigint "created_by"
    t.string "name"
    t.string "name_abbr"
    t.string "tax_id"
    t.string "industry"
    t.string "city"
    t.string "address"
    t.string "phone"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "linkman"
    t.string "compliance"
    t.string "compliance_file"
    t.bigint "user_channel_id"
    t.jsonb "property", default: {}
    t.string "consent_file"
    t.jsonb "consent_file_options", default: {}
    t.datetime "last_active_time"
    t.index ["user_channel_id"], name: "index_companies_on_user_channel_id"
  end

  create_table "company_infos", force: :cascade do |t|
    t.bigint "company_summary_id"
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.string "remark"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_summary_id"], name: "index_company_infos_on_company_summary_id"
  end

  create_table "company_summaries", force: :cascade do |t|
    t.bigint "company_id"
    t.datetime "datetime"
    t.bigint "operator_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_company_summaries_on_company_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "created_by"
    t.bigint "company_id"
    t.string "file"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.decimal "charge_rate", precision: 10, scale: 2
    t.string "currency"
    t.string "base_duration"
    t.integer "progressive_duration"
    t.integer "payment_days"
    t.string "type_of_payment_day"
    t.string "payment_way"
    t.boolean "is_taxed"
    t.decimal "tax_rate", precision: 6, scale: 5
    t.boolean "is_invoice_needed"
    t.jsonb "financial_info", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "shorthand_rate", precision: 10, scale: 2
    t.decimal "recruitment_rate", precision: 10, scale: 2
    t.string "expert_level"
    t.index ["company_id"], name: "index_contracts_on_company_id"
  end

  create_table "cost_summaries", force: :cascade do |t|
    t.datetime "datetime"
    t.decimal "price", precision: 10, scale: 2
    t.bigint "operator_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cost_types", force: :cascade do |t|
    t.string "name"
    t.string "path"
    t.integer "parent_id"
    t.boolean "is_parent", default: false
    t.boolean "disabled", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "costs", force: :cascade do |t|
    t.bigint "cost_summary_id"
    t.bigint "cost_type_id"
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.string "remark"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cost_summary_id"], name: "index_costs_on_cost_summary_id"
    t.index ["cost_type_id"], name: "index_costs_on_cost_type_id"
  end

  create_table "czbank_xibaos", force: :cascade do |t|
    t.string "cod_id"
    t.string "org_name"
    t.string "staff_name"
    t.string "staff_id"
    t.integer "sale_value"
    t.datetime "trans_date"
    t.integer "bill_count"
    t.integer "dl_count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "is_public", default: false
    t.datetime "belong_date"
  end

  create_table "hospital_departments", force: :cascade do |t|
    t.bigint "hospital_id"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["hospital_id"], name: "index_hospital_departments_on_hospital_id"
  end

  create_table "hospitals", force: :cascade do |t|
    t.string "name"
    t.string "province"
    t.string "level"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "city"
    t.jsonb "kwlist", default: []
    t.string "category"
  end

  create_table "industries", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "invoice_records", force: :cascade do |t|
    t.bigint "prepaid_client_id", null: false
    t.decimal "amount", default: "0.0", null: false
    t.datetime "invoice_date"
    t.string "invoice_number"
    t.string "file"
    t.datetime "expected_payment_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["prepaid_client_id"], name: "index_invoice_records_on_prepaid_client_id"
  end

  create_table "kpi_infos", force: :cascade do |t|
    t.bigint "kpi_summary_id"
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.string "remark"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["kpi_summary_id"], name: "index_kpi_infos_on_kpi_summary_id"
  end

  create_table "kpi_summaries", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "datetime"
    t.bigint "operator_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_kpi_summaries_on_user_id"
  end

  create_table "location_data", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.integer "level"
    t.bigint "parent_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "medical_insurance_infos", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.integer "year", null: false
    t.boolean "is_clinical", default: false
    t.string "non_clinical_type"
    t.string "sub_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["candidate_id", "year"], name: "index_medical_insurance_infos_on_candidate_id_and_year", unique: true
    t.index ["candidate_id"], name: "index_medical_insurance_infos_on_candidate_id"
  end

  create_table "prepaid_clients", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.decimal "total_hours", default: "0.0", null: false
    t.decimal "invoice_amount", default: "0.0", null: false
    t.datetime "invoice_date"
    t.string "invoice_number"
    t.date "expected_payment_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "invoice_file"
    t.index ["company_id"], name: "index_prepaid_clients_on_company_id"
  end

  create_table "project_candidates", force: :cascade do |t|
    t.string "category"
    t.bigint "project_id"
    t.bigint "candidate_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "mark"
    t.index ["candidate_id"], name: "index_project_candidates_on_candidate_id"
    t.index ["project_id"], name: "index_project_candidates_on_project_id"
  end

  create_table "project_remarks", force: :cascade do |t|
    t.bigint "project_id"
    t.text "remark"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_project_remarks_on_project_id"
  end

  create_table "project_requirements", force: :cascade do |t|
    t.bigint "created_by"
    t.bigint "project_id"
    t.string "status"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "demand_number"
    t.string "file"
    t.bigint "operator_id"
    t.string "title"
    t.string "file1"
    t.string "file2"
    t.string "category"
    t.integer "priority", default: 0
    t.index ["project_id"], name: "index_project_requirements_on_project_id"
  end

  create_table "project_task_costs", force: :cascade do |t|
    t.bigint "project_task_id"
    t.string "category"
    t.decimal "price", precision: 10, scale: 2
    t.string "currency"
    t.string "memo"
    t.string "payment_status"
    t.jsonb "payment_info", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_channel_id"
    t.decimal "lijin", precision: 10, scale: 2
    t.decimal "tax_free_value", precision: 10, scale: 2, default: "0.0"
    t.index ["project_task_id"], name: "index_project_task_costs_on_project_task_id"
    t.index ["user_channel_id"], name: "index_project_task_costs_on_user_channel_id"
  end

  create_table "project_tasks", force: :cascade do |t|
    t.bigint "created_by"
    t.string "category"
    t.bigint "project_id"
    t.bigint "expert_id"
    t.bigint "client_id"
    t.string "status"
    t.string "interview_form"
    t.integer "duration"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "charge_status"
    t.datetime "billed_at"
    t.datetime "charged_at"
    t.integer "charge_days"
    t.datetime "charge_deadline"
    t.string "payment_status"
    t.datetime "paid_at"
    t.decimal "total_price", precision: 10, scale: 2
    t.decimal "charge_rate", precision: 10, scale: 2
    t.decimal "base_price", precision: 10, scale: 2
    t.decimal "actual_price", precision: 10, scale: 2
    t.string "currency"
    t.boolean "is_taxed", default: false
    t.decimal "tax", precision: 10, scale: 2
    t.boolean "is_shorthand", default: false
    t.decimal "shorthand_price", precision: 10, scale: 2
    t.boolean "is_recorded", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "expert_level"
    t.decimal "expert_rate", precision: 20, scale: 18
    t.string "memo"
    t.integer "charge_duration"
    t.bigint "pm_id"
    t.boolean "f_flag", default: false
    t.bigint "user_channel_id"
    t.datetime "notice_email_sent_at"
    t.jsonb "property", default: {}
    t.bigint "candidate_experience_id"
    t.boolean "is_new_expert", default: false
    t.string "jiesuan_file"
    t.jsonb "jiesuan_files", default: []
    t.index ["client_id"], name: "index_project_tasks_on_client_id"
    t.index ["expert_id"], name: "index_project_tasks_on_expert_id"
    t.index ["project_id"], name: "index_project_tasks_on_project_id"
    t.index ["user_channel_id"], name: "index_project_tasks_on_user_channel_id"
  end

  create_table "project_users", force: :cascade do |t|
    t.string "category"
    t.bigint "project_id"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "created_by"
    t.bigint "company_id"
    t.string "name"
    t.string "code"
    t.string "status"
    t.string "industry"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_channel_id"
    t.datetime "billing_at"
    t.datetime "billed_at"
    t.string "invoice_no"
    t.datetime "invoice_payment_date"
    t.decimal "invoice_amount", precision: 10, scale: 2
    t.string "invoice_file"
    t.index ["company_id"], name: "index_projects_on_company_id"
    t.index ["user_channel_id"], name: "index_projects_on_user_channel_id"
  end

  create_table "search_aliases", force: :cascade do |t|
    t.string "name"
    t.jsonb "kwlist", default: []
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "user_channels", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name_cn"
    t.string "name_en"
    t.string "role"
    t.string "title"
    t.string "status"
    t.string "phone"
    t.datetime "date_of_birth"
    t.datetime "date_of_employment"
    t.datetime "date_of_resignation"
    t.integer "candidate_access_limit"
    t.bigint "user_channel_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["user_channel_id"], name: "index_users_on_user_channel_id"
  end

  create_table "yibao_expert_yearly_categories", force: :cascade do |t|
    t.bigint "yibao_expert_id", null: false
    t.integer "year"
    t.string "category_type"
    t.string "sub_category"
    t.string "detail_category"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["yibao_expert_id"], name: "index_yibao_expert_yearly_categories_on_yibao_expert_id"
  end

  create_table "yibao_experts", force: :cascade do |t|
    t.string "name"
    t.string "institution"
    t.string "department"
    t.string "position"
    t.decimal "fee"
    t.integer "willingness"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "invoice_records", "prepaid_clients"
  add_foreign_key "medical_insurance_infos", "candidates"
  add_foreign_key "prepaid_clients", "companies"
  add_foreign_key "project_remarks", "projects"
  add_foreign_key "yibao_expert_yearly_categories", "yibao_experts"
end
