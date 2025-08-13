# encoding: utf-8
class FinanceController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /finance
  def index
    query = ProjectTask.where(status: 'finished')
    query = user_channel_filter(query, 'project_tasks.user_channel_id')
    # query = query.where('project_tasks.created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    # query = query.where('project_tasks.created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    query = query.where('project_tasks.started_at >= ?', params[:started_at_ge]) if params[:started_at_ge].present?
    query = query.where('project_tasks.started_at <= ?', params[:started_at_le]) if params[:started_at_le].present?
    %w[id project_id category interview_form charge_status payment_status user_channel_id].each do |field|
      query = query.where("project_tasks.#{field}" => params[field].strip) if params[field].present?
    end
    if params[:project].present?
      query = query.joins(:project).where('projects.code ILIKE :term OR projects.name ILIKE :term',
                                          { term: "%#{params[:project].strip}%" })
    end
    if params[:company].present?
      companies = Company.where('name ILIKE :company OR name_abbr ILIKE :company', { company: "%#{params[:company].strip}%"})
      query = query.joins(:project).where('projects.company_id' => companies.ids)
    end
    if params[:expert].present?
      query = query.joins(:expert).where('candidates.name ILIKE ?', "%#{params[:expert].strip}%")
    end
    # export excel files
    case params[:commit]
      when '中文模板' then export_project_tasks(query, category='cn') and return
      when '英文模板' then export_project_tasks(query, category='en') and return
      when '专家费打款' then export_project_tasks(query, category='expert_fee') and return
      when 'BDA-专家访谈账单模板' then export_project_tasks(query, category='bda') and return
      when 'IQVIA信息表' then export_project_tasks(query, category='iqvia_info') and return
      when 'IQVIA对账单' then export_project_tasks(query, category='supplier_statement') and return
      else nil
    end

    @project_tasks = query.order(:started_at => :desc).paginate(:page => params[:page], :per_page => 20)
  end

  # GET /finance/:id
  def show
    load_project_task
  end

  # GET /finance/:id/edit
  def edit
    load_project_task
  end

  # PUT /finance/:id
  def update
    begin
      load_project_task

      @project_task.actual_price    = params[:project_task][:actual_price]
      @project_task.shorthand_price = params[:project_task][:shorthand_price]
      @project_task.charge_status   = params[:project_task][:charge_status]
      @project_task.payment_status  = params[:project_task][:payment_status]
      if params.has_key?(:lijin)
        expert_cost = @project_task.costs.expert.first
        raise '缺少专家费用, missing expert fee' if expert_cost.nil?
        expert_cost.update(lijin: params[:lijin])
      end
      if @project_task.charge_status_changed?
        @project_task.set_charge_timestamp
      end
      if @project_task.save
        flash[:success] = t(:operation_succeeded)
        redirect_to finance_path(@project_task)
      else
        render :edit
      end
    rescue Exception => e
      flash.now[:error] = e.message
      render :edit
    end
  end

  # PUT /finance/:id/return_back
  def return_back
    load_project_task

    if @project_task.can_return_back?
      @project_task.update!(status: 'ongoing')
      flash[:success] = t(:operation_succeeded)
    else
      flash[:error] = t(:not_authorized)
    end
    redirect_to finance_index_path
  end

  # GET /finance/batch_update_charge_status
  def batch_update_charge_status
    if params[:status] == 'billed'
      ActiveRecord::Base.transaction do
        ProjectTask.where(id: params[:uids], charge_status: 'unbilled').each do |task|
          task.charge_status = 'billed'
          task.set_charge_timestamp
          task.save!
        end
      end
    elsif params[:status] == 'paid'
      ActiveRecord::Base.transaction do
        ProjectTask.where(id: params[:uids], charge_status: 'billed').each do |task|
          task.charge_status = 'paid'
          task.set_charge_timestamp
          task.save!
        end
      end
    end
    flash[:success] = t(:operation_succeeded)
    redirect_to finance_index_path
  end

  # GET /finance/batch_update_payment_status
  def batch_update_payment_status
    if params[:status] == 'paid'
      ActiveRecord::Base.transaction do
        ProjectTask.where(id: params[:uids], payment_status: 'unpaid').each do |task|
          task.update(payment_status: 'paid')
        end
      end
    end
    flash[:success] = t(:operation_succeeded)
    redirect_to finance_index_path
  end

  # GET /finance/export_finance_excel?mode=cn&uids[]=
  def export_finance_excel
    begin
      query = ProjectTask.where(id: params[:uids])
      case params[:mode]
        when 'cn' then export_project_tasks(query, 'cn')
        when 'en' then export_project_tasks(query, 'en')
        when 'expert_fee' then export_project_tasks(query, 'expert_fee')
        when 'bda' then export_project_tasks(query, 'bda')
        when 'iqvia_info' then export_project_tasks(query, 'iqvia_info')
        when 'supplier_statement' then export_project_tasks(query, 'supplier_statement')
        else raise('params error')
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to finance_index_path
    end
  end

  private
  def load_project_task
    @project_task = ProjectTask.find(params[:id])
    @can_operate = @project_task.user_channel_id == current_user.user_channel_id
  end

  def project_task_params
    params.require(:project_task).permit(:actual_price, :shorthand_price, :charge_status, :payment_status)
  end

  def export_project_tasks(query, category='cn')
    query_limit = 5000  # export data limit
    if query.count > query_limit
      flash[:error] = "导出数据条目过多, 当前: #{query.count}, 最大: #{query_limit}"
      redirect_to finance_index_path and return
    end

    template_path = case category
                    when 'cn' then 'public/templates/finance_template.xlsx'
                    when 'en' then 'public/templates/finance_template.xlsx'
                    when 'expert_fee' then 'public/templates/finance_template_expert_fee.xlsx'
                    when 'bda' then 'public/templates/finance_template_20211206.xlsx'
                    when 'iqvia_info' then 'public/templates/settlement_template_20230217.xlsx'
                    when 'supplier_statement' then 'public/templates/settlement_template_20250704.xlsx'
                    else ''
                    end

    raise 'template file not found' unless File.exist?(template_path)
    book = ::RubyXL::Parser.parse(template_path)                      # read from template file
    sheet = book[0]

    case category
    when 'cn' then set_sheet_cn_en(sheet, query, 'cn')
    when 'en' then set_sheet_cn_en(sheet, query, 'en')
    when 'expert_fee' then set_sheet_expert_fee(sheet, query)
    when 'bda' then set_sheet_bda_fee(sheet, query)
    when 'iqvia_info' then set_sheet_iqvia_info(sheet, query)
    when 'supplier_statement' then set_sheet_supplier_statement(sheet, query)
    else raise("invalid category[#{category}]")
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/finance_#{category}_#{current_user.id}_#{Time.now.strftime('%H%M%S')}.xlsx"
    book.write file_path
    send_file file_path
  end

  def set_sheet_cn_en(sheet, query, category='cn')
    query.order(:started_at => :desc).each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, task.project.company.name_abbr)          # 客户(公司)/Client
      sheet.add_cell(row, 1, task.project.name)                       # 项目名称/Project
      sheet.add_cell(row, 2, task.project.code)                       # 项目代码/Project code
      sheet.add_cell(row, 3, [task.project.main_client.try(:name), task.project.main_client.try(:nickname)].join(' '))   # 负责人/Seat
      sheet.add_cell(row, 4, task.started_at.strftime('%F %H:%M'))  # 日期/Date
      interview_form = case category
                         when 'cn' then ProjectTask::INTERVIEW_FORM[task.interview_form]
                         when 'en' then task.interview_form.capitalize
                         else task.interview_form
                       end
      sheet.add_cell(row, 5, interview_form)                          # 访谈类型
      sheet.add_cell(row, 6, "##{task.expert.uid}")                   # 专家编号/Expert UID
      expert_name = case category
                      when 'cn' then task.expert.name
                      when 'en' then task.expert.mr_name
                      else task.expert.name
                    end
      sheet.add_cell(row, 7, expert_name)                             # 专家姓名/Expert name
      exp = task.expert.latest_work_experience
      sheet.add_cell(row, 8, exp&.org_cn)                             # 专家公司名称/Expert company
      sheet.add_cell(row, 9, exp&.department)                         # 科室/Department
      sheet.add_cell(row, 10, exp&.title)                             # 专家职位/Expert title
      sheet.add_cell(row, 11, task.expert_level.capitalize)           # 专家级别/Expert level
      sheet.add_cell(row, 12, task.expert_rate)                       # 倍率/Rate
      sheet.add_cell(row, 13, task.duration)                          # 访谈时长/Duration
      sheet.add_cell(row, 14, task.charge_hour)                       # 收费小时/Charge Hour
      sheet.add_cell(row, 15, task.actual_price)                      # 总费用/Fee
      sheet.add_cell(row, 16, task.currency)                          # 币种/Currency
      sheet.add_cell(row, 17, task.memo)                              # 备注/Comment
      sheet.add_cell(row, 18, task.shorthand_price)                   # 速记费/Shorthand Fee
      sheet.add_cell(row, 19, task.expert.new_expert? ? 'Y' : 'N')    # 新专家/New Expert
      sheet.add_cell(row, 20, task.pm.name_cn)                        # 项目经理/PM
      sheet.add_cell(row, 21, task.creator.name_cn)                   # 专家招募/Research(creator)
      sheet.add_cell(row, 22, task.expert.cpt)                        # 专家基础费率
      # 支出信息
      other_cost = task.costs.where(category: 'others').first
      if other_cost
        sheet.add_cell(row, 23, other_cost.price)
      end
      expert_cost = task.costs.where(category: 'expert').first
      if expert_cost
        sheet.add_cell(row, 24, expert_cost.price)                         # 专家费/Expert Fee
        sheet.add_cell(row, 25, expert_cost.payment_info['username'])      # 账号名/Account name(Username)
        sheet.add_cell(row, 26, expert_cost.bank_or_alipay)                # 银行或者支付宝/Bank&Alipay
        sheet.add_cell(row, 27, expert_cost.payment_info['account'])       # 账号/Account
        sheet.add_cell(row, 28, expert_cost.payment_info['sub_branch'])    # 支行备注/Fee Comment
      end
      recommend_cost = task.costs.where(category: 'recommend').first
      if recommend_cost
        sheet.add_cell(row, 29, recommend_cost.price)                       # 推荐费/Recommend Fee
        sheet.add_cell(row, 30, recommend_cost.payment_info['username'])    # 推荐人账号名
        sheet.add_cell(row, 31, recommend_cost.bank_or_alipay)              # 推荐人银行或支付宝/Bank&Alipay
        sheet.add_cell(row, 32, recommend_cost.payment_info['account'])     # 推荐人帐号/Account
        sheet.add_cell(row, 33, recommend_cost.payment_info['sub_branch'])  # 推荐人支行备注/Sub-branch remarks
      end
      translation_cost = task.costs.where(category: 'translation').first
      if translation_cost
        sheet.add_cell(row, 34, translation_cost.price)                     # 翻译费/Translation
      end
      sheet.add_cell(row, 35, '')                                           # 备注/Remark
    end
  end

  def set_sheet_expert_fee(sheet, query)
    sheet.sheet_name = Time.now.strftime('%Y.%m')
    
    # 获取所有相关的costs并进行排序
    costs = ProjectTaskCost.joins(:project_task)
      .where(project_task_id: query.pluck(:id), category: %w[expert recommend translation others])
      .order("CASE WHEN payment_info ->> 'category' = 'alipay' THEN 1 WHEN payment_info ->> 'category' = 'unionpay' THEN 2 ELSE 3 END ASC, payment_info ->> 'account' ASC, payment_info ->> 'username' ASC")

    sum_price = 0
    row = 1
    costs.each do |cost|
      task = cost.project_task
        sheet.add_cell(row, 0, '')                                                             # 序号
        sheet.add_cell(row, 1, '')                                                             # 是否兴业银行
        sheet.add_cell(row, 2, CandidatePaymentInfo::CATEGORY[cost.payment_info['category']])  # 支付宝/银联
        sheet.add_cell(row, 3, cost.payment_info['account'])                                   # 收款账号
        sheet.add_cell(row, 4, cost.payment_info['username'])                                  # 收款户名
        sheet.add_cell(row, 5, '')
        if cost.payment_info['category'] == 'unionpay'
          sheet.add_cell(row, 5, [cost.payment_info['bank'], cost.payment_info['sub_branch']].join)  # 收款银行及营业网点
        end
        sheet.add_cell(row, 6, task.expert.phone)
        sheet.add_cell(row, 7, cost.payment_info['id_number'])
        sheet.add_cell(row, 8, '')                                                              # 是否同城
        sheet.add_cell(row, 9, '')                                                              # 汇入地址
        sheet.add_cell(row, 10, cost.price)                                                     # 转账金额
        sheet.add_cell(row, 11, '')                                                             # 转账用途

        if cost.category == 'expert' && cost.payment_info['category'] == 'unionpay'
          tax_cost = task.costs.where(category: 'expert_tax').first
          sheet.add_cell(row, 12, tax_cost&.price)
        end
        sheet.add_cell(row, 13, cost.memo)
        sheet.add_cell(row, 14, task.project.company.name_abbr)

        sum_price += cost.price
        row += 1
    end
    sheet.add_cell(row, 10, sum_price)                                                          # 金额汇总
    sheet.add_cell(row, 11, (sum_price / 0.95).round(2))                                        # 金额汇总 / 0.95
  end

  def set_sheet_bda_fee(sheet, query)
    query.order(started_at: :desc).each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 1, task.uid)                           # B, Reference Code/费用编号
      sheet.add_cell(row, 2, task.started_at.strftime('%F'))     # C, Date/访谈日期
      sheet.add_cell(row, 3, task.client.name)                   # D, BDA User/联系人
      sheet.add_cell(row, 4, task.started_at.strftime('%H:%M'))  # E, Time/访谈时间
      sheet.add_cell(row, 5, task.project.name)                  # F, Project/项目名称
      sheet.add_cell(row, 6, task.expert.name)                   # G, Exp.Name/专家姓名
      exp = task.expert.latest_work_experience
      sheet.add_cell(row, 7, exp.title)                          # H, Exp.Position/专家职位
      sheet.add_cell(row, 8, exp.org_cn)                         # I, Exp.Company/专家公司
      sheet.add_cell(row, 9, task.interview_form)                # J, Type/访谈类型
      sheet.add_cell(row, 10, (task.duration / 60.0).round(2))   # K, Interview Length(h)/访谈实际时长(h)
      sheet.add_cell(row, 11, (task.charge_duration/60.0).round(2)) # L, Charge Hour(h)/收费时长(h)
      sheet.add_cell(row, 12, task.expert_rate)                  # M, Multiple/费率倍数
      sheet.add_cell(row, 13, task.charge_rate)                  # N, Price Per Hour/单价（含税）
      sheet.add_cell(row, 14, task.actual_price)                 # O, Charge/费用（含税）
    end
  end

  def set_sheet_iqvia_info(sheet, query)
    query.each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, index + 1)                                                       # A, 序号
      sheet.add_cell(row, 1, 'hci consulting')                                                # B, 供应商
      sheet.add_cell(row, 2, task.project.code)                                                    # C, Internal code
      sheet.add_cell(row, 3, task.expert_name_for_external)                                   # D, 专家名称
      # exp = task.expert.latest_work_experience
      exp = task.active_exp
      sheet.add_cell(row, 4, exp.org_cn)                                                      # E, 公司/医院/单位
      sheet.add_cell(row, 5, exp.department)                                                  # F, 部门/科室
      sheet.add_cell(row, 6, exp.title)                                                       # G, 职位/职称
      sheet.add_cell(row, 7, (task.started_at.strftime('%Y/%m/%d') rescue ''))                # H, 访谈日期
      sheet.add_cell(row, 8, 2100)                                                            # I, 标准费率/RMB/元
      sheet.add_cell(row, 9, task.charge_duration)                                            # J, 访问时长/分钟
      sheet.add_cell(row, 10, task.total_price - task.lijin_for_settlement)                   # K, 招募费用
      sheet.add_cell(row, 11, task.lijin_for_settlement)                                      # L, 礼金（专家实际领取费用）
      sheet.add_cell(row, 12, task.expert_rate)                                               # M, 专家倍率
      sheet.add_cell(row, 13, task.total_price)                                               # N, 总费用RMB/元
      sheet.add_cell(row, 14, 0)                                                              # O, 招募费用-未超时部分
      sheet.add_cell(row, 15, 0)                                                              # P, 时长超出90分钟后招募费5折减免金额
      sheet.add_cell(row, 16, 0)                                                              # Q, 礼金（专家实际领取费用）
      sheet.add_cell(row, 17, 0)                                                              # R, 实际费用RMB/元
    end
  end

  # 供应商对账单
  def set_sheet_supplier_statement(sheet, query)
    query.each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, index + 1)                                                       # A, 序号
      sheet.add_cell(row, 1, 'hci consulting')                                                # B, 供应商
      sheet.add_cell(row, 2, task.project.code)                                               # C, Internal code
      sheet.add_cell(row, 3, "# #{task.expert.uid}")                                          # D, 专家编号 (原专家名称)
      # 删除了原来的 E, F, G 列 (公司/医院/单位, 部门/科室, 职位/职称)
      sheet.add_cell(row, 4, (task.started_at.strftime('%Y/%m/%d') rescue ''))                # E, 访谈日期 (原H列)
      sheet.add_cell(row, 5, 2100)                                                            # F, 标准费率/RMB/元 (原I列)
      sheet.add_cell(row, 6, task.charge_duration)                                            # G, 访问时长/分钟 (原J列)
      sheet.add_cell(row, 7, task.total_price - task.lijin_for_settlement)                   # H, 招募费用 (原K列)
      sheet.add_cell(row, 8, task.lijin_for_settlement)                                      # I, 礼金（专家实际领取费用） (原L列)
      sheet.add_cell(row, 9, task.expert_rate)                                               # J, 专家倍率 (原M列)
      sheet.add_cell(row, 10, task.total_price)                                               # K, 总费用RMB/元 (原N列)
      sheet.add_cell(row, 11, 0)                                                              # L, 招募费用-未超时部分 (原O列)
      sheet.add_cell(row, 12, 0)                                                              # M, 时长超出90分钟后招募费5折减免金额 (原P列)
      sheet.add_cell(row, 13, 0)                                                              # N, 礼金（专家实际领取费用） (原Q列)
      sheet.add_cell(row, 14, 0)                                                              # O, 实际费用RMB/元 (原R列)
    end
  end

end