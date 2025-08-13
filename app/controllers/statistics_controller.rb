# encoding: utf-8
class StatisticsController < ApplicationController
  before_action :authenticate_user!
  # load_and_authorize_resource

  # GET /statistics/current_month_count_infos.js
  def current_month_count_infos
    current_month = Time.now.beginning_of_month
    project_task_query = ProjectTask.where(status: 'finished', currency: 'RMB').where('started_at >= ?', current_month)
    project_task_query = user_channel_filter(project_task_query)
    project_task_cost_query = ProjectTaskCost.joins(:project_task).where('project_tasks.status': 'finished', 'project_task_costs.currency': 'RMB').
      where('project_tasks.started_at >= ?', current_month).where('project_task_costs.category': 'expert')
    project_task_cost_query = user_channel_filter(project_task_cost_query)

    total_experts              = user_channel_filter(Candidate.where(category: %w[expert doctor]).where('created_at >= ?', current_month)).count
    total_tasks                = project_task_query.count
    total_charge_duration_hour = (project_task_query.sum(:charge_duration) / 60.0).round(1)
    total_income               = project_task_query.sum(:actual_price)
    total_income_unbilled      = project_task_query.where('project_tasks.charge_status' => 'unbilled').sum(:actual_price)
    total_income_billed        = project_task_query.where('project_tasks.charge_status' => 'billed').sum(:actual_price)
    total_expert_fee           = project_task_cost_query.sum('project_task_costs.price')
    total_expert_fee_unpaid    = project_task_cost_query.where('project_tasks.payment_status' => 'unpaid').sum('project_task_costs.price')
    if total_charge_duration_hour.zero?
      premium_charge_rate = 0
    else
      premium_charge_rate = project_task_query.where(expert_level: 'premium').sum(:charge_duration).to_f / project_task_query.sum(:charge_duration)
    end

    # 基础统计项
    base_infos = [
      { :name => t('dashboard.total_experts'),              :value => total_experts,              :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_tasks'),                :value => total_tasks,                :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_charge_duration_hour'), :value => total_charge_duration_hour, :url => v_monthly_new_statistics_path },
      { :name => t('dashboard.total_income'),               :value => total_income,               :url => finance_summary_statistics_path }
    ]
    
    # 针对特定用户cinney.wu@hci-consulting.com隐藏的统计项
    excluded_items_for_cinney = [
      { :name => t('dashboard.total_income_unbilled'),      :value => total_income_unbilled,      :url => nil },
      { :name => t('dashboard.total_income_billed'),        :value => total_income_billed,        :url => nil },
      { :name => t('dashboard.total_expert_fee'),           :value => total_expert_fee,           :url => finance_summary_statistics_path },
      { :name => t('dashboard.total_expert_fee_unpaid'),    :value => total_expert_fee_unpaid,    :url => nil },
      { name: t('dashboard.premium_charge_rate'), value: "#{(premium_charge_rate * 100).round(1)} %", url: nil }
    ]
    
    # 根据用户邮箱决定显示哪些统计项
    if current_user.email == 'cinney.wu@hci-consulting.com'
      @current_month_count_infos = base_infos
    else
      @current_month_count_infos = base_infos + excluded_items_for_cinney
    end

    respond_to do |f|
      f.js
    end
  end

  # GET /statistics/current_month_task_ranking?limit=10
  def current_month_task_ranking
    # 最近三个月份
    current_month = Time.now.beginning_of_month
    @month_options = []
    start_month = Time.new(2000, 1, 1).beginning_of_month
    months = (current_month.year * 12 + current_month.month) - (start_month.year * 12 + start_month.month)
    months.downto(0) do |i|
      _month_ = current_month - i.month
      @month_options << [_month_.strftime('%Y-%m'), _month_.strftime('%F')]
    end

    s_month = (params[:month].to_time rescue nil) || current_month  # 统计月份
    result = []
    if current_user.admin? || current_user.finance?
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
        manage_minutes_group = project_tasks.where(pm_id: user.id).where.not(created_by: user.id).
                               select('created_by, sum(charge_duration) as charge_duration').group(:created_by)
        manage_minutes_detail = manage_minutes_group.map{ |item|
          { username: User.find(item.created_by)&.name_cn, interview_minutes: item.charge_duration }
        }
      else
        interview_minutes = project_tasks.where(created_by: user.id).sum(:charge_duration)
        manage_minutes = 0.0
        manage_minutes_detail = []
      end
      sum_demand = project_requirements.where(operator_id: user.id).sum(:demand_number)
      sum_succ = call_records.where(rec_status: 'succ', created_by: user.id).count
      total_minutes = interview_minutes + manage_minutes
      if total_minutes > 0
        new_expert_count = project_tasks.where(created_by: user.id, is_new_expert: true).count
        new_expert_rate = new_expert_count.zero? ?
          0 : new_expert_count.to_f / project_tasks.where(created_by: user.id).count
        result << { 
          username: user.name_cn,
          interview_minutes: interview_minutes,
          manage_minutes: manage_minutes,
          manage_minutes_detail: manage_minutes_detail,
          total_minutes: total_minutes,
          new_expert_rate: new_expert_rate,
          zhuanhualv: sum_demand.zero? ? 0 : (sum_succ.to_f / sum_demand).round(3)
        }
      end

      # pm_minutes = project_tasks.where(pm_id: user.id).sum(:charge_duration) * 0.5       # 权重 0.5
      # pa_minutes = project_tasks.where(created_by: user.id).sum(:charge_duration) * 0.5  # 权重 0.5
      # total_minutes = pm_minutes + pa_minutes
      # if total_minutes > 0
      #   result << { :username => user.name_cn, :pm_minutes => pm_minutes, :pa_minutes => pa_minutes, :total_minutes => total_minutes }
      # end
    end

    @current_month_task_ranking = result.sort_by{|e| e[:total_minutes]}.reverse
    respond_to do |f|
      f.js
      f.html
      f.json { render json: { ranking: @current_month_task_ranking } }
    end
  end

  # GET /statistics/unscheduled_projects.js
  # def unscheduled_projects
  #   query = Project.where(status: 'initialized').order(:created_at => :asc)
  #   query = user_channel_filter(query)
  #   query = query.limit(params[:limit]) if params[:limit].present?
  #   @projects = query
  #
  #   respond_to do |f|
  #     f.js
  #   end
  # end

  def wait_to_bill_projects
    company_ids = Contract.available.where(payment_way: 'by_project').pluck(:company_id)
    query = Project.joins(:project_tasks).where(
      'projects.company_id': company_ids, 
      'projects.status': 'ongoing', 
      'project_tasks.status': 'finished', 
      'project_tasks.charge_status': 'unbilled'
      ).where('projects.updated_at <= ?', Time.now - 60.days).distinct
    query = user_channel_filter(query, 'projects.user_channel_id')
    @count = query.count
    query = query.limit(params[:limit]) if params[:limit].present?
    @projects = query.order(:id)
  end

  # GET /statistics/ongoing_project_requirements.js
  def ongoing_project_requirements
    query = ProjectRequirement.joins(:project).where('project_requirements.status': 'ongoing').order(:created_at => :desc)
    query = user_channel_filter(query, 'projects.user_channel_id')
    query = query.limit(params[:limit]) if params[:limit].present?
    @project_requirements = query

    respond_to do |f|
      f.js
    end
  end

  # GET /statistics/ongoing_project_tasks
  def ongoing_project_tasks
    query = ProjectTask.where(status: 'ongoing').order(:started_at => :asc)
    query = user_channel_filter(query)
    @count = query.count
    query = query.limit(params[:limit]) if params[:limit].present?
    @project_tasks = query
  end

  # GET /statistics/finance_dashboard
  def update_project_payment_date
    @project = Project.find(params[:id])
    if @project.update(invoice_payment_date: params[:invoice_payment_date])
      render json: { status: 'success' }
    else
      render json: { status: 'error', message: '项目更新失败' }
    end
  end

  def finance_dashboard
    current_month = Time.now.beginning_of_month
    @month_options = []
    start_month = Time.new(2000, 1, 1).beginning_of_month
    end_month = current_month + 10.years
    start_months = (current_month.year * 12 + current_month.month) - (start_month.year * 12 + start_month.month)
    end_months = (end_month.year * 12 + end_month.month) - (current_month.year * 12 + current_month.month)
    # 生成所有月份选项并去重
    (-start_months..end_months).each do |i|
      _month_ = current_month + i.month
      @month_options << [_month_.strftime('%Y-%m'), _month_.strftime('%F')]
    end
    @month_options.uniq!

    # 设置默认月份为当前月份
    params[:month] ||= current_month.strftime('%F')

    @currency = 'RMB'
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id

    # 初始化数据统计变量
    @unbilled_total = 0
    @receivable_total = 0
    @billed_total = 0
    @received_total = 0

    # 基础查询
    base_query = Project.includes(:company)

    if @user_channel_id.present?
      base_query = base_query.where(user_channel_id: @user_channel_id)
    end

    # 按公司筛选
    if params[:company_id].present?
      base_query = base_query.where(company_id: params[:company_id])
    end

    # 根据搜索类型设置统计逻辑
    if params[:search_type] == 'all_to_date'  
      # 待开票金额：项目状态为ongoing的项目总金额
      @unbilled_total = base_query.where(status: 'ongoing').joins(:project_tasks).sum('project_tasks.total_price')

      # 应收款金额：三个月前的已开票项目的发票金额总和
      @receivable_total = base_query.where(status: 'billing')
        .sum(:invoice_amount)

      # 已开票金额：所有已开票项目的发票金额总和
      @billed_total = base_query.where(status: 'billing').sum(:invoice_amount)

      # 已收款金额：所有已收款项目的发票金额总和
      @received_total = base_query.where(status: 'billed').sum(:invoice_amount)
    else
      selected_month = (params[:month].to_time rescue nil) || current_month

      # 待开票金额：三个月前开始的ongoing项目总金额
      @unbilled_total = base_query.where(status: 'ongoing')
        .joins(:project_tasks)
        .sum('project_tasks.total_price')

      # 应收款金额：三个月前开票的项目发票金额总和
      @receivable_total = base_query.where(status: 'billing')
        .where('billing_at <= ?', selected_month - 3.months)
        .sum(:invoice_amount)

      # 已开票金额：当月开票的项目发票金额总和
      @billed_total = base_query.where(status: 'billing')
        .where('billing_at BETWEEN ? AND ?', selected_month, selected_month + 1.month)
        .sum(:invoice_amount)

      # 已收款金额：当月收款的项目发票金额总和
      @received_total = base_query.where(status: 'billed')
        .where('billed_at BETWEEN ? AND ?', selected_month, selected_month + 1.month)
        .sum(:invoice_amount)
    end

    # 获取项目列表用于显示
    # 根据搜索类型筛选项目
    project_query = base_query.where(status: ['ongoing', 'billing', 'billed'])
    if params[:search_type] == 'all_to_date'
      # 不需要额外的时间筛选
    else
      selected_month = (params[:month].to_time rescue nil) || current_month
      project_query = project_query.joins(:project_tasks).where('project_tasks.started_at BETWEEN ? AND ?', selected_month, selected_month + 1.month).distinct
    end

    # 按项目状态筛选
    if params[:project_status].present?
      if params[:project_status] == 'needs_settlement'
        # 需结算状态的特殊处理将在后面的map中处理
        project_query = project_query.where(status: ['ongoing', 'billing', 'billed'])
      else
        project_query = project_query.where(status: params[:project_status])
      end
    end

    # 按预计收款时间筛选
    if params[:payment_date_start].present? || params[:payment_date_end].present?
      if params[:payment_date_start].present?
        project_query = project_query.where('invoice_payment_date >= ?', params[:payment_date_start])
      end
      if params[:payment_date_end].present?
        project_query = project_query.where('invoice_payment_date <= ?', params[:payment_date_end])
      end
    end

    @projects = project_query.order(created_at: :desc).map do |project|
      project.instance_eval do
        define_singleton_method(:total_price) { project_tasks.sum(:total_price) }
        define_singleton_method(:billed_amount) { invoice_amount }
        define_singleton_method(:billed_at) { billing_at }
        define_singleton_method(:expected_payment_date) { invoice_payment_date }
        define_singleton_method(:invoice_number) { invoice_no }
        
        # 检查最近两个月是否有通话记录
        two_months_ago = Time.now - 2.months
        has_recent_calls = CallRecord.where(project_id: id)
                                   .where('created_at >= ?', two_months_ago)
                                   .exists?
        define_singleton_method(:needs_settlement?) { !has_recent_calls }
      end

      # 不再在这里更新统计数据，因为已经在前面统计过了

      project
    end

    # 如果筛选条件是"需结算"，则过滤出需要结算的项目
    if params[:project_status] == 'needs_settlement'
      @projects = @projects.select(&:needs_settlement?)
    end
  end

  # GET /statistics/finance_summary
  def finance_summary
    # current_year = Time.now.year
    # @year_options = (2020..current_year).to_a.reverse              # year options
    # @year = params[:year] || current_year                          # statistical year
    # @currency = params[:currency] || 'RMB'                         # currency
    # @user_channel_id = params[:user_channel_id] || current_user.user_channel_id  # user_channel_id
    # @company_id = params[:company_id]
    # @x_axis = I18n.locale == :zh_cn ?
    #   %w[1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月] : %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

    current_year = Time.now.year
    @year_options = ['无'] + (2020..current_year).to_a.reverse    # year options
    if ['无', '', nil].include?(params[:year])
      @year = nil
      o_time = Time.now.beginning_of_month - 11.months # start time
    else
      @year = params[:year] || current_year  # statistical year
      o_time = Time.local @year
    end
    @currency = params[:currency] || 'RMB'                         # currency
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id  # user_channel_id
    @company_id = params[:company_id]
    @x_axis = []
    # annual total infos
    income              = []
    expense             = []
    profit              = []
    expense_expert      = []
    expense_expert_tax  = []
    expense_recommend   = []
    expense_translation = []
    expense_others      = []

    if @company_id.present?
      project_task_query = ProjectTask.joins(:project).
        where('projects.company_id': @company_id, 'project_tasks.status': 'finished', 'project_tasks.currency': @currency)
      project_task_cost_query = ProjectTaskCost.joins(:project_task).joins('LEFT JOIN projects on projects.id = project_tasks.project_id').
        where('projects.company_id': @company_id, 'project_tasks.status': 'finished', 'project_task_costs.currency': @currency)
    else
      project_task_query = ProjectTask.where(status: 'finished', currency: @currency)
      project_task_cost_query = ProjectTaskCost.joins(:project_task).where('project_tasks.status': 'finished', 'project_task_costs.currency': @currency)
    end
    if @user_channel_id.present?
      project_task_query = project_task_query.where(user_channel_id: @user_channel_id)
      project_task_cost_query = project_task_cost_query.where(user_channel_id: @user_channel_id)
    end

    12.times do |i|
      s_time = o_time + i.month  # start time
      e_time = s_time + 1.month  # end time

      cost_group = project_task_cost_query.where('project_tasks.started_at BETWEEN ? AND ?', s_time, e_time).
        select('SUM(project_task_costs.price) AS sum_price, project_task_costs.category').group('project_task_costs.category')

      expert_fee      = cost_group.select{|c| c.category == 'expert' }[0].try(:sum_price)      || 0.0
      expert_tax_fee  = cost_group.select{|c| c.category == 'expert_tax' }[0].try(:sum_price)  || 0.0
      recommend_fee   = cost_group.select{|c| c.category == 'recommend' }[0].try(:sum_price)   || 0.0
      translation_fee = cost_group.select{|c| c.category == 'translation' }[0].try(:sum_price) || 0.0
      others_fee      = cost_group.select{|c| c.category == 'others' }[0].try(:sum_price)      || 0.0
      total_in = project_task_query.where('project_tasks.started_at BETWEEN ? AND ?', s_time, e_time).sum(:actual_price)
      total_ex = expert_fee + expert_tax_fee + recommend_fee + translation_fee + others_fee

      income << total_in
      expense << total_ex
      profit << total_in - total_ex
      expense_expert << expert_fee
      expense_expert_tax << expert_tax_fee
      expense_recommend << recommend_fee
      expense_translation << translation_fee
      expense_others << others_fee
      @x_axis << s_time.strftime('%Y.%m')
    end


    @result = [
      { name: t('dashboard.total_income'), data: income },
      { name: t('dashboard.expense'), data: expense },
      { name: t('dashboard.profit'), data: profit }
      # { :name => t('dashboard.expense_expert'), :data => expense_expert, :stack => t('dashboard.expense') },
      # { :name => t('dashboard.expense_recommend'), :data => expense_recommend, :stack => t('dashboard.expense') },
      # { :name => t('dashboard.expense_translation'), :data => expense_translation, :stack => t('dashboard.expense') },
      # { :name => t('dashboard.expense_others'), :data => expense_others, :stack => t('dashboard.expense') },
    ]

    @annual_count_infos = [
      { name: t('dashboard.total_income'), value: income.sum },
      { name: t('dashboard.expense'), value: expense.sum },
      { name: t('dashboard.expense_expert'), value: expense_expert.sum },
      { name: '税费（专家费用）', value: expense_expert_tax.sum },
      { name: t('dashboard.expense_recommend'), value: expense_recommend.sum },
      { name: t('dashboard.expense_translation'), value: expense_translation.sum },
      { name: t('dashboard.expense_others'), value: expense_others.sum }
    ]
  end
  
  # GET /statistics/expense_summary
  def expense_summary
    current_year = Time.now.year
    @year_options = ['无'] + (2020..current_year).to_a.reverse    # year options
    if ['无', '', nil].include?(params[:year])
      @year = nil
      o_time = Time.now.beginning_of_month - 11.months # start time
    else
      @year = params[:year] || current_year  # statistical year
      o_time = Time.local @year
    end
    @currency = params[:currency] || 'RMB'                         # currency
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id  # user_channel_id
    @x_axis = []
    
    # 初始化各类数据数组
    expert_expense = []      # 专家支出
    employee_expense = []    # 员工支出
    office_expense = []      # 办公支出
    vat_expense = []         # 增值税
    total_expense = []       # 每月总支出
    total_income = []        # 每月总收入
    gross_profit = []        # 总毛利
    gross_profit_rate = []   # 毛利率
    net_profit = []          # 总净利
    net_profit_rate = []     # 净利率

    # 按月份统计各类数据
    12.times do |i|
      s_time = o_time + i.month  # start time
      e_time = s_time + 1.month  # end time
      month_datetime = s_time.beginning_of_month
      
      # 获取当月成本结算数据
      cost_summary = CostSummary.where(datetime: month_datetime).first
      
      # 计算专家支出 - 根据cost_types表中父节点是专家费用的子节点id对应的price值总和
      expert_cost = 0
      if cost_summary
        # 尝试多种可能的路径模式来查找专家费用
        expert_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ?) AND is_parent = ?", "/专家费用%", "%专家费用%", "专家费用", true).first
        Rails.logger.info("专家费用类型查询结果: #{expert_type.inspect}")
        
        if expert_type
          expert_costs = cost_summary.costs.joins(:cost_type)
            .where("cost_types.path LIKE ? OR cost_types.name LIKE ?", "#{expert_type.path}%", "%专家费用%")
          
          Rails.logger.info("专家费用查询SQL: #{expert_costs.to_sql}")
          Rails.logger.info("找到的专家费用记录数: #{expert_costs.count}")
          
          expert_cost = expert_costs.sum(:price)
          Rails.logger.info("专家费用总额: #{expert_cost}")
        else
          # 如果找不到专家费用类型，尝试直接查找包含"专家"的费用
          expert_costs = cost_summary.costs.joins(:cost_type)
            .where("cost_types.name LIKE ?", "%专家%")
          
          Rails.logger.info("备用专家费用查询SQL: #{expert_costs.to_sql}")
          Rails.logger.info("找到的备用专家费用记录数: #{expert_costs.count}")
          
          expert_cost = expert_costs.sum(:price)
          Rails.logger.info("备用专家费用总额: #{expert_cost}")
        end
      end
      expert_expense << expert_cost
      
      # 计算员工支出 - 根据cost_types表中父节点是工资的子节点id对应的price值总和
      employee_cost = 0
      if cost_summary
        # 尝试多种可能的路径模式来查找工资
        salary_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ? OR name LIKE ?) AND is_parent = ?", "/工资%", "%工资%", "工资", "%薪资%", true).first
        Rails.logger.info("工资类型查询结果: #{salary_type.inspect}")
        
        if salary_type
          employee_costs = cost_summary.costs.joins(:cost_type)
            .where("cost_types.path LIKE ? OR cost_types.name LIKE ? OR cost_types.name LIKE ?", "#{salary_type.path}%", "%工资%", "%薪资%")
          
          Rails.logger.info("员工支出查询SQL: #{employee_costs.to_sql}")
          Rails.logger.info("找到的员工支出记录数: #{employee_costs.count}")
          
          employee_cost = employee_costs.sum(:price)
          Rails.logger.info("员工支出总额: #{employee_cost}")
        else
          # 如果找不到工资类型，尝试直接查找包含"工资"或"薪资"的费用
          employee_costs = cost_summary.costs.joins(:cost_type)
            .where("cost_types.name LIKE ? OR cost_types.name LIKE ?", "%工资%", "%薪资%")
          
          Rails.logger.info("备用员工支出查询SQL: #{employee_costs.to_sql}")
          Rails.logger.info("找到的备用员工支出记录数: #{employee_costs.count}")
          
          employee_cost = employee_costs.sum(:price)
          Rails.logger.info("备用员工支出总额: #{employee_cost}")
        end
      end
      employee_expense << employee_cost
      
      # 计算增值税 - project_tasks表中started_at字段是统计月份的(total_price - shorthand_price) * 6%的和
      vat = ProjectTask.where(status: 'finished')
        .where('started_at >= ? AND started_at < ?', s_time, e_time)
        .sum('(total_price - shorthand_price) * 0.06')
      vat_expense << vat
      
      # 计算办公支出 - 总成本减去专家支出、员工支出和税务支出
      total_cost = cost_summary ? cost_summary.price : 0
      tax_cost = 0
      if cost_summary
        tax_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ?) AND is_parent = ?", "/税务%", "%税务%", "税务", true).first
        if tax_type
          tax_cost = cost_summary.costs.joins(:cost_type)
            .where("cost_types.path LIKE ? OR cost_types.name LIKE ?", "#{tax_type.path}%", "%税务%")
            .sum(:price)
        end
      end
      office_cost = total_cost - expert_cost - employee_cost - tax_cost
      office_expense << office_cost
      
      # 计算每月总支出 = 专家支出 + 员工支出 + 办公支出 + 增值税
      month_total_expense = expert_cost + employee_cost + office_cost + vat
      total_expense << month_total_expense
      
      # 计算每月总收入 - project_tasks表中started_at字段是统计月份的(total_price - shorthand_price)的和
      month_income = ProjectTask.where(status: 'finished')
        .where('started_at >= ? AND started_at < ?', s_time, e_time)
        .sum('total_price - shorthand_price')
      total_income << month_income
      
      # 计算总毛利 = 总收入 - 专家支出
      month_gross_profit = month_income - expert_cost
      gross_profit << month_gross_profit
      
      # 计算毛利率 = 总毛利 / 总收入
      month_gross_profit_rate = month_income.zero? ? 0 : (month_gross_profit / month_income * 100).round(2)
      gross_profit_rate << month_gross_profit_rate
      
      # 计算总净利 = 总收入 - 总支出
      month_net_profit = month_income - month_total_expense
      net_profit << month_net_profit
      
      # 计算净利率 = 总净利 / 总收入
      month_net_profit_rate = month_income.zero? ? 0 : (month_net_profit / month_income * 100).round(2)
      net_profit_rate << month_net_profit_rate
      
      @x_axis << s_time.strftime('%Y.%m')
    end

    # 准备图表数据
    @result = [
      { name: '专家支出', data: expert_expense, stack: '支出' },
      { name: '员工支出', data: employee_expense, stack: '支出' },
      { name: '办公支出', data: office_expense, stack: '支出' },
      { name: '增值税', data: vat_expense, stack: '支出' },
      { name: '每月总支出', data: total_expense },
      { name: '每月总收入', data: total_income },
      { name: '总毛利', data: gross_profit },
      { name: '总净利', data: net_profit }
    ]

    # 准备年度总计数据
    @annual_expense_infos = [
      { name: '专家支出', value: expert_expense.sum },
      { name: '员工支出', value: employee_expense.sum },
      { name: '办公支出', value: office_expense.sum },
      { name: '增值税', value: vat_expense.sum },
      { name: '每月总支出', value: total_expense.sum },
      { name: '每月总收入', value: total_income.sum },
      { name: '总毛利', value: gross_profit.sum },
      { name: '毛利率', value: "#{(total_income.sum.zero? ? 0 : (gross_profit.sum / total_income.sum * 100).round(2))}%" },
      { name: '总净利', value: net_profit.sum },
      { name: '净利率', value: "#{(total_income.sum.zero? ? 0 : (net_profit.sum / total_income.sum * 100).round(2))}%" }
    ]
  end

  def v_monthly_new
    if params[:datetime]
      begin
        @year = (params[:datetime]&.to_time || Time.now).beginning_of_year
        @data = []
        12.times do |i|
          s_time = @year + i.month
          q_experts = user_channel_filter(Candidate.where(category: %w[expert doctor]).where('created_at BETWEEN ? AND ?', s_time, s_time + 1.month))
          q_tasks = user_channel_filter(ProjectTask.where(status: 'finished', currency: 'RMB').where('started_at BETWEEN ? AND ?', s_time, s_time + 1.month))

          @data << {
            name: s_time.strftime('%Y.%m'),
            new_expert: q_experts.count,
            new_task: q_tasks.count,
            new_task_duration: (q_tasks.sum(:charge_duration) / 60.0).round(1)
          }
        end
        render json: { status: 0, data: @data }
      rescue => e
        render json: { status: 1, msg: e.message }
      end
    end
  end

  def v_ongoing_sta
    begin
      sum_project = current_user.projects.where(status: 'ongoing').count
      sum_demand = 0
      sum_recommended = 0
      sum_hold = 0
      sum_succ = 0
      infos = [] # 明细 { user_id: 1, username: 'xx', sum_demand: 1, sum_succ: 1, zhuanhualv: 1.0 }
      if current_user.is_role? 'pm'
        current_user.projects.where(status: 'ongoing').each do |project|
          sum_demand += project.project_requirements.where.not(status: 'cancelled').sum(:demand_number)
          sum_recommended += project.call_records.where(rec_status: 'recommended').count
          sum_hold += project.call_records.where(rec_status: 'hold').count
          sum_succ += project.call_records.where(rec_status: 'succ').count
          project.users.each do |user|
            _info = infos.select{ |info| info[:user_id] == user.id }[0]
            _sum_demand = project.project_requirements.where.not(status: 'cancelled').where(operator_id: user.id).sum(:demand_number)
            _sum_succ = project.call_records.where(rec_status: 'succ', created_by: user.id).count
            next if _sum_demand.zero?
            if _info
              _info[:sum_demand] += _sum_demand
              _info[:sum_succ] += _sum_succ
            else
              infos << { user_id: user.id, username: user.name_cn, sum_demand: _sum_demand, sum_succ: _sum_succ }
            end
          end
        end
      elsif current_user.is_role? 'pa'
        current_user.projects.where(status: 'ongoing').each do |project|
          sum_demand += project.project_requirements.where.not(status: 'cancelled').where(operator_id: current_user.id).sum(:demand_number)
          sum_recommended += project.call_records.where(rec_status: 'recommended', created_by: current_user.id).count
          sum_hold += project.call_records.where(rec_status: 'hold', created_by: current_user.id).count
          sum_succ += project.call_records.where(rec_status: 'succ', created_by: current_user.id).count
        end
      end

      infos.each do |info|
        info[:zhuanhualv] = (info[:sum_succ].to_f / info[:sum_demand]).round(3)
      end

      @data = {
        sum_project: sum_project,
        sum_demand: sum_demand,
        sum_recommended: sum_recommended,
        sum_hold: sum_hold,
        sum_succ: sum_succ,
        zhuanhualv: sum_demand.zero? ? 0 : (sum_succ.to_f / sum_demand).round(3),
        infos: infos
      }
      render json: { status: 0, data: @data }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_client_zhuanhualv_data
    begin
      if params[:time_range] == 'season'
        stime = Time.now.beginning_of_quarter
      elsif params[:time_range] == 'year'
        stime = Time.now.beginning_of_year
      else
        stime = params[:stime]&.to_time
        etime = params[:etime]&.to_time
      end
      raise '统计时间不能为空' if stime.blank?
      etime = etime || Time.now
      @data = []
      project_requirements = ProjectRequirement.where.not(status: 'cancelled').where('demand_number > 0').where('created_at BETWEEN ? AND ?', stime, etime)
      project_requirements.each do |req|
        next if req.project.nil?
        req.project.project_candidates.client.each do |p_c|
          item = @data.select{|x| x[:id] == p_c.candidate_id }[0]
          if item
            item[:sum_demand] += req.demand_number
          else
            @data << { id: p_c.candidate_id, sum_demand: req.demand_number, sum_succ: 0 }
          end
        end
      end
      project_tasks = ProjectTask.where(status: 'finished').where('started_at BETWEEN ? AND ?', stime, etime)
      project_tasks.each do |task|
        next if task.project.nil?
        task.project.project_candidates.client.each do |p_c|
          item = @data.select{|x| x[:id] == p_c.candidate_id }[0]
          if item
            item[:sum_succ] += 1
          else
            @data << { id: p_c.candidate_id, sum_demand: 0, sum_succ: 1 }
          end
        end
      end
      @data.each do |item|
        client = Candidate.find(item[:id])
        item[:uid] = client.uid
        item[:name] = client.name
        item[:nickname] = client.nickname
        item[:company_name] = client.company.name
        item[:title] = client.title
        if item[:sum_succ].zero?
          item[:zhuanhualv] = 0
        elsif item[:sum_demand].zero?
          item[:zhuanhualv] = 1
        else
          item[:zhuanhualv] = (item[:sum_succ].to_f / item[:sum_demand]).round(3)
        end
      end
      # @data = @data.sort_by{ |x| x[:zhuanhualv] }
      render json: { status: 0, data: @data }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end


  # GET /statistics/client_statistics
  def client_statistics
    Rails.logger.info("客户统计 - 开始执行客户统计方法")
    # 获取月份选项，默认显示当前月份
    current_time = Time.now
    current_month = current_time.beginning_of_month
    @month_options = []
    start_month = Time.new(2020, 1, 1).beginning_of_month
    months = (current_month.year * 12 + current_month.month) - (start_month.year * 12 + start_month.month)
    months.downto(0) do |i|
      _month_ = current_month - i.month
      @month_options << [_month_.strftime('%Y-%m'), _month_.strftime('%F')]
    end
    Rails.logger.info("客户统计 - 生成月份选项完成: #{@month_options.size}个月份选项")

    # 设置查询月份，默认为当前月份
    Rails.logger.info("客户统计 - 接收到的月份参数: #{params[:month]}")
    s_month = if params[:month].present?
                begin
                  # 尝试处理时间戳格式或yyyy-MM格式
                  if params[:month].to_s.match?(/^\d{13}$/) # 判断是否为时间戳格式（13位数字）
                    parsed_month = Time.at(params[:month].to_i / 1000).beginning_of_month
                    Rails.logger.info("客户统计 - 解析时间戳格式: #{params[:month]} -> #{parsed_month}")
                    parsed_month
                  else
                    # 尝试将yyyy-MM格式转换为时间对象，添加-01表示月份的第一天
                    parsed_month = "#{params[:month]}-01".to_time
                    Rails.logger.info("客户统计 - 解析yyyy-MM格式: #{params[:month]} -> #{parsed_month}")
                    parsed_month
                  end
                rescue => e
                  Rails.logger.error("客户统计 - 月份参数解析错误: #{e.message}")
                  current_month
                end
              else
                Rails.logger.info("客户统计 - 未提供月份参数，使用当前月份: #{current_month}")
                current_month
              end
    @current_month = s_month.strftime('%Y/%m')
    Rails.logger.info("客户统计 - 最终使用的查询月份: #{s_month}, 格式化后: #{@current_month}")

    # 设置用户渠道
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id

    # 基础查询条件
    client_query = Client.where(category: 'client')
    if @user_channel_id.present?
      client_query = client_query.where(user_channel_id: @user_channel_id)
    end

    # 计算当前月份的客户统计数据
    @total_clients = client_query.count
    @new_clients = client_query.where('created_at BETWEEN ? AND ?', s_month, s_month + 1.month).count

    # 活跃客户：当月有项目的客户
    active_client_ids = Project.where('created_at BETWEEN ? AND ?', s_month, s_month + 1.month)
                              .pluck(:company_id).uniq
    @active_clients = client_query.where(company_id: active_client_ids).count

    # 计算上月数据（环比）
    last_month = s_month - 1.month
    last_month_new_clients = client_query.where('created_at BETWEEN ? AND ?', last_month, last_month + 1.month).count
    last_month_active_client_ids = Project.where('created_at BETWEEN ? AND ?', last_month, last_month + 1.month)
                                         .pluck(:company_id).uniq
    last_month_active_clients = client_query.where(company_id: last_month_active_client_ids).count

    # 计算去年同期数据（同比）
    last_year_month = s_month - 1.year
    last_year_new_clients = client_query.where('created_at BETWEEN ? AND ?', last_year_month, last_year_month + 1.month).count
    last_year_active_client_ids = Project.where('created_at BETWEEN ? AND ?', last_year_month, last_year_month + 1.month)
                                        .pluck(:company_id).uniq
    last_year_active_clients = client_query.where(company_id: last_year_active_client_ids).count

    # 计算环比变化率
    @mom_new_clients = calculate_change_rate(@new_clients, last_month_new_clients)
    @mom_active_clients = calculate_change_rate(@active_clients, last_month_active_clients)

    # 计算同比变化率
    @yoy_new_clients = calculate_change_rate(@new_clients, last_year_new_clients)
    @yoy_active_clients = calculate_change_rate(@active_clients, last_year_active_clients)

    # 计算客户收入相关数据
    @currency = params[:currency] || 'RMB'
    project_task_query = ProjectTask.where(status: 'finished', currency: @currency)
    project_task_cost_query = ProjectTaskCost.joins(:project_task).where('project_tasks.status': 'finished', 'project_task_costs.currency': @currency)

    if @user_channel_id.present?
      project_task_query = project_task_query.where(user_channel_id: @user_channel_id)
      project_task_cost_query = project_task_cost_query.where(user_channel_id: @user_channel_id)
    end

    # 当月总收入
    @total_income = calculate_total_income(project_task_query, s_month)
    # 当月毛利
    @gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, s_month)
    # 毛利率
    @gross_profit_rate = @total_income.zero? ? 0 : (@gross_profit / @total_income * 100).round(2)

    # 上月数据
    last_month_total_income = calculate_total_income(project_task_query, last_month)
    last_month_gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, last_month)
    last_month_gross_profit_rate = last_month_total_income.zero? ? 0 : (last_month_gross_profit / last_month_total_income * 100).round(2)

    # 去年同期数据
    last_year_total_income = calculate_total_income(project_task_query, last_year_month)
    last_year_gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, last_year_month)
    last_year_gross_profit_rate = last_year_total_income.zero? ? 0 : (last_year_gross_profit / last_year_total_income * 100).round(2)

    # 计算环比变化率
    @mom_total_income = calculate_change_rate(@total_income, last_month_total_income)
    @mom_gross_profit = calculate_change_rate(@gross_profit, last_month_gross_profit)
    @mom_gross_profit_rate = calculate_change_rate(@gross_profit_rate, last_month_gross_profit_rate)

    # 计算同比变化率
    @yoy_total_income = calculate_change_rate(@total_income, last_year_total_income)
    @yoy_gross_profit = calculate_change_rate(@gross_profit, last_year_gross_profit)
    @yoy_gross_profit_rate = calculate_change_rate(@gross_profit_rate, last_year_gross_profit_rate)

    # 客户排名数据
    Rails.logger.info("客户统计 - 开始计算客户排名，查询月份: #{s_month}")
    @client_ranking = calculate_client_ranking(s_month)
    Rails.logger.info("客户统计 - 客户排名计算完成，结果数量: #{@client_ranking&.size || 0}")

    # 记录总计数据
    @total_projects = @client_ranking.sum { |c| c[:project_count] || 0 }
    @total_hours = @client_ranking.sum { |c| (c[:total_hours] || 0).to_f }.round(2)
    
    # 修改转化率计算逻辑，与company_monthly_statistics页面保持一致
    # 获取当月创建的项目ID列表
    monthly_projects = Project.where('created_at BETWEEN ? AND ?', s_month, s_month + 1.month)
    monthly_project_ids = monthly_projects.pluck(:id)
    Rails.logger.info("客户统计 - 当月创建的项目IDs: #{monthly_project_ids}")
    
    # 分子：这些项目中产生的访谈数量（call_records表中rec_status为succ的记录数）
    succ_count_query = CallRecord.where(rec_status: 'succ')
                          .where(project_id: monthly_project_ids)
    
    Rails.logger.info("客户统计 - 计算成功访谈数SQL: #{succ_count_query.to_sql}")
    succ_count = succ_count_query.count
    Rails.logger.info("客户统计 - 成功访谈数: #{succ_count}")
    
    # 分母：这些项目对应的需求人数总和
    demand_sum_query = ProjectRequirement.where.not(status: 'cancelled')
                                  .where(project_id: monthly_project_ids)
    
    Rails.logger.info("客户统计 - 计算需求总量SQL: #{demand_sum_query.to_sql}")
    demand_sum = demand_sum_query.sum(:demand_number)
    Rails.logger.info("客户统计 - 需求总量: #{demand_sum}")
    
    # 计算转化率
    @completion_rate = demand_sum.zero? ? 0 : ((succ_count.to_f / demand_sum) * 100).round(2)

    Rails.logger.info("客户统计 - 总项目数: #{@total_projects}")
    Rails.logger.info("客户统计 - 总收入: #{@total_income}")
    Rails.logger.info("客户统计 - 总毛利: #{@gross_profit}")
    Rails.logger.info("客户统计 - 总毛利率: #{@gross_profit_rate}%")
    Rails.logger.info("客户统计 - 总完成率: #{@completion_rate}%")

    # 准备图表数据（最近12个月）
    @x_axis = []
    total_clients_data = []
    new_clients_data = []
    active_clients_data = []
    total_incomes_data = []
    gross_profits_data = []
    gross_profit_rates_data = []

    # 计算最近12个月的数据
    12.times do |i|
      month_time = current_month - (11-i).month

      # 月份标签
      @x_axis << month_time.strftime('%Y/%m')

      # 客户总数（截至该月底的累计客户数）
      total_clients_data << client_query.where('created_at <= ?', month_time + 1.month).count

      # 新增客户数
      new_clients_data << client_query.where('created_at BETWEEN ? AND ?', month_time, month_time + 1.month).count

      # 活跃客户数
      active_month_client_ids = Project.where('created_at BETWEEN ? AND ?', month_time, month_time + 1.month)
                                      .pluck(:company_id).uniq
      active_clients_data << client_query.where(company_id: active_month_client_ids).count

      # 总收入
      month_income = calculate_total_income(project_task_query, month_time)
      total_incomes_data << month_income

      # 毛利
      month_gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, month_time)
      gross_profits_data << month_gross_profit

      # 毛利率
      month_gross_profit_rate = month_income.zero? ? 0 : (month_gross_profit / month_income * 100).round(2)
      gross_profit_rates_data << month_gross_profit_rate
    end

    # 图表数据
    @result = [
      { name: '客户总数', data: total_clients_data },
      { name: '新增客户', data: new_clients_data },
      { name: '活跃客户', data: active_clients_data },
      { name: '总收入', data: total_incomes_data },
      { name: '毛利', data: gross_profits_data },
      { name: '毛利率(%)', data: gross_profit_rates_data }
    ]
    
    respond_to do |format|
      format.html
      format.json { render json: { client_ranking: @client_ranking } }
    end
  end
  
  # 计算客户排名
  def calculate_client_ranking(month)
    Rails.logger.info("客户统计 - 开始计算客户排名，查询月份: #{month}")
    # 获取当月有完成任务的客户
    client_data = {}
    
    # 查询当月完成的项目任务
    finished_tasks = ProjectTask.where(status: 'finished')
                      .where('started_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 输出SQL查询语句到日志
    Rails.logger.info("客户统计 - 完成任务SQL: #{finished_tasks.to_sql}")
    Rails.logger.info("客户统计 - 完成任务参数: 开始时间=#{month}, 结束时间=#{month + 1.month}")
    
    if @user_channel_id.present?
      finished_tasks = finished_tasks.where(user_channel_id: @user_channel_id)
      
      # 输出带渠道过滤的SQL查询语句到日志
      Rails.logger.info("客户统计 - 渠道过滤后完成任务SQL: #{finished_tasks.to_sql}")
      Rails.logger.info("客户统计 - 渠道ID: #{@user_channel_id}")
    end
    
    # 记录查询结果数量
    finished_tasks_count = finished_tasks.count
    Rails.logger.info("客户统计 - 完成任务数量: #{finished_tasks_count}")
    
    # 按客户分组统计数据 - 已完成任务
    Rails.logger.info("客户统计 - 开始按客户分组统计数据")
    finished_tasks.includes(project: [:company]).each do |task|
      next unless task.project && task.project.company
      
      company_id = task.project.company_id
      company_name = task.project.company.name
      
      client_data[company_id] ||= {
        name: company_name,
        company_id: company_id,
        total_income: 0,
        total_cost: 0,
        projects: Set.new,
        total_hours: 0,
        expert_fee: 0,
        expert_tax_fee: 0,
        recommend_fee: 0,
        translation_fee: 0,
        others_fee: 0
      }
      
      # 累计收入
      client_data[company_id][:total_income] += (task.actual_price || 0).to_f
      
      # 累计小时数（分钟转小时，保留两位小数）
      client_data[company_id][:total_hours] += (task.charge_duration || 0).to_f / 60.0
      
      # 项目数（去重）
      client_data[company_id][:projects] << task.project_id
      
      # 累计各类费用
      task.costs.each do |cost|
        case cost.category
        when 'expert'
          client_data[company_id][:expert_fee] += (cost.price || 0).to_f
        when 'expert_tax'
          client_data[company_id][:expert_tax_fee] += (cost.price || 0).to_f
        when 'recommend'
          client_data[company_id][:recommend_fee] += (cost.price || 0).to_f
        when 'translation'
          client_data[company_id][:translation_fee] += (cost.price || 0).to_f
        when 'others'
          client_data[company_id][:others_fee] += (cost.price || 0).to_f
        end
      end
    end
    
    # 获取需求量数据
    Rails.logger.info("客户统计 - 开始获取需求量数据")
    company_demand_data = {}
    
    # 查询当月的需求
    project_requirements = ProjectRequirement.where('created_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 按公司分组统计需求量
    project_requirements.includes(:project).each do |requirement|
      next unless requirement.project && requirement.project.company_id
      
      company_id = requirement.project.company_id
      company_demand_data[company_id] = (company_demand_data[company_id] || 0).to_i + (requirement.demand_number || 0).to_i
    end
    
    # 获取转化率数据（已完成任务数）
    Rails.logger.info("客户统计 - 开始获取转化率数据")
    company_task_count = {}
    
    # 查询当月的任务
    monthly_tasks = ProjectTask.where('started_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 按公司分组统计任务数
    monthly_tasks.includes(:project).each do |task|
      next unless task.project && task.project.company_id
      
      company_id = task.project.company_id
      company_task_count[company_id] ||= 0
      company_task_count[company_id] += 1
    end
    
    # 获取项目量数据
    Rails.logger.info("客户统计 - 开始获取项目量数据")
    company_project_count = {}
    
    # 查询当月的项目
    monthly_projects = Project.where('started_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 按公司分组统计项目数
    monthly_projects.each do |project|
      next unless project.company_id
      
      company_id = project.company_id
      company_project_count[company_id] ||= 0
      company_project_count[company_id] += 1
    end
    
    # 计算各项指标
    client_data.each do |company_id, data|
      # 计算项目数并移除临时集合
      data[:project_count] = company_project_count[company_id] || 0
      data.delete(:projects)
      
      # 计算总支出
      data[:total_cost] = (data[:expert_fee] || 0).to_f + (data[:expert_tax_fee] || 0).to_f + (data[:recommend_fee] || 0).to_f + (data[:translation_fee] || 0).to_f + (data[:others_fee] || 0).to_f
      
      # 计算毛利（总收入-总支出）
      data[:gross_profit] = (data[:total_income] || 0).to_f - (data[:total_cost] || 0).to_f
      
      # 计算毛利率（毛利/总收入，保留4位小数，显示为百分比保留2位小数）
      data[:gross_profit_rate] = (data[:total_income].nil? || data[:total_income].zero?) ? 0 : (((data[:gross_profit] || 0).to_f / data[:total_income].to_f) * 10000).round / 100.0
      
      # 计算专家单价（总收入/总小时数，保留4位小数）
      data[:expert_price] = (data[:total_hours].nil? || data[:total_hours].zero?) ? 0 : (data[:total_income].to_f / data[:total_hours].to_f).round(4)
      
      # 设置需求量（确保为整数）
      data[:demand_hours] = (company_demand_data[company_id] || 0).to_i
      
      # 计算转化率（成功访谈数/需求人数总和）- 与company_monthly_statistics页面保持一致
      # 获取该公司当月创建的项目
      company_monthly_projects = Project.where('created_at BETWEEN ? AND ?', month, month + 1.month)
                                      .where(company_id: company_id)
      company_monthly_project_ids = company_monthly_projects.pluck(:id)
      
      # 分子：这些项目中产生的访谈数量（call_records表中rec_status为succ的记录数）
      company_succ_count = CallRecord.where(rec_status: 'succ')
                                  .where(project_id: company_monthly_project_ids)
                                  .count
      
      # 分母：这些项目对应的需求人数总和
      company_demand_sum = ProjectRequirement.where.not(status: 'cancelled')
                                          .where(project_id: company_monthly_project_ids)
                                          .sum(:demand_number)
      
      # 计算转化率
      data[:completion_rate] = company_demand_sum.zero? ? 0 : ((company_succ_count.to_f / company_demand_sum) * 100).round(2)
      
      # 四舍五入小时数显示（保留两位小数）
      data[:total_hours] = data[:total_hours].round(2)
    end
    
    # 按总收入排序
    client_data.values.sort_by { |data| -data[:total_income] }
  end

  # GET /statistics/total_performance
  def total_performance
    # 默认使用当前月份，不需要年份选择
    current_time = Time.now
    current_month = current_time.beginning_of_month
    last_month = current_month - 1.month
    last_year_same_month = current_month - 1.year
    
    @currency = params[:currency] || 'RMB'
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id
    
    # 当前月份（用于显示在页面上）
    @current_month = current_time.strftime('%Y/%m')
    
    # 设置基础查询条件
    project_task_query = ProjectTask.where(status: 'finished', currency: @currency)
    project_task_cost_query = ProjectTaskCost.joins(:project_task).where('project_tasks.status': 'finished', 'project_task_costs.currency': @currency)
    
    if @user_channel_id.present?
      project_task_query = project_task_query.where(user_channel_id: @user_channel_id)
      project_task_cost_query = project_task_cost_query.where(user_channel_id: @user_channel_id)
    end
    
    # 计算当前月份的指标
    @total_hours = calculate_total_hours(project_task_query, current_month)
    @total_demand_hours = calculate_total_demand_hours(project_task_query, current_month)
    @conversion_rate = calculate_conversion_rate(current_month)
    @total_income = calculate_total_income(project_task_query, current_month)
    @gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, current_month)
    @net_profit = calculate_net_profit(@gross_profit, current_month)
    
    # 计算毛利率和净利率
    @gross_profit_rate = @total_income.zero? ? 0 : (@gross_profit / @total_income * 100).round(2)
    @net_profit_rate = @total_income.zero? ? 0 : (@net_profit / @total_income * 100).round(2)
    
    # 计算环比数据（与上月相比）
    last_month_total_hours = calculate_total_hours(project_task_query, last_month)
    last_month_total_demand_hours = calculate_total_demand_hours(project_task_query, last_month)
    last_month_conversion_rate = calculate_conversion_rate(last_month)
    last_month_total_income = calculate_total_income(project_task_query, last_month)
    last_month_gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, last_month)
    last_month_net_profit = calculate_net_profit(last_month_gross_profit, last_month)
    
    # 计算上月毛利率和净利率
    last_month_gross_profit_rate = last_month_total_income.zero? ? 0 : (last_month_gross_profit / last_month_total_income * 100).round(2)
    last_month_net_profit_rate = last_month_total_income.zero? ? 0 : (last_month_net_profit / last_month_total_income * 100).round(2)
    
    # 计算同比数据（与去年同期相比）
    last_year_total_hours = calculate_total_hours(project_task_query, last_year_same_month)
    last_year_total_demand_hours = calculate_total_demand_hours(project_task_query, last_year_same_month)
    last_year_conversion_rate = calculate_conversion_rate(last_year_same_month)
    last_year_total_income = calculate_total_income(project_task_query, last_year_same_month)
    last_year_gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, last_year_same_month)
    last_year_net_profit = calculate_net_profit(last_year_gross_profit, last_year_same_month)
    
    # 计算去年同期毛利率和净利率
    last_year_gross_profit_rate = last_year_total_income.zero? ? 0 : (last_year_gross_profit / last_year_total_income * 100).round(2)
    last_year_net_profit_rate = last_year_total_income.zero? ? 0 : (last_year_net_profit / last_year_total_income * 100).round(2)
    
    # 计算环比变化率
    @mom_total_hours = calculate_change_rate(@total_hours, last_month_total_hours)
    @mom_total_demand_hours = calculate_change_rate(@total_demand_hours, last_month_total_demand_hours)
    @mom_conversion_rate = calculate_change_rate(@conversion_rate, last_month_conversion_rate)
    @mom_total_income = calculate_change_rate(@total_income, last_month_total_income)
    @mom_gross_profit = calculate_change_rate(@gross_profit, last_month_gross_profit)
    @mom_net_profit = calculate_change_rate(@net_profit, last_month_net_profit)
    @mom_gross_profit_rate = calculate_change_rate(@gross_profit_rate, last_month_gross_profit_rate)
    @mom_net_profit_rate = calculate_change_rate(@net_profit_rate, last_month_net_profit_rate)
    
    # 计算同比变化率
    @yoy_total_hours = calculate_change_rate(@total_hours, last_year_total_hours)
    @yoy_total_demand_hours = calculate_change_rate(@total_demand_hours, last_year_total_demand_hours)
    @yoy_conversion_rate = calculate_change_rate(@conversion_rate, last_year_conversion_rate)
    @yoy_total_income = calculate_change_rate(@total_income, last_year_total_income)
    @yoy_gross_profit = calculate_change_rate(@gross_profit, last_year_gross_profit)
    @yoy_net_profit = calculate_change_rate(@net_profit, last_year_net_profit)
    @yoy_gross_profit_rate = calculate_change_rate(@gross_profit_rate, last_year_gross_profit_rate)
    @yoy_net_profit_rate = calculate_change_rate(@net_profit_rate, last_year_net_profit_rate)
    
    # 准备图表数据（最近6个月）
    @x_axis = []
    total_hours = []
    total_demand_hours = []
    conversion_rates = []
    total_incomes = []
    gross_profits = []
    net_profits = []
    
    # 计算最近6个月的数据
    gross_profit_rates = []
    net_profit_rates = []
    6.times do |i|
      month_time = current_month - (5-i).month
      
      total_hours << calculate_total_hours(project_task_query, month_time)
      total_demand_hours << calculate_total_demand_hours(project_task_query, month_time)
      conversion_rates << calculate_conversion_rate(month_time)
      total_income = calculate_total_income(project_task_query, month_time)
      total_incomes << total_income
      gross_profit = calculate_gross_profit(project_task_query, project_task_cost_query, month_time)
      gross_profits << gross_profit
      net_profit = calculate_net_profit(gross_profit, month_time)
      net_profits << net_profit
      
      # 计算毛利率和净利率
      gross_profit_rate = total_income.zero? ? 0 : (gross_profit / total_income * 100).round(2)
      gross_profit_rates << gross_profit_rate
      net_profit_rate = total_income.zero? ? 0 : (net_profit / total_income * 100).round(2)
      net_profit_rates << net_profit_rate
      
      @x_axis << month_time.strftime('%Y/%m')
    end
    
    # 图表数据
    @result = [
      { name: '总小时数', data: total_hours },
      { name: '总需求人数', data: total_demand_hours },
      { name: '转化率(%)', data: conversion_rates },
      { name: '总收入', data: total_incomes },
      { name: '毛利', data: gross_profits },
      { name: '毛利率(%)', data: gross_profit_rates },
      { name: '净利', data: net_profits },
      { name: '净利率(%)', data: net_profit_rates }
    ]
  end
  # 员工统计总览页面
  def employee_statistics
    # 获取当前月份或用户选择的月份
    begin
      @month = params[:month].present? ? Time.parse(params[:month]) : Time.now.beginning_of_month
    rescue ArgumentError => e
      # 如果解析失败，尝试使用其他格式解析或使用当前月份
      Rails.logger.error("解析月份参数出错: #{e.message}, 参数值: #{params[:month]}")
      # 尝试使用yyyy-mm格式解析
      begin
        if params[:month].present? && params[:month].match?(/^\d{4}-\d{2}$/)
          year, month = params[:month].split('-').map(&:to_i)
          @month = Time.new(year, month, 1).beginning_of_month
        else
          @month = Time.now.beginning_of_month
        end
      rescue => e2
        Rails.logger.error("二次解析月份参数出错: #{e2.message}")
        @month = Time.now.beginning_of_month
      end
    end

    # 计算员工统计数据
    @employee_ranking = calculate_employee_ranking(@month)

    # 计算总计数据
    @total_interview_hours = @employee_ranking.sum { |data| data[:interview_hours].to_f }
    @total_manage_hours = @employee_ranking.sum { |data| data[:manage_hours].to_f }
    @total_hours = @employee_ranking.sum { |data| data[:total_hours].to_f }
    @total_demand_hours = @employee_ranking.sum { |data| data[:demand_hours].to_f }
    @total_converted_tasks = @employee_ranking.sum { |data| data[:converted_tasks].to_f }
    # 计算总计行的转化率（使用加权平均，与employee_monthly_statistics保持一致）
    @total_conversion_rate = @total_demand_hours.zero? ? 0 : (@employee_ranking.sum { |data| data[:conversion_rate].to_f * data[:demand_hours].to_f } / @total_demand_hours).round(2)
    @total_income = @employee_ranking.sum { |data| data[:total_income].to_f }
    @total_expert_cost = @employee_ranking.sum { |data| data[:expert_cost].to_f }
    @total_expert_price = @total_hours.zero? ? 0 : (@total_income / @total_hours).round(4)
    @total_personal_income = @employee_ranking.sum { |data| data[:personal_income].to_f }
    # 确保在计算绩效倍数时处理边界情况
    begin
      @total_performance_multiplier = @total_demand_hours.zero? ? 0 : (@total_hours / @total_demand_hours).round(2)
    rescue => e
      # 如果计算出错，设置为0并记录错误
      Rails.logger.error("计算绩效倍数出错: #{e.message}")
      @total_performance_multiplier = 0
    end
    @total_projects = @employee_ranking.sum { |data| data[:project_count].to_i }

    # 月份选项，用于下拉选择
    @month_options = []
    start_month = Time.new(2000, 1, 1).beginning_of_month
    current_month = Time.now.beginning_of_month
    months = (current_month.year * 12 + current_month.month) - (start_month.year * 12 + start_month.month)
    months.downto(0) do |i|
      _month_ = current_month - i.month
      @month_options << [_month_.strftime('%Y-%m'), _month_.strftime('%F')]
    end
  end

  # 员工月度统计数据页面
  def employee_monthly_statistics
    @employee_id = params[:employee_id]
    @employee_name = params[:employee_name]
    @year = params[:year].present? ? params[:year] : Time.now.year.to_s

    # 获取该员工当年各月份的统计数据
    @monthly_data = []
    (1..12).each do |month|
      month_date = Time.new(@year.to_i, month, 1).beginning_of_month
      month_data = calculate_employee_monthly_data(@employee_id, month_date)
      # 修改条件：历史年份显示所有月份，当前年份只显示到当前月份
      if @year.to_i < Time.now.year || month <= Time.now.month
        @monthly_data << month_data
      end
    end

    # 计算总计数据
    @total_interview_hours = @monthly_data.sum { |data| data[:interview_hours].to_f }
    @total_manage_hours = @monthly_data.sum { |data| data[:manage_hours].to_f }
    @total_hours = @monthly_data.sum { |data| data[:total_hours].to_f }
    @total_demand_hours = @monthly_data.sum { |data| data[:demand_hours].to_f }
    @total_conversion_rate = @total_demand_hours.zero? ? 0 : (@monthly_data.sum { |data| data[:conversion_rate].to_f * data[:demand_hours].to_f } / @total_demand_hours).round(2)
    @total_income = @monthly_data.sum { |data| data[:total_income].to_f }
    @total_expert_cost = @monthly_data.sum { |data| data[:expert_cost].to_f }
    @total_expert_price = @total_hours.zero? ? 0 : (@total_expert_cost / @total_hours).round(4)
    @total_personal_income = @monthly_data.sum { |data| data[:personal_income].to_f }
    @total_performance_multiplier = @total_demand_hours.zero? ? 0 : (@total_hours / @total_demand_hours).round(2)
    @total_projects = @monthly_data.sum { |data| data[:project_count].to_i }
  end

  # private

  # 计算员工排名数据
  def calculate_employee_ranking(month)
    employee_data = []

    # 获取所有员工（包括未激活状态）
    employees = User.where(role: %w[admin pm pa])
    employees = user_channel_filter(employees) if current_user.user_channel_id.present?

    employees.each do |employee|
      # 获取该员工在指定月份的任务数据 - 小时数字段的统计逻辑同收费小时数排名页面的总小时数字段
      tasks = ProjectTask.where(status: 'finished', currency: 'RMB')
                         .where('started_at >= ? AND started_at < ?', month, month + 1.month)

      # 只包含created_by的任务，与kpi_summaries保持一致
      employee_tasks = tasks.where(created_by: employee.id)

      # 计算访谈小时和管理小时
      if employee.is_role?('admin', 'pm')
        interview_minutes = tasks.where(created_by: employee.id).sum(:charge_duration)
        manage_minutes = tasks.where(pm_id: employee.id).where.not(created_by: employee.id).sum(:charge_duration)
      else
        interview_minutes = tasks.where(created_by: employee.id).sum(:charge_duration)
        manage_minutes = 0.0
      end
      
      # 计算总小时数
      interview_hours = (interview_minutes / 60.0).round(2)
      manage_hours = (manage_minutes / 60.0).round(2)
      total_hours = interview_hours + manage_hours
      
      # 计算接收需求量 - 查询project_requirements表operator_id关联的users用户表，project_requirements表created_at是查询月demand_number的和
      received_demands_query = ProjectRequirement.where(operator_id: employee.id)
                                          .where('created_at >= ? AND created_at < ?', month, month + 1.month)
      
      Rails.logger.info("员工统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 计算接收需求量SQL: #{received_demands_query.to_sql}")
      received_demands = received_demands_query.sum(:demand_number)
      Rails.logger.info("员工统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 接收需求量: #{received_demands}")
      
      # 计算转化率 - call_records表中created_at是查询月且rec_status是succ的记录数除以接收需求量
      converted_tasks_query = CallRecord.where(rec_status: 'succ')
                                .where(created_by: employee.id)
                                .where('call_records.created_at >= ? AND call_records.created_at < ?', month, month + 1.month)
      
      Rails.logger.info("员工统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 计算转化任务SQL: #{converted_tasks_query.to_sql}")
      converted_tasks = converted_tasks_query.count
      Rails.logger.info("员工统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 转化任务数: #{converted_tasks}")
      
      conversion_rate = received_demands.zero? ? 0 : (converted_tasks.to_f / received_demands * 100).round(2)
      Rails.logger.info("员工统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 转化率: #{conversion_rate}%")

      # 计算访谈总价 - 与kpi_summaries/v_index页面总访谈收入字段统计口径一致，只包含created_by的任务
      total_income = employee_tasks.sum(:actual_price)

      # 计算专家支出 - 同员工业绩统计页面这个人的总专家支出计算口径
      costs = ProjectTaskCost.joins(:project_task)
                             .where('project_tasks.id': employee_tasks.pluck(:id))
      expert_cost = costs.where(category: 'expert').sum(:price)
      
      # 计算专家单价 - 同员工业绩统计页面这个人的专家平均单价计算口径
      expert_price = total_hours.zero? ? 0 : (expert_cost / total_hours).round(4)

      # 计算个人总收入 - 同员工业绩统计页面这个人的个人总收入计算口径
      # 假设从KpiSummary中获取，如果没有则按照一定比例计算
      kpi_summary = KpiSummary.where(datetime: month.beginning_of_month, user_id: employee.id).first
      if kpi_summary
        personal_income_info = kpi_summary.infos.find_by(name: '个人总收入')
        personal_income = personal_income_info ? personal_income_info.price : (total_income * 0.2).round(2)
      else
        personal_income = (total_income * 0.2).round(2)
      end
      
      # 计算绩效倍数 - 同员工业绩统计页面这个人的绩效倍数计算口径
      # 假设从KpiSummary中获取，如果没有则按照一定比例计算
      if kpi_summary
        performance_multiplier_info = kpi_summary.infos.find_by(name: '绩效倍数')
        performance_multiplier = performance_multiplier_info ? performance_multiplier_info.price : (received_demands.zero? ? 0 : (total_hours / received_demands).round(2))
      else
        performance_multiplier = received_demands.zero? ? 0 : (total_hours / received_demands).round(2)
      end

      # 计算项目数量
      project_count = employee_tasks.select(:project_id).distinct.count

      # 添加到员工数据列表
      employee_data << {
        employee_id: employee.id,
        name: employee.name_cn,
        interview_hours: interview_hours,
        manage_hours: manage_hours,
        total_hours: total_hours,
        demand_hours: received_demands,
        converted_tasks: converted_tasks,
        conversion_rate: conversion_rate,
        total_income: total_income,
        expert_cost: expert_cost,
        expert_price: expert_price,
        personal_income: personal_income,
        performance_multiplier: performance_multiplier,
        project_count: project_count
      }
    end

    # 按小时数从大到小排序
    return employee_data.sort_by { |data| -data[:total_hours].to_f }
  end

  # 计算员工月度数据
  def calculate_employee_monthly_data(employee_id, month)
    employee = User.find(employee_id)

    # 获取该员工在指定月份的任务数据 - 小时数字段的统计逻辑同收费小时数排名页面的总小时数字段
    tasks = ProjectTask.where(status: 'finished', currency: 'RMB')
                       .where('started_at >= ? AND started_at < ?', month, month + 1.month)

    # 只包含created_by的任务，与kpi_summaries保持一致
    employee_tasks = tasks.where(created_by: employee.id)

    # 计算访谈小时和管理小时
    if employee.is_role?('admin', 'pm')
      interview_minutes = tasks.where(created_by: employee.id).sum(:charge_duration)
      manage_minutes = tasks.where(pm_id: employee.id).where.not(created_by: employee.id).sum(:charge_duration)
    else
      interview_minutes = tasks.where(created_by: employee.id).sum(:charge_duration)
      manage_minutes = 0.0
    end
    
    # 计算总小时数
    interview_hours = (interview_minutes / 60.0).round(2)
    manage_hours = (manage_minutes / 60.0).round(2)
    total_hours = interview_hours + manage_hours
    
    # 计算接收需求量 - 查询project_requirements表operator_id关联的users用户表，project_requirements表created_at是查询月demand_number的和
    received_demands_query = ProjectRequirement.where(operator_id: employee.id)
                                        .where('created_at >= ? AND created_at < ?', month, month + 1.month)
    
    Rails.logger.info("员工月度统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 月份: #{month.strftime('%Y-%m')}, 计算接收需求量SQL: #{received_demands_query.to_sql}")
    received_demands = received_demands_query.sum(:demand_number)
    Rails.logger.info("员工月度统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 月份: #{month.strftime('%Y-%m')}, 接收需求量: #{received_demands}")
    
    # 计算转化率 - call_records表中created_at是查询月且rec_status是succ的记录数除以接收需求量
    converted_tasks_query = CallRecord.where(rec_status: 'succ')
                              .where(created_by: employee.id)
                              .where('call_records.created_at >= ? AND call_records.created_at < ?', month, month + 1.month)
    
    Rails.logger.info("员工月度统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 月份: #{month.strftime('%Y-%m')}, 计算转化任务SQL: #{converted_tasks_query.to_sql}")
    converted_tasks = converted_tasks_query.count
    Rails.logger.info("员工月度统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 月份: #{month.strftime('%Y-%m')}, 转化任务数: #{converted_tasks}")
    
    conversion_rate = received_demands.zero? ? 0 : (converted_tasks.to_f / received_demands * 100).round(2)
    Rails.logger.info("员工月度统计 - 员工ID: #{employee.id}, 姓名: #{employee.name_cn}, 月份: #{month.strftime('%Y-%m')}, 转化率: #{conversion_rate}%")

    # 计算访谈总价 - 与kpi_summaries/v_index页面总访谈收入字段统计口径一致，只包含created_by的任务
    total_income = employee_tasks.sum(:actual_price)

    # 计算专家支出 - 同员工业绩统计页面这个人的总专家支出计算口径
    costs = ProjectTaskCost.joins(:project_task)
                           .where('project_tasks.id': employee_tasks.pluck(:id))
    expert_cost = costs.where(category: 'expert').sum(:price)
    
    # 计算专家单价 - 同员工业绩统计页面这个人的专家平均单价计算口径
    expert_price = total_hours.zero? ? 0 : (expert_cost / total_hours).round(4)

    # 计算个人总收入 - 同员工业绩统计页面这个人的个人总收入计算口径
    # 假设从KpiSummary中获取，如果没有则按照一定比例计算
    kpi_summary = KpiSummary.where(datetime: month.beginning_of_month, user_id: employee.id).first
    if kpi_summary
      personal_income_info = kpi_summary.infos.find_by(name: '个人总收入')
      personal_income = personal_income_info ? personal_income_info.price : (total_income * 0.2).round(2)
    else
      personal_income = (total_income * 0.2).round(2)
    end
    
    # 计算绩效倍数 - 同员工业绩统计页面这个人的绩效倍数计算口径
    # 假设从KpiSummary中获取，如果没有则按照一定比例计算
    if kpi_summary
      performance_multiplier_info = kpi_summary.infos.find_by(name: '绩效倍数')
      performance_multiplier = performance_multiplier_info ? performance_multiplier_info.price : (received_demands.zero? ? 0 : (total_hours / received_demands).round(2))
    else
      performance_multiplier = received_demands.zero? ? 0 : (total_hours / received_demands).round(2)
    end

    # 计算项目数量
    project_count = employee_tasks.select(:project_id).distinct.count

    # 返回月度数据
    {
      month_name: month.strftime('%Y-%m'),
      interview_hours: interview_hours,
      manage_hours: manage_hours,
      total_hours: total_hours,
      demand_hours: received_demands,
      total_income: total_income,
      expert_cost: expert_cost,
      expert_price: expert_price,
      personal_income: personal_income,
      performance_multiplier: performance_multiplier,
      conversion_rate: conversion_rate,
      project_count: project_count
    }
  end

  # private
  
  # 计算总小时数（访谈小时数）
  def calculate_total_hours(query, month)
    interview_minutes = query.where('project_tasks.started_at BETWEEN ? AND ?', month, month + 1.month).sum(:charge_duration)
    (interview_minutes / 60.0).round(2)
  end
  
  # 计算总需求人数（从project_requirements表获取）
  def calculate_total_demand_hours(query, month)
    # 查询project_requirements表中created_at是查询月的demand_number的和
    ProjectRequirement.where.not(status: 'cancelled')
                     .where('created_at BETWEEN ? AND ?', month, month + 1.month)
                     .sum(:demand_number)
  end
  
  # 计算转化率
  def calculate_conversion_rate(month)
    # 分子：搜索月份时项目创建的月份产生的访谈数量
    # 查找在指定月份创建的项目
    projects_created_in_month = Project.where('created_at BETWEEN ? AND ?', month, month + 1.month)
    
    # 计算这些项目中产生的访谈数量（call_records表中rec_status为succ的记录数）
    succ_count = CallRecord.where(rec_status: 'succ')
                          .where(project_id: projects_created_in_month.pluck(:id))
                          .count
    
    # 分母：搜索月份创建的项目对应的需求人数总和
    sum_demand = ProjectRequirement.where.not(status: 'cancelled')
                                  .where(project_id: projects_created_in_month.pluck(:id))
                                  .sum(:demand_number)
    
    # 计算转化率，处理边界情况
    if sum_demand.zero?
      0
    else
      (succ_count.to_f / sum_demand * 100).round(2)
    end
  end
  
  # 计算总收入
  def calculate_total_income(query, month)
    query.where('project_tasks.started_at BETWEEN ? AND ?', month, month + 1.month).sum('total_price - shorthand_price')
  end
  
  # 计算毛利（总收入 - 专家支出）- 与expense_summary页面保持一致
  def calculate_gross_profit(task_query, cost_query, month)
    # 计算总收入
    total_income = task_query.where('project_tasks.started_at BETWEEN ? AND ?', month, month + 1.month).sum('total_price - shorthand_price').to_f
    
    # 计算专家支出 - 只计算专家费用，与expense_summary页面逻辑一致
    cost_summary = CostSummary.where(datetime: month).first
    expert_cost = 0
    if cost_summary
      # 尝试多种可能的路径模式来查找专家费用
      expert_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ?) AND is_parent = ?", "/专家费用%", "%专家费用%", "专家费用", true).first
      
      if expert_type
        expert_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.path LIKE ? OR cost_types.name LIKE ?", "#{expert_type.path}%", "%专家费用%")
          .sum(:price)
      else
        # 如果找不到专家费用类型，尝试直接查找包含"专家"的费用
        expert_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.name LIKE ?", "%专家%")
          .sum(:price)
      end
    end
    
    # 毛利 = 总收入 - 专家支出
    total_income - expert_cost
  end
  
  # 计算净利（总收入 - 总支出）- 与expense_summary页面保持一致
  def calculate_net_profit(gross_profit, month)
    # 重新计算总收入，因为净利计算需要用到
    total_income = ProjectTask.where(status: 'finished')
      .where('started_at >= ? AND started_at < ?', month, month + 1.month)
      .sum('total_price - shorthand_price')
    
    # 获取当月成本结算数据
    cost_summary = CostSummary.where(datetime: month).first
    
    # 计算专家支出
    expert_cost = 0
    if cost_summary
      expert_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ?) AND is_parent = ?", "/专家费用%", "%专家费用%", "专家费用", true).first
      if expert_type
        expert_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.path LIKE ? OR cost_types.name LIKE ?", "#{expert_type.path}%", "%专家费用%")
          .sum(:price)
      else
        expert_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.name LIKE ?", "%专家%")
          .sum(:price)
      end
    end
    
    # 计算员工支出
    employee_cost = 0
    if cost_summary
      salary_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ? OR name LIKE ?) AND is_parent = ?", "/工资%", "%工资%", "工资", "%薪资%", true).first
      if salary_type
        employee_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.path LIKE ? OR cost_types.name LIKE ? OR cost_types.name LIKE ?", "#{salary_type.path}%", "%工资%", "%薪资%")
          .sum(:price)
      else
        employee_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.name LIKE ? OR cost_types.name LIKE ?", "%工资%", "%薪资%")
          .sum(:price)
      end
    end
    
    # 计算增值税
    vat = ProjectTask.where(status: 'finished')
      .where('started_at >= ? AND started_at < ?', month, month + 1.month)
      .sum('(total_price - shorthand_price) * 0.06')
    
    # 计算办公支出
    total_cost = cost_summary ? cost_summary.price : 0
    tax_cost = 0
    if cost_summary
      tax_type = CostType.where("(path LIKE ? OR path LIKE ? OR name = ?) AND is_parent = ?", "/税务%", "%税务%", "税务", true).first
      if tax_type
        tax_cost = cost_summary.costs.joins(:cost_type)
          .where("cost_types.path LIKE ? OR cost_types.name LIKE ?", "#{tax_type.path}%", "%税务%")
          .sum(:price)
      end
    end
    office_cost = total_cost - expert_cost - employee_cost - tax_cost
    
    # 计算总支出
    total_expense = expert_cost + employee_cost + office_cost + vat
    
    # 净利 = 总收入 - 总支出
    total_income - total_expense
  end
  
  # 计算变化率
  def calculate_change_rate(current_value, previous_value)
    if previous_value.nil? || previous_value.zero?
      return "可能N/A (去年没数据)" if current_value > 0
      return 0
    end
    
    ((current_value - previous_value) / previous_value * 100).round(1)
  end

  # GET /statistics/company_monthly_statistics
  def company_monthly_statistics
    Rails.logger.info("公司月度统计 - 开始执行公司月度统计方法")
    Rails.logger.info("公司月度统计 - 请求参数: #{params.inspect}")
    
    # 获取公司ID
    @company_id = params[:company_id]
    @company_name = params[:company_name]
    
    unless @company_id.present? && @company_name.present?
      flash[:error] = "缺少公司信息"
      Rails.logger.error("公司月度统计 - 缺少公司信息，重定向到客户统计总览页面")
      redirect_to client_statistics_statistics_path
      return
    end
    
    Rails.logger.info("公司月度统计 - 公司ID: #{@company_id}, 公司名称: #{@company_name}")
    
    # 获取年份，优先使用传递的参数
    current_time = Time.now
    @current_year = params[:year] || current_time.year.to_s
    Rails.logger.info("公司月度统计 - 查询年份: #{@current_year}, 来源参数: #{params[:year]}, 参数类型: #{params[:year].class}")
    
    # 设置用户渠道
    @user_channel_id = params[:user_channel_id] || current_user.user_channel_id
    Rails.logger.info("公司月度统计 - 用户渠道ID: #{@user_channel_id}, 当前用户ID: #{current_user.id}")
    
    # 计算该公司今年各月份的数据
    @monthly_data = []
    
    # 遍历今年的12个月
    12.times do |i|
      month_time = Time.new(@current_year.to_i, i+1, 1).beginning_of_month
      Rails.logger.info("公司月度统计 - 处理月份: #{month_time.strftime('%Y-%m')}")
      month_data = calculate_company_monthly_data(@company_id, month_time)
      # 修改条件：历史年份显示所有月份，当前年份只显示到当前月份
      if @current_year.to_i < Time.now.year || (i+1) <= Time.now.month
        @monthly_data << month_data
        Rails.logger.info("公司月度统计 - 添加月份数据: #{month_time.strftime('%Y-%m')}, 数据: #{month_data.inspect}")
      else
        Rails.logger.info("公司月度统计 - 跳过未来月份: #{month_time.strftime('%Y-%m')}")
      end
    end
    
    # 按月份排序
    @monthly_data.sort_by! { |data| data[:month_time] }
    Rails.logger.info("公司月度统计 - 最终数据条数: #{@monthly_data.size}")
    Rails.logger.info("公司月度统计 - 是否有数据: #{@monthly_data.any?}")
    if !@monthly_data.any?
      Rails.logger.warn("公司月度统计 - 未查询到任何数据，请检查公司ID和年份参数")
    end
    
    # 计算总计数据
    @total_hours = @monthly_data.sum { |data| data[:total_hours] || 0 }
    @total_income = @monthly_data.sum { |data| data[:total_income] || 0 }
    @total_gross_profit = @monthly_data.sum { |data| data[:gross_profit] || 0 }
    @total_gross_profit_rate = @total_income.zero? ? 0 : ((@total_gross_profit / @total_income) * 10000).round / 100.0
    @total_expert_price = @total_hours.zero? ? 0 : (@total_income / @total_hours).round(4)
    @total_demand_hours = @monthly_data.sum { |data| data[:demand_hours] || 0 }
    @total_completion_rate = @total_demand_hours.zero? ? 0 : ((@monthly_data.sum { |data| data[:total_hours] || 0 } / @total_demand_hours) * 100).round(2)
    @total_projects = @monthly_data.sum { |data| data[:project_count] || 0 }
    
    # 计算总体毛利率
    @total_gross_profit_rate = @total_income.zero? ? 0 : (@total_gross_profit / @total_income * 100).round(2)
    
    # 计算总体专家单价
    @total_expert_price = @total_hours.zero? ? 0 : (@total_income / @total_hours).round(4)
    
    # 计算总体完成率 - 使用需求量和总小时数计算
    @total_completion_rate = @total_demand_hours.zero? ? 0 : ((@total_hours / @total_demand_hours) * 100).round(2)
    Rails.logger.info("公司月度统计 - 总体完成率: #{@total_completion_rate}%, 总小时数: #{@total_hours}, 总需求量: #{@total_demand_hours}")
  end
  
  # 计算公司月度数据
  def calculate_company_monthly_data(company_id, month_time)
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}")
    
    # 基础查询条件
    project_task_query = ProjectTask.where(status: 'finished')
    Rails.logger.info("计算公司月度数据 - 基础查询条件: status='finished'")
    
    if @user_channel_id.present?
      project_task_query = project_task_query.where(user_channel_id: @user_channel_id)
      Rails.logger.info("计算公司月度数据 - 添加用户渠道过滤: user_channel_id=#{@user_channel_id}")
    end
    
    # 查询当月完成的项目任务
    date_range = "#{month_time} 到 #{month_time + 1.month}"
    Rails.logger.info("计算公司月度数据 - 查询时间范围: #{date_range}")
    
    # 记录SQL查询
    sql_log = project_task_query
              .where('project_tasks.started_at BETWEEN ? AND ?', month_time, month_time + 1.month)
              .includes(project: [:company])
              .where(projects: { company_id: company_id })
              .to_sql
    Rails.logger.info("计算公司月度数据 - 项目任务SQL: #{sql_log}")
    
    finished_tasks = project_task_query
                      .where('project_tasks.started_at BETWEEN ? AND ?', month_time, month_time + 1.month)
                      .includes(project: [:company])
                      .where(projects: { company_id: company_id })
    
    Rails.logger.info("计算公司月度数据 - 完成的项目任务数量: #{finished_tasks.size}")
    
    # 查询当月需求量（用于计算转化率）
    project_requirements = ProjectRequirement.where.not(status: 'cancelled')
                           .where('project_requirements.created_at BETWEEN ? AND ?', month_time, month_time + 1.month)
                           .joins(project: [:company])
                           .where(projects: { company_id: company_id })
  
    
    Rails.logger.info("计算公司月度数据 - 项目需求SQL: #{project_requirements.to_sql}")
    # Rails.logger.info("计算公司月度数据 - 项目需求数量: #{project_requirements.size}")
    
    # 查询当月项目数
    monthly_projects = Project.where('projects.created_at BETWEEN ? AND ?', month_time, month_time + 1.month)
                       .where(company_id: company_id)
    
    if @user_channel_id.present?
      monthly_projects = monthly_projects.where(user_channel_id: @user_channel_id)
    end
    
    Rails.logger.info("计算公司月度数据 - 月度项目SQL: #{monthly_projects.to_sql}")
    Rails.logger.info("计算公司月度数据 - 月度项目数量: #{monthly_projects.size}")
    
    # 如果没有任务，返回基本数据结构
    if finished_tasks.empty? && project_requirements.empty? && monthly_projects.empty?
      Rails.logger.info("计算公司月度数据 - 未找到任何数据，返回空数据结构 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}")
      return {
        month_time: month_time,
        month_name: month_time.strftime('%Y-%m'),
        total_hours: 0,
        total_income: 0,
        total_cost: 0,
        gross_profit: 0,
        gross_profit_rate: 0,
        expert_price: 0,
        demand_hours: 0,
        completion_rate: 0,
        project_count: 0
      }
    end
    
    # Rails.logger.info("计算公司月度数据 - 找到数据，开始计算详细指标 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}")
    # Rails.logger.info("计算公司月度数据 - 完成的项目任务IDs: #{finished_tasks.pluck(:id)}")
    # Rails.logger.info("计算公司月度数据 - 项目需求IDs: #{project_requirements.pluck(:id)}")
    # Rails.logger.info("计算公司月度数据 - 月度项目IDs: #{monthly_projects.pluck(:id)}")
    
    # 初始化数据结构
    data = {
      month_time: month_time,
      month_name: month_time.strftime('%Y-%m'),
      total_income: 0,
      total_cost: 0,
      projects: Set.new,
      total_hours: 0,
      expert_fee: 0,
      expert_tax_fee: 0,
      recommend_fee: 0,
      translation_fee: 0,
      others_fee: 0
    }
    
    # 统计已完成任务数据
    Rails.logger.info("计算公司月度数据 - 开始统计已完成任务数据")
    finished_tasks.each do |task|
      Rails.logger.debug("计算公司月度数据 - 处理任务ID: #{task.id}, 项目ID: #{task.project_id}, 实际价格: #{task.actual_price}, 计费时长: #{task.charge_duration}分钟")
      
      # 累计收入
      data[:total_income] += (task.total_price - task.shorthand_price)
      
      # 累计小时数（分钟转小时，保留两位小数）
      data[:total_hours] += task.charge_duration / 60.0
      
      # 项目数（去重）
      data[:projects] << task.project_id
      
      # 累计各类费用
      task_costs = task.costs.to_a
      Rails.logger.debug("计算公司月度数据 - 任务ID: #{task.id} 的费用数量: #{task_costs.size}")
      
      task_costs.each do |cost|
        Rails.logger.debug("计算公司月度数据 - 处理费用ID: #{cost.id}, 类别: #{cost.category}, 价格: #{cost.price}")
        case cost.category
        when 'expert'
          data[:expert_fee] += cost.price
        when 'expert_tax'
          data[:expert_tax_fee] += cost.price
        when 'recommend'
          data[:recommend_fee] += cost.price
        when 'translation'
          data[:translation_fee] += cost.price
        when 'others'
          data[:others_fee] += cost.price
        end
      end
    end
    
    Rails.logger.info("计算公司月度数据 - 累计收入: #{data[:total_income]}, 累计小时数: #{data[:total_hours]}, 专家费用: #{data[:expert_fee]}, 专家税费: #{data[:expert_tax_fee]}")
    Rails.logger.info("计算公司月度数据 - 推荐费用: #{data[:recommend_fee]}, 翻译费用: #{data[:translation_fee]}, 其他费用: #{data[:others_fee]}")
    
    # 计算各项指标
    Rails.logger.info("计算公司月度数据 - 开始计算各项指标")
    
    # 计算项目数并移除临时集合
    data[:project_count] = monthly_projects.count
    Rails.logger.info("计算公司月度数据 - 项目数量: #{data[:project_count]}")
    data.delete(:projects)
    
    # 计算总支出
    data[:total_cost] = data[:expert_fee] + data[:expert_tax_fee] + data[:recommend_fee] + data[:translation_fee] + data[:others_fee]
    Rails.logger.info("计算公司月度数据 - 总支出: #{data[:total_cost]}")
    
    # 计算毛利（总收入-总支出）
    data[:gross_profit] = data[:total_income] - data[:total_cost]
    Rails.logger.info("计算公司月度数据 - 毛利: #{data[:gross_profit]}")
    
    # 计算毛利率（毛利/总收入，保留4位小数，显示为百分比保留2位小数）
    data[:gross_profit_rate] = data[:total_income].zero? ? 0 : ((data[:gross_profit] / data[:total_income]) * 10000).round / 100.0
    Rails.logger.info("计算公司月度数据 - 毛利率: #{data[:gross_profit_rate]}%")
    
    # 计算专家单价（总收入/总小时数，保留2位小数）
    data[:expert_price] = data[:total_hours].zero? ? 0 : (data[:total_income] / data[:total_hours]).round(2)
    Rails.logger.info("计算公司月度数据 - 专家单价: #{data[:expert_price]}")
    
    # 计算需求量（从ProjectRequirement表获取，确保为整数）
    data[:demand_hours] = project_requirements.present? ? project_requirements.sum(:demand_number).to_i : 0
    Rails.logger.info("计算公司月度数据 - 需求量: #{data[:demand_hours]}")
    
    # 计算转化率（搜索月份时项目创建的月份产生的访谈数量/搜索月份创建的项目对应的需求人数总和）
    # 获取当月创建的项目ID列表
    monthly_project_ids = monthly_projects.pluck(:id)
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 当月创建的项目IDs: #{monthly_project_ids}")
    
    # 分子：这些项目中产生的访谈数量（call_records表中rec_status为succ的记录数）
    succ_count_query = CallRecord.where(rec_status: 'succ')
                          .where(project_id: monthly_project_ids)
    
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 计算成功访谈数SQL: #{succ_count_query.to_sql}")
    succ_count = succ_count_query.count
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 成功访谈数: #{succ_count}")
    
    # 分母：这些项目对应的需求人数总和
    demand_sum_query = ProjectRequirement.where.not(status: 'cancelled')
                                  .where(project_id: monthly_project_ids)
    
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 计算需求总量SQL: #{demand_sum_query.to_sql}")
    demand_sum = demand_sum_query.sum(:demand_number)
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 需求总量: #{demand_sum}")
    
    # 计算转化率
    data[:task_count] = succ_count  # 添加成功访谈数量到返回数据中
    data[:completion_rate] = demand_sum.zero? ? 0 : ((succ_count.to_f / demand_sum) * 100).round(2)
    Rails.logger.info("计算公司月度数据 - 公司ID: #{company_id}, 月份: #{month_time.strftime('%Y-%m')}, 转化率: #{data[:completion_rate]}%")
    
    # 四舍五入小时数显示（保留两位小数）
    data[:total_hours] = data[:total_hours].round(2)
    Rails.logger.info("计算公司月度数据 - 最终小时数(四舍五入): #{data[:total_hours]}")
    
    return data
  end

end
