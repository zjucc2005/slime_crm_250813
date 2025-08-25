# encoding: utf-8
class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.email == 'cinney.wu@hci-consulting.com'
      load_dashboard_of_cinney
    elsif current_user.is_role?('su', 'admin', 'finance')
      load_dashboard_of_admin
    elsif current_user.is_role?('pm', 'pd')
      load_dashboard_of_pm
    elsif current_user.is_role?('pa')
      load_dashboard_of_pa
    end
  end

  def css_demo
    arr = [2,3,5]
    arr.inject(:*)
  end

  # AJAX接口：获取个人小时数排名
  def personal_ranking_ajax
    s_month = if params[:month].present?
                begin
                  if params[:month].to_s.match?(/^\d{13}$/) # 判断是否为时间戳格式（13位数字）
                    Time.at(params[:month].to_i / 1000).beginning_of_month
                  else
                    "#{params[:month]}-01".to_time
                  end
                rescue => e
                  Time.now.beginning_of_month
                end
              else
                Time.now.beginning_of_month
              end
    
    ranking = calculate_personal_ranking(s_month)
    
    respond_to do |format|
      format.json { render json: { ranking: ranking } }
    end
  end

  # AJAX接口：获取客户小时数排名
  def client_ranking_ajax
    s_month = if params[:month].present?
                begin
                  if params[:month].to_s.match?(/^\d{13}$/) # 判断是否为时间戳格式（13位数字）
                    Time.at(params[:month].to_i / 1000).beginning_of_month
                  else
                    "#{params[:month]}-01".to_time
                  end
                rescue => e
                  Time.now.beginning_of_month
                end
              else
                Time.now.beginning_of_month
              end
    
    client_ranking = calculate_client_ranking_for_cinney(s_month)
    
    respond_to do |format|
      format.json { render json: { client_ranking: client_ranking } }
    end
  end

  private
  def load_dashboard_of_admin
    @total_experts              = user_channel_filter(Candidate.where(category: %w[expert doctor])).count
    @total_signed_companies     = user_channel_filter(Company.signed).count
    @total_tasks                = user_channel_filter(ProjectTask.where(status: 'finished')).count
    @total_tasks_of_new_expert  = user_channel_filter(ProjectTask.where(status: 'finished', is_new_expert: true)).count
    @total_charge_duration_hour = ( user_channel_filter(ProjectTask.where(status: 'finished')).sum(:charge_duration) / 60.0).round(1)
  end

  def load_dashboard_of_pm
    @total_experts              = Candidate.where(category: %w[expert doctor]).where(created_by: current_user.id).count
    @total_tasks                = ProjectTask.where(status: 'finished', created_by: current_user.id).count
    @total_charge_duration_hour = (ProjectTask.where(status: 'finished', created_by: current_user.id).sum(:charge_duration) / 60.0).round(1)
    @self_hour_monthly = (ProjectTask.where(status: 'finished', created_by: current_user.id).where('started_at >= ?', current_month).sum(:charge_duration) / 60.0).round(1)
    @manage_hour_monthly = (ProjectTask.where(status: 'finished', pm_id: current_user.id).where.not(created_by: current_user.id).where('started_at >= ?', current_month).sum(:charge_duration) / 60.0).round(1)

    query = ProjectTask.where('created_by = :uid OR pm_id = :uid', uid: current_user.id)
    @project_tasks = query.order(status: :desc, started_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  def load_dashboard_of_pa
    @total_experts              = Candidate.where(category: %w[expert doctor]).where(created_by: current_user.id).count
    @total_tasks                = ProjectTask.where(status: 'finished', created_by: current_user.id).count
    @total_charge_duration_hour = (ProjectTask.where(status: 'finished', created_by: current_user.id).sum(:charge_duration) / 60.0).round(1)
    @self_hour_monthly = (ProjectTask.where(status: 'finished', created_by: current_user.id).where('started_at >= ?', current_month).sum(:charge_duration) / 60.0).round(1)

    query = ProjectTask.where('created_by = :uid OR pm_id = :uid', uid: current_user.id)
    @project_tasks = query.order(status: :desc, started_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  def load_dashboard_of_cinney
    current_month = Time.now.beginning_of_month
    
    # 当月推荐专家总个数：call_records表rec_status字段等于recommended且created_at字段在当前月份的数量
    @monthly_recommended_experts = CallRecord.where(rec_status: 'recommended')
                                            .where('created_at BETWEEN ? AND ?', current_month, current_month + 1.month)
                                            .count
    
    # 当月需求人数：project_requirements表的created_at字段在当前月份，对符合条件记录的demand_number字段求和
    @monthly_demand_number = ProjectRequirement.where('created_at BETWEEN ? AND ?', current_month, current_month + 1.month)
                                              .sum(:demand_number)
    
    # 收到需求总个数：project_requirements表的created_at字段在当前月份的数量
    @monthly_requirements_count = ProjectRequirement.where('created_at BETWEEN ? AND ?', current_month, current_month + 1.month)
                                                   .count
    
    # 本月新增统计数据（与admin权限相同的逻辑，但排除特定项目）
    project_task_query = ProjectTask.where(status: 'finished', currency: 'RMB').where('started_at >= ?', current_month)
    project_task_query = user_channel_filter(project_task_query)
    
    total_experts = user_channel_filter(Candidate.where(category: %w[expert doctor]).where('created_at >= ?', current_month)).count
    total_tasks = project_task_query.count
    total_charge_duration_hour = (project_task_query.sum(:charge_duration) / 60.0).round(1)
    total_income = project_task_query.sum(:actual_price)
    
    # 构建与admin相同格式的统计数据数组
    @current_month_count_infos = [
      { :name => t('dashboard.total_experts'),              :value => total_experts,              :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_tasks'),                :value => total_tasks,                :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_charge_duration_hour'), :value => total_charge_duration_hour, :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_income'),               :value => total_income,               :url => finance_summary_statistics_path }
    ]
    
    # 进展中的项目任务
    ongoing_query = ProjectTask.where(status: 'ongoing').order(:started_at => :asc)
    ongoing_query = user_channel_filter(ongoing_query)
    @ongoing_project_tasks = ongoing_query.limit(10)
    
    # 月份选项（用于筛选）- 从当前月份开始，按倒序排列
    @month_options = []
    start_month = Time.new(2019, 1, 1).beginning_of_month
    months = (current_month.year * 12 + current_month.month) - (start_month.year * 12 + start_month.month)
    months.downto(0) do |i|
      _month_ = current_month - i.month
      @month_options << [_month_.strftime('%Y-%m'), _month_.strftime('%F')]
    end
    
    # 个人小时数排名（当月）
    @current_month_task_ranking = calculate_personal_ranking(current_month)
    
    # 客户小时数排名（当月）
    @client_ranking = calculate_client_ranking_for_cinney(current_month)
  end
  
  def calculate_personal_ranking(s_month)
    result = []
    # cinney.wu@hci-consulting.com 用户在首页拥有查看所有用户数据的权限
    if current_user.admin? || current_user.finance? || current_user.email == 'cinney.wu@hci-consulting.com'
      users = User.where(role: %w[admin pm pa])  # 所有用户(包括未激活) + 角色admin/pm/pa
    else
      users = User.where(id: current_user.id)
    end
    users = user_channel_filter(users)
    project_tasks = ProjectTask.where(status: 'finished').where('started_at BETWEEN ? AND ?', s_month, s_month + 1.month)
    project_requirements = ProjectRequirement.where.not(status: 'cancelled').where('created_at BETWEEN ? AND ?', s_month, s_month + 1.month)
    call_records = CallRecord.where('created_at BETWEEN ? AND ?', s_month, s_month + 1.month)
    
    users.each do |user|
      if user.is_role?('admin', 'pm')
        interview_minutes = project_tasks.where(created_by: user.id).sum(:charge_duration)
        manage_minutes = project_tasks.where(pm_id: user.id).where.not(created_by: user.id).sum(:charge_duration)
      else
        interview_minutes = project_tasks.where(created_by: user.id).sum(:charge_duration)
        manage_minutes = 0.0
      end
      
      sum_demand = project_requirements.where(operator_id: user.id).sum(:demand_number)
      sum_succ = call_records.where(rec_status: 'succ', created_by: user.id).count
      total_minutes = interview_minutes + manage_minutes
      
      if total_minutes > 0
        new_expert_count = project_tasks.where(created_by: user.id, is_new_expert: true).count
        new_expert_rate = new_expert_count.zero? ? 0 : new_expert_count.to_f / project_tasks.where(created_by: user.id).count
        
        result << {
          username: user.name_cn,
          interview_minutes: interview_minutes,
          manage_minutes: manage_minutes,
          total_minutes: total_minutes,
          new_expert_rate: new_expert_rate,
          new_expert_count: new_expert_count,
          zhuanhualv: sum_demand.zero? ? 0 : (sum_succ.to_f / sum_demand).round(3)
        }
      end
    end
    
    result.sort_by{|e| e[:total_minutes]}.reverse
  end
  
  def calculate_client_ranking_for_cinney(month)
    client_data = {}
    
    # 查询当月完成的项目任务
    finished_tasks = ProjectTask.where(status: 'finished')
                                .where('started_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 按客户分组统计数据
    finished_tasks.includes(project: [:company]).each do |task|
      next unless task.project && task.project.company
      
      company_id = task.project.company_id
      company_name = task.project.company.name
      
      client_data[company_id] ||= {
        name: company_name,
        company_id: company_id,
        total_income: 0,
        total_hours: 0
      }
      
      # 累计收入
      client_data[company_id][:total_income] += (task.actual_price || 0).to_f
      
      # 累计小时数（分钟转小时）
      client_data[company_id][:total_hours] += (task.charge_duration || 0).to_f / 60.0
    end
    
    # 计算转化率
    client_data.each do |company_id, data|
      # 获取该公司当月创建的项目
      company_monthly_projects = Project.where('created_at BETWEEN ? AND ?', month, month + 1.month)
                                        .where(company_id: company_id)
      company_monthly_project_ids = company_monthly_projects.pluck(:id)
      
      # 成功访谈数
      company_succ_count = CallRecord.where(rec_status: 'succ')
                                     .where(project_id: company_monthly_project_ids)
                                     .count
      
      # 需求人数总和
      company_demand_sum = ProjectRequirement.where.not(status: 'cancelled')
                                             .where(project_id: company_monthly_project_ids)
                                             .sum(:demand_number)
      
      # 计算转化率
      data[:completion_rate] = company_demand_sum.zero? ? 0 : ((company_succ_count.to_f / company_demand_sum) * 100).round(2)
      
      # 四舍五入小时数
      data[:total_hours] = data[:total_hours].round(2)
    end
    
    # 按客户小时数排序
    client_data.values.sort_by { |data| -data[:total_hours] }
  end

  def current_month
    Time.now.beginning_of_month
  end
end