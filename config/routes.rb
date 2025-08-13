
# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  devise_for :users

  root to: 'home#index'
  get 'css_demo', to: 'home#css_demo'
  get 'personal_ranking_ajax', to: 'home#personal_ranking_ajax'
  get 'client_ranking_ajax', to: 'home#client_ranking_ajax'

  resources :api, :only => [] do
    post :createExpert, on: :collection
  end

  resources :utils do
    get :loading_modal, on: :collection
  end

  resource :event_stream do
    get :test
  end

  resources :users do
    post :admin_create,      on: :collection  # create users by admin
    get :edit_password,      on: :member
    put :edit_password,      on: :member

    get :my_account,         on: :collection
    get :edit_my_account,    on: :collection
    put :edit_my_account,    on: :collection
    get :edit_my_password,   on: :collection
    put :edit_my_password,   on: :collection
    get :edit_my_user_channel, on: :collection
    put :edit_my_user_channel, on: :collection

    get :v_staff_options, on: :collection
  end

  resources :user_channels do
    get :new_admin,     on: :member
    post :create_admin, on: :member
  end
  
  resources :candidates do
    put :update_is_available,  on: :member

    get :add_experience, on: :collection
    get :show_phone,     on: :member      # show candidate phone.js
    get :gen_card,       on: :collection
    get :expert_template,on: :collection

    get :import_expert,  on: :collection  # show importing result
    post :import_expert, on: :collection  # import experts with excel

    get :payment_infos,        on: :member
    get :new_payment_info,     on: :member
    post :create_payment_info, on: :member
    get :project_tasks,        on: :member
    get :comments,             on: :member
    get :call_records,         on: :member

    get :expert_info_for_clipboard, on: :member
    get :recommender_info, on: :collection

    get :loading_modal, on: :collection
    post :batch_update_file, on: :collection  # 批量更新附件
    get :new_call_record, on: :member
    get :yibao, on: :collection
    get :load_work_experiences_for_project_task, on: :member

    get :v_index, on: :collection
    get :v_index_data, on: :collection
  end

  resources :candidate_payment_infos
  resources :candidate_comments

  resources :doctors do
    get :import_haodf,  on: :collection  # show importing result
    post :import_haodf, on: :collection  # import doctors from haodf data
  end

  resources :clients do
    get :import_client, on: :collection
    post :import_client, on: :collection
  end

  resources :companies do
    resources :contracts, only: [:new, :create]
    get :load_client_options, on: :member
    get :new_contract, on: :member
  end

  resources :prepaid_clients do
    get :new_contract, on: :member
  end

  resources :contracts

  resources :projects do
    get :add_users,   on: :collection   # 添加项目参与人
    put :add_users,   on: :collection
    get :add_experts, on: :collection   # 添加专家
    put :add_experts, on: :collection
    get :add_clients, on: :member       # 添加客户
    put :add_clients, on: :member
    get :add_project_task, on: :member
    put :add_project_task, on: :member
    get :add_project_requirement, on: :member
    put :add_project_requirement, on: :member
    get :edit_finance, on: :member      # 编辑项目财务信息


    delete :delete_user,   on: :member  # 删除项目参与人
    delete :delete_expert, on: :member  # 删除专家
    delete :delete_client, on: :member  # 删除客户

    post :start, on: :member
    post :finish, on: :member
    post :billing, on: :member
    post :billed, on: :member

    get :batch_update_status, on: :collection

    get :experts,       on: :member
    get :project_tasks, on: :member
    get :user_options,  on: :member  # 加载项目用户账号信息

    post :export_billing_excel, on: :member  # 导出项目出账模板

    get :work_board, on: :collection
    get :load_project_requirements, on: :collection

    # get :v_dashboard, on: :collection
    # get :v_dashboard_data, on: :collection

    get :v_pm_dashboard, on: :collection
    get :v_pm_dashboard_data, on: :collection
    
    get :v_pa_dashboard, on: :collection
    get :v_pa_dashboard_data, on: :collection

    patch :update_finance, on: :member  # 更新项目财务信息

  end

  resources :project_requirements do
    put :finish,   on: :member
    put :unfinish, on: :member
    put :cancel,   on: :member

    get :edit_operator, on: :member
    put :update_operator, on: :member

    post :v_create, on: :collection
    post :v_update, on: :collection
    get :v_show, on: :collection
    post :v_update_demand_number, on: :collection
  end

  resources :project_candidates do
    put :update_mark, on: :member
  end

  resources :project_tasks do
    get :get_base_price, on: :member  # 计算基础价格(实时)
    post :add_cost,      on: :member  # 添加支出信息
    delete :remove_cost, on: :member  # 删除支出信息
    get :edit_cost,      on: :member
    patch :update_cost,   on: :member
    get :draw_consent,   on: :member  # 生成知情同意书

    put :cancel,         on: :member  # 取消任务
    put :moveto,         on: :member  # 转移任务

    post :v_upload_jiesuan_file, on: :member
    post :v_remove_jiesuan_file, on: :member
  end

  resources :finance do
    put :return_back, on: :member

    get :batch_update_charge_status,  on: :collection
    get :batch_update_payment_status, on: :collection
    get :export_finance_excel,        on: :collection
  end

  resources :call_records do
    get :edit_operator, on: :member
    put :update_operator, on: :member
    put :after_call, on: :member
    get :add_to_candidate, on: :member

    post :batch_import, on: :collection

    get :remote_index, on: :collection
    post :remote_create, on: :collection
    post :remote_update, on: :member
    post :remote_update_silent, on: :member
    post :remote_delete, on: :member
    post :remote_import, on: :collection

    post :remote_create_for_candidate, on: :collection

    post :two_way_call, on: :collection

    get :v_index, on: :collection
    get :v_load_index, on: :collection

    post :v_create, on: :collection 
    post :v_create_batch, on: :collection
    post :v_update, on: :collection
    get :v_match_candidates, on: :collection
    post :v_ruku, on: :collection
    post :v_tuijian, on: :collection
  end

  resources :location_data do
    get :autocomplete_city, on: :collection
    get :show_phone_location, on: :collection
    get :load_children, on: :collection
    get :province_options, on: :collection
  end
  resources :hospitals do
    post :create_department, on: :member
    post :delete_department, on: :member

    get :load_departments, on: :member
    get :change_hospital_for_doctor_form, on: :member
    # get :load_hospital_options, on: :collection
    get :hospital_options, on: :collection
    get :load_children, on: :member

    post :v_create_department, on: :collection
  end
  resources :banks
  resources :industries
  resources :search_aliases
  resources :card_templates do
    get :v_group_index, on: :collection
    get :v_apply, on: :collection
  end

  resources :statistics do
    get :current_month_count_infos,  on: :collection
    get :current_month_task_ranking, on: :collection
    # get :unscheduled_projects,       on: :collection
    get :wait_to_bill_projects,      on: :collection
    get :ongoing_project_requirements, on: :collection
    get :ongoing_project_tasks,      on: :collection

    get :finance_summary,            on: :collection
    get :expense_summary,            on: :collection
    get :finance_dashboard,          on: :collection
    get :total_performance,          on: :collection
    get :client_statistics,          on: :collection
    get :company_monthly_statistics, on: :collection
    get :employee_statistics,        on: :collection
    get :employee_monthly_statistics, on: :collection

    get :v_monthly_new, on: :collection

    get :v_ongoing_sta, on: :collection

    get :v_client_zhuanhualv, on: :collection
    get :v_client_zhuanhualv_data, on: :collection
    patch :update_project_payment_date, on: :collection
  end

  resources :extras do
    get :import_gllue_candidates,  on: :collection
    post :import_gllue_candidates, on: :collection
  end

  resources :costs do
    get :v_summary_show, on: :collection
    get :v_summary_new, on: :collection
    post :v_summary_create, on: :collection
    get :v_summary_edit, on: :collection
    post :v_summary_update, on: :collection
    get :v_types, on: :collection
    get :v_load_types, on: :collection
    post :create_cost_type, on: :collection
    post :update_cost_type, on: :collection
    post :delete_cost_type, on: :collection
    get :summary_chart, on: :collection
    get :summary_chart_data, on: :collection
  end

  resources :kpi_summaries do
    get :v_index, on: :collection
    get :v_summary_new, on: :collection
    post :v_summary_create, on: :collection
    get :v_summary_edit, on: :collection
    post :v_summary_update, on: :collection
    get :v_summary_show, on: :collection
    get :v_summary_init, on: :collection
  end

  resources :company_summaries do
    get :v_index, on: :collection
    get :v_summary_new, on: :collection
    post :v_summary_create, on: :collection
    get :v_summary_edit, on: :collection
    post :v_summary_update, on: :collection
    get :v_summary_show, on: :collection
    get :v_summary_init, on: :collection
    get :v_summary_chart, on: :collection

    get :v_company_options, on: :collection
  end

  resources :c_tags do
  end

  # tmp utils for czbank
  resources :czbank do
    get :xibao, on: :collection
    post :xibao_create, on: :collection
    post :xibao_import, on: :collection

    get :xibao_list, on: :collection
    get :xibao_gen_pic, on: :collection
  end
end
