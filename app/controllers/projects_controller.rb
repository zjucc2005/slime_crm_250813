# encoding: utf-8
require 'rubyXL/convenience_methods'

class ProjectsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /projects
  def index
    # query = current_user.is_role?('admin') ? Project.all : current_user.projects
    query = params[:my_project] == 'true' ? current_user.projects : Project.all
    query = user_channel_filter(query)
    query = query.where('projects.created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    query = query.where('projects.created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    %w[name code].each do |field|
      query = query.where("projects.#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
    end
    %w[id status user_channel_id].each do |field|
      query = query.where("projects.#{field}" => params[field]) if params[field].present?
    end
    if params[:company].present?
      query = query.joins(:company).where('companies.name ILIKE :company OR companies.name_abbr ILIKE :company', { company: "%#{params[:company].strip}%" })
    end
    if params[:client_name].present?
      query = query.joins(:candidates).where('candidates.category': 'client').where('candidates.name ILIKE ?', "%#{params[:client_name].strip}%").distinct
    end
    if params[:client_id].present?
      query = query.joins(:project_candidates).where('project_candidates.category': 'client', 'project_candidates.candidate_id': params[:client_id]).distinct
    end

    # export excel files
    case params[:commit]
    when 'Weekly update' then export_projects(query.order(created_at: :desc), category='weekly_update') and return
    when I18n.t(:standard_template) then export_projects(query.order(created_at: :desc), category='standard') and return
    when '项目总费用统计表' then export_projects(query.order(created_at: :desc), category='total_fee') and return
    else nil
    end

    @projects = query.order(updated_at: :desc).paginate(:page => params[:page], :per_page => 20)
  end

  # GET /projects/new
  def new
    @project = Project.new
    load_signed_company_options
  end

  # GET /projects/:id/edit_finance
  def edit_finance
    @project = Project.find(params[:id])
    authorize! :edit_finance, @project
  end

  def update_finance
    @project = Project.find(params[:id])
    
    if @project.update(project_finance_params)
      flash[:notice] = '项目信息更新成功'
    else
      flash[:error] = '项目信息更新失败'
    end

    respond_to do |format|
      format.js
      format.html { redirect_to finance_dashboard_statistics_path }
    end
  end

  def create
    begin
      @project = Project.new(project_params.merge(created_by: current_user.id, user_channel_id: current_user.user_channel_id))

      if @project.valid?
        ActiveRecord::Base.transaction do
          @project.save!
          if current_user.is_role?('pm')
            @project.project_users.find_or_create_by!(category: 'pm', user_id: current_user.id)
          end
        end
        flash[:success] = t(:operation_succeeded)
        redirect_to project_path(@project)
      else
        load_signed_company_options
        render :new
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  def project_finance_params
    params.require(:project).permit(
      :total_price,
      :invoice_amount,
      :status,
      :invoice_payment_date,
      project_remarks_attributes: [:id, :remark, :_destroy]
    )
  end

  # GET /projects/:id
  def show
    load_project
  end

  # GET /projects/:id/edit
  def edit
    load_project
    load_signed_company_options
  end

  # PUT /projects/:id
  def update
    begin
      load_project

      if @project.update(project_params_update)
        flash[:success] = t(:operation_succeeded)
        redirect_to project_path(@project)
      else
        load_signed_company_options
        render :edit
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # DELETE /projects/:id
  def destroy
    begin
      load_project

      if @project.can_destroy?
        @project.destroy!
        flash[:success] = t(:operation_succeeded)
        redirect_to projects_path
      else
        raise t(:cannot_delete)
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # GET/PUT /projects/add_users
  def add_users
    # if request.put?
    #   begin
    #     @project = Project.find(params[:project_id])
    #     raise t(:not_authorized) unless @project.can_edit?
    #
    #     ActiveRecord::Base.transaction do
    #       # add pm
    #       pm_users = User.where(id: params[:uids], role: 'pm')
    #       pa_users = User.where(id: params[:uids], role: 'pa')
    #       pm_users.each do |user|
    #         @project.project_users.find_or_create_by!(category: user.role, user_id: user.id)
    #       end
    #       # add pa
    #       pa_users.each do |user|
    #         @project.project_users.find_or_create_by!(category: user.role, user_id: user.id)
    #       end
    #     end
    #     flash[:success] = t(:operation_succeeded)
    #     redirect_to project_path(@project)
    #   rescue Exception => e
    #     flash[:error] = e.message
    #     redirect_to projects_path
    #   end
    # end

    begin
      @project = Project.find(params[:project_id])
      raise t(:not_authorized) unless @project.can_edit?

      ActiveRecord::Base.transaction do
        # add pm
        pm_users = User.where(id: params[:uids], role: %w[admin pm])
        pa_users = User.where(id: params[:uids], role: 'pa')
        pm_users.each do |user|
          @project.project_users.find_or_create_by!(category: user.role, user_id: user.id)
        end
        # add pa
        pa_users.each do |user|
          @project.project_users.find_or_create_by!(category: user.role, user_id: user.id)
        end
      end
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # GET/PUT /projects/add_experts.js
  def add_experts
    # if request.put?
    #   begin
    #     @project = Project.find(params[:project_id])
    #     raise t(:not_authorized) unless @project.can_edit?
    #
    #     ActiveRecord::Base.transaction do
    #       (params[:uids] || []).each do |candidate_id|
    #         @project.project_candidates.expert.find_or_create_by!(candidate_id: candidate_id)
    #       end
    #     end
    #     flash[:success] = t(:operation_succeeded)
    #     if params[:commit] == t('action.submit_and_continue_to_add')
    #       redirect_to candidates_path(from_source: 'project', project_id: @project.id)
    #     else
    #       redirect_to project_path(@project)
    #     end
    #   rescue Exception => e
    #     flash[:error] = e.message
    #     redirect_to projects_path
    #   end
    # end

    begin
      @project = Project.find(params[:project_id])
      raise t(:not_authorized) unless @project.can_edit?

      ActiveRecord::Base.transaction do
        (params[:uids] || []).each do |candidate_id|
          @project.project_candidates.expert.find_or_create_by!(candidate_id: candidate_id)
        end
      end
      @notice = t(:operation_succeeded)

      if params[:mode] == '0'
        flash[:success] = t(:operation_succeeded)
        redirect_to project_path(@project)
      end
    rescue Exception => e
      @notice = e.message
    end

    respond_to do |f|
      f.js
      f.html
    end
  end

  # GET/PUT /projects/:id/add_clients
  def add_clients
    begin
      load_project
      query = @project.company.candidates
      %w[name nickname title phone email].each do |field|
        query = query.where("#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
      end
      @clients = query.order(:created_at => :desc)

      if request.put?
        raise t(:not_authorized) unless @project.can_edit?

        ActiveRecord::Base.transaction do
          uids = params[:uids] || []
          @project.project_candidates.client.where.not(candidate_id: uids).destroy_all
          uids.each do |candidate_id|
            next if @project.project_candidates.client.exists?(candidate_id: candidate_id)
            @project.project_candidates.client.create!(candidate_id: candidate_id)
          end
        end
        flash[:success] = t(:operation_succeeded)
        redirect_to project_path(@project)
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # GET/PUT /projects/:id/add_project_task
  def add_project_task
    begin
      load_project
      @contract = @project.active_contract
      @project_task = @project.project_tasks.new(expert_id: params[:expert_id], expert_level: @contract.expert_level)

      if request.put?
        raise t(:not_authorized) unless @project.can_add_task?
        @project_task = ProjectTask.new(project_task_params.merge(project_id: @project.id,
                                                                  created_by: current_user.id,
                                                                  user_channel_id: current_user.user_channel_id))
        if @project_task.save
          if params[:call_record_id].present?
            @call_record = CallRecord.find_by(id: params[:call_record_id])
            @call_record&.update!(project_task_id: @project_task.id)
          end
          flash[:success] = t(:operation_succeeded)
          redirect_with_return_to(project_path(@project))
        else
          render :add_project_task
        end
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # GET/PUT /projects/:id/add_project_requirement
  def add_project_requirement
    begin
      load_project
      @project_requirement = @project.project_requirements.new

      if request.put?
        raise t(:not_authorized) unless @project.can_add_requirement?

        # @project_requirement = @project.project_requirements.new(project_requirement_params.to_h.merge(created_by: current_user.id))
        @project_requirement = ProjectRequirement.new(project_requirement_params.merge(project_id: @project.id, created_by: current_user.id))
        if @project_requirement.save
          flash[:success] = t(:operation_succeeded)
          redirect_to project_path(@project)
        else
          render :add_project_requirement
        end
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # DELETE /projects/:id/delete_user?user_id=1
  def delete_user
    begin
      load_project
      raise t(:not_authorized) unless @project.can_edit?
      @project.project_users.find_by(user_id: params[:user_id]).destroy
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # DELETE /projects/:id/delete_expert?expert_id=1
  def delete_expert
    begin
      load_project
      raise t(:not_authorized) unless @project.can_edit?
      @project.project_candidates.find_by(candidate_id: params[:expert_id]).destroy
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # DELETE /projects/:id/delete_client?client_id=1
  def delete_client
    begin
      load_project
      raise t(:not_authorized) unless @project.can_edit?
      @project.project_candidates.find_by(candidate_id: params[:client_id]).destroy
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # POST /project/:id/start
  def start
    begin
      load_project
      raise t(:not_authorized) unless @project.can_start?
      @project.start!
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  def finish
    begin
      load_project
      raise t(:not_authorized) unless @project.can_finish?
      @project.finish!
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  def billing
    begin
      load_project
      raise t(:not_authorized) unless @project.can_billing?
      @project.invoice_no = params[:invoice_no]
      @project.attributes = {
        invoice_no: params[:invoice_no],
        invoice_payment_date: params[:invoice_payment_date],
        invoice_amount: params[:invoice_amount],
        invoice_file: params[:invoice_file],
      }
      @project.status = 'billing'
      @project.billing_at ||= Time.now
      @project.save!
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  def billed
    begin
      load_project
      raise t(:not_authorized) unless @project.can_billed?
      @project.status = 'billed'
      @project.billed_at ||= Time.now
      @project.save!
      flash[:success] = t(:operation_succeeded)
      redirect_to project_path(@project)
    rescue => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # @param status : String
  # @param uids : Array
  def batch_update_status
    begin
      if params[:status] == 'finished'
        ActiveRecord::Base.transaction do
          Project.where(id: params[:uids], status: 'ongoing').each do |project|
            project.update(status: 'finished')
          end
        end
      elsif params[:status] == 'billed'
        ActiveRecord::Base.transaction do
          Project.where(id: params[:uids], status: ['billing', 'ongoing', 'finished']).each do |project|
            project.update(status: 'billed', billed_at: Time.now)
          end
        end
      end
      flash[:success] = t(:operation_succeeded)
      redirect_to projects_path
    rescue => e
      flash[:error] = e.message
      redirect_to projects_path
    end
  end

  # GET /projects/:id/experts
  def experts
    load_project
    query = @project.experts
    @experts = query.paginate(:page => params[:page], :per_page => 100)
  end

  # GET /projects/:id/project_tasks
  def project_tasks
    load_project
    query = @project.project_tasks
    @project_tasks = query.order(:created_at => :desc).paginate(:page => params[:page], :per_page => 20)
  end

  # GET /projects/:id/user_options.json
  def user_options
    load_project
    users = @project.users
    render :json => users.map{|user| [user.uid_name , user.id] }
  end

  # POST /projects/:id/export_billing_excel?template=1&close_or_not=false
  def export_billing_excel
    load_project
    begin
      case params[:template]
      when 'settlement_20210604_1' then export_settlement_20210604_1(@project)
      when 'settlement_202206' then export_settlement_202206(@project)
      when 'settlement_20230217' then export_settlement_20230217(@project)
      when 'settlement_20250704' then export_settlement_20250704(@project)
      else raise('template not found')
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to project_path(@project)
    end
  end

  def work_board
    query = current_user.admin? ? Project.all : current_user.projects
    query = user_channel_filter(query)
    query = query.where('created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    query = query.where('created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    %w[name code].each do |field|
      query = query.where("#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
    end
    %w[id status].each do |field|
      query = query.where(field.to_sym => params[field]) if params[field].present?
    end
    if params[:company].present?
      query = query.joins(:company).where('companies.name ILIKE :company OR companies.name_abbr ILIKE :company', { company: "%#{params[:company].strip}%" })
    end
    if params[:client_name].present?
      query = query.joins(:candidates).where('candidates.category': 'client').where('candidates.name ILIKE ?', "%#{params[:client_name].strip}%").distinct
    end
    @projects = query.order(updated_at: :desc).paginate(page: params[:page], per_page: 10)
  end

  # GET .js/json
  def load_project_requirements
    @project = Project.find_by(id: params[:project_id])
    @options = '<option value>Please select</option>'
    if @project
      @options += @project.project_requirements.order(created_at: :asc).map { |item| "<option value=\"#{item.id}\">#{item.title}</option>" }.join
    end
    respond_to { |f| f.js }
  end

  # def v_dashboard; end
  # def v_dashboard_data
  #   begin
  #     render json: { status: 0, data: { projects: dashboard_projects.map(&:to_api_dashboard) } }
  #   rescue => e
  #     render json: { status: 1, msg: e.message }
  #   end
  # end

  def v_pm_dashboard_data
    begin
      page = Integer(params[:page]) rescue 1
      per_page = Integer(params[:per_page]) rescue 10
      query = current_user.admin? ? Project.all : current_user.projects
      query = query.where(status: %w[initialized ongoing])
      rec_count = query.joins(:call_records).where('call_records.rec_status': 'recommended').count

      %w[name code].each do |field|
        query = query.where("projects.#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
      end
      if params[:company_name_abbr].present?
        query = query.joins(:company).where('companies.name ILIKE :company OR companies.name_abbr ILIKE :company', { company: "%#{params[:company_name_abbr].strip}%" })
      end
      if [true, 'true', 1, '1'].include?(params[:is_rec])
        query = query.joins(:call_records).where('call_records.rec_status': 'recommended').distinct
      end
      @projects = query.order(id: :desc).paginate(page: page, per_page: per_page)
      render json: { 
        status: 0, 
        data: { 
          projects: @projects.map(&:to_api_dashboard),
          rec_count: rec_count,
          total: query.count, page: page, per_page: per_page
        }
      }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_pa_dashboard_data
    begin
      query = ProjectRequirement.where(status: 'ongoing', operator_id: current_user.id)
      %w[name code].each do |field|
        query = query.joins(:project).where("projects.#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
      end
      if params[:company_name_abbr].present?
        company_ids = Company.where("name ILIKE :company OR name_abbr ILIKE :company", { company: "%#{params[:company_name_abbr].strip}%"}).ids
        query = query.joins(:project).where("projects.company_id": company_ids)
      end
      ordering = params[:ordering] == 'asc' ? :asc : :desc
      @project_requirements = query.order(priority: :desc, id: ordering)
      render json: { status: 0, data: { project_requirements: @project_requirements.map(&:to_api_dashboard_index) } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  private
  def load_project
    @project = Project.find(params[:id])
    @can_operate = @project.can_be_operated_by(current_user)
  end

  def dashboard_projects
    query = current_user.su? ? Project.all : current_user.projects
    query.where(status: %w[initialized ongoing]).order(:company_id, :created_at)
  end

  def project_params
    params.require(:project).permit(:company_id, :name, :code, :industry)
  end

  def project_params_update
    params.require(:project).permit(:name, :code, :industry, :requirement, :started_at, :ended_at)
  end

  def project_task_params
    params.require(:project_task).permit(:category, :expert_id, :client_id, :pm_id, :interview_form, :started_at, :expert_level,
                                         :expert_rate, :expert_alias, :candidate_experience_id)
  end

  def project_requirement_params
    params.require(:project_requirement).permit(:title, :content, :demand_number, :file, :operator_id)
  end

  # 加载客户公司
  def load_signed_company_options
    @signed_company_options = user_channel_filter(Company.signed).pluck(:name, :id)
  end

  # 导出项目信息
  def export_projects(query, category)
    query_limit = 1000  # export data limit
    if query.count > query_limit
      flash[:error] = "导出数据条目过多, 当前: #{query.count}, 最大: #{query_limit}"
      redirect_to projects_path and return
    end

    template_path = case category
                    when 'weekly_update' then 'public/templates/project_weekly_update_template.xlsx'
                    when 'standard' then 'public/templates/project_standard_template.xlsx'
                    when 'total_fee' then 'public/templates/project_total_fee_template.xlsx'
                    else ''
                    end

    raise 'template file not found' unless File.exist?(template_path)
    book = ::RubyXL::Parser.parse(template_path)                      # read from template file
    sheet = book[0]

    case category
    when 'weekly_update' then set_sheet_weekly_update(sheet, query)
    when 'standard' then set_sheet_standard(sheet, query)
    when 'total_fee' then set_sheet_total_fee(sheet, query)
    else raise("invalid category[#{category}]")
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/projects_#{category}_#{current_user.id}_#{Time.now.strftime('%H%M%S')}.xlsx"
    book.write file_path
    send_file file_path
  end

  def set_sheet_weekly_update(sheet, query)
    current_week = Time.now.beginning_of_week
    row = 1
    query.each do |project|
      if project.created_at >= current_week
        project_phase = 'New'
      elsif project.updated_at < Time.now - 1.week  # 1周内未更新的项目
        project_phase = 'Pending'
      else
        project_phase = 'On-going'
      end
      current_week_task_count = project.project_tasks.where(status: 'finished').where('started_at >= ?', current_week).count
      last_week_task_count = project.project_tasks.where(status: 'finished').where('started_at >= ? AND started_at < ?', current_week - 1.week, current_week).count

      sheet.add_cell(row, 0, project.code)                                      # 项目号/项目代码
      sheet.add_cell(row, 1, project.name)                                      # 项目名称
      sheet.add_cell(row, 2, project.created_at.strftime('%F'))                 # 收到项目日期/创建日期
      sheet.add_cell(row, 3, project_phase)                                     # 项目阶段 [new/on-going/pending]
      sheet.add_cell(row, 4, project.project_requirements.sum(:demand_number))  # 计划出Call/项目需求总人数
      sheet.add_cell(row, 5, last_week_task_count)                              # 上周出Call / 上周完成任务
      sheet.add_cell(row, 6, current_week_task_count)                           # 本周出Call / 本周完成任务数
      sheet.add_cell(row, 7, '')                                                # 下周预计出Call
      sheet.add_cell(row, 8, '')                                                # 备注
      row += 1
    end

    sheet.add_cell(row, 3, '小计')
    sheet.add_cell(row, 4, '', "SUM(E2:E#{row})")
    sheet.add_cell(row, 5, '', "SUM(F2:F#{row})")
  end

  def set_sheet_standard(sheet, query)
    query.each_with_index do |project, index|
      row = index + 1
      sheet.add_cell(row, 0, "# #{project.uid}")
      sheet.add_cell(row, 1, project.name)
      sheet.add_cell(row, 2, (project.main_client.name rescue ''))
      sheet.add_cell(row, 3, project.code)
      sheet.add_cell(row, 4, project.company.name_abbr)
      sheet.add_cell(row, 5, (project.project_requirements.sum(:demand_number) rescue 'ERROR'))
      sheet.add_cell(row, 6, project.total_project_tasks)
      sheet.add_cell(row, 7, "#{project.total_charge_duration} h")
      sheet.add_cell(row, 8, Project::STATUS[project.status] || project.status)
      sheet.add_cell(row, 9, (project.creator.name_cn rescue 'NA'))
      sheet.add_cell(row, 10, project.created_at.strftime('%F %T'))
      sheet.add_cell(row, 11, project.updated_at.strftime('%F %T'))
    end
  end

  def set_sheet_total_fee(sheet, query)
    query.each_with_index do |project, index|
      row = index + 1
      sheet.add_cell(row, 0, project.company.name_abbr)
      sheet.add_cell(row, 1, project.name)
      sheet.add_cell(row, 2, project.code)
      sheet.add_cell(row, 3, Project::STATUS[project.status] || project.status)
      sheet.add_cell(row, 4, project.total_price)
      sheet.add_cell(row, 5, project.created_at.strftime('%F %T'))
    end
  end

  def export_settlement_20210604_1(project)
    template_path = 'public/templates/settlement_template_20210604_1.xlsx'
    raise 'template file not found' unless File.exist?(template_path)
    query = project.project_tasks.where(status: 'finished').order(:started_at => :asc)
    raise 'project task not found' if query.count == 0

    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[0]
    sheet.add_cell(0, 2, query.count)  # B1, 访谈个数

    query.each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, task.memo)
      sheet.add_cell(row, 1, task.project.name)                                               # A, 项目名称
      sheet.add_cell(row, 2, task.project.code)                                               # B, 项目号
      sheet.add_cell(row, 3, '')                                                              # C, 访谈人
      sheet.add_cell(row, 4, ProjectTask::INTERVIEW_FORM[task.interview_form])                # D, 访问类型
      sheet.add_cell(row, 5, "# #{task.expert.uid}")                                          # E, 专家编号
      sheet.add_cell(row, 6, task.expert_name_for_external)                                   # F, 专家称呼
      # exp = task.expert.latest_work_experience
      exp = task.active_exp
      exp ? sheet.add_cell(row, 7, "#{exp.org_cn}#{exp.title}") : sheet.add_cell(row, 6, '')  # G, 专家信息
      sheet.add_cell(row, 8, (task.started_at.strftime('%F') rescue ''))                      # H, 访谈日期
      sheet.add_cell(row, 9, (task.started_at.strftime('%H:%M') rescue ''))                   # I, 开始时间
      sheet.add_cell(row, 10, (task.ended_at.strftime('%H:%M') rescue '' ))                    # J, 结束时间
      sheet.add_cell(row, 11, task.duration)                                                  # K, 访谈时长
      sheet.add_cell(row, 12, task.charge_duration)                                           # L, 收费时长
      sheet.add_cell(row, 13, (2100 * task.expert_rate).round(2))                             # M, 访谈单价
      # sheet.add_cell(row, 13, (task.actual_price / 0.84).round(2))                            # N, 折前费用
      sheet.add_cell(row, 14, task.actual_price)                                              # N, 折后费用
      sheet.add_cell(row, 15, task.lijin_for_settlement)               # O, 礼金费用
      sheet.add_cell(row, 16, '银行卡转账（公对私）')                                             # P, 礼金支付方式
    end

    ActiveRecord::Base.transaction do
      query.each do |task|
        task.update(charge_status: 'billed') if task.charge_status == 'unbilled'  # 自动更新收费状态
      end
      project.close! if params[:close_or_not] == 'true'  # 关闭项目选项
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/#{project.code}_对账单.xlsx"
    book.write file_path
    send_file file_path
  end

  def export_settlement_202206(project)
    template_path = 'public/templates/settlement_template_202206.xlsx'
    raise 'template file not found' unless File.exist?(template_path)
    query = project.project_tasks.where(status: 'finished').order(started_at: :asc)
    raise 'project task not found' if query.count == 0
    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[1]

    query.each_with_index do |task, index|
      sheet.add_validation_list("F#{index + 2}", Utils::ExcelDropdown.interviewee_type_list)
      sheet.add_validation_list("H#{index + 2}", Utils::ExcelDropdown.fw_method_list)
      sheet.add_validation_list("K#{index + 2}", Utils::ExcelDropdown.hospital_level_list)
      sheet.add_validation_list("N#{index + 2}", Utils::ExcelDropdown.jishuzhicheng_list)
      sheet.add_validation_list("O#{index + 2}", Utils::ExcelDropdown.xingzhengzhiwu_list)
      sheet.add_validation_list("U#{index + 2}", Utils::ExcelDropdown.lijin_payer_list)
      sheet.add_validation_list("W#{index + 2}", Utils::ExcelDropdown.lijin_payment_list)

      row = index + 1
      sheet.add_cell(row, 0, project.code)                                                    # A, 内部项目号
      sheet.add_cell(row, 1, index + 1)                                                       # B, 序号
      prov, city = LocationDatum.parse(task.expert.city.to_s)
      sheet.add_cell(row, 2, prov)                                                            # C, 省份
      sheet.add_cell(row, 3, city)                                                            # D, 城市
      sheet.add_cell(row, 4, project.name)                                                    # E, 疾病领域/项目标题
      sheet.add_cell(row, 7, '定性IDI（电话访问）')                                              # H, FW执行方法
      # exp = task.expert.latest_work_experience
      exp = task.active_exp
      sheet.add_cell(row, 9, exp.org_cn)                                                      # J, 受访者所在单位名称
      sheet.add_cell(row, 10, task.expert.category == 'doctor' ? Hospital.level_sort(exp.org_en.to_s) : '')             # K, 医院级别
      sheet.add_cell(row, 11, exp.department)                                                 # L, 科室
      sheet.add_cell(row, 12, task.expert_name_for_external)                                  # M, 医生姓名
      sheet.add_cell(row, 13, exp.title)                                                      # N, 技术职称
      sheet.add_cell(row, 14, exp.title1)                                                     # O, 行政职务
      sheet.add_cell(row, 16, '4008063263')                                                   # Q, 受访者手机号码
      sheet.add_cell(row, 17, (task.started_at.strftime('%Y/%m/%d') rescue ''))               # R, 访问日期
      sheet.add_cell(row, 18, (task.started_at.strftime('%H:%M') rescue ''))                  # S, 访问时间
      sheet.add_cell(row, 19, '263会议')                                                       # T, 访问地点
      sheet.add_cell(row, 20, '由代理支付礼金')                                                  # U, 礼金支付方
      sheet.add_cell(row, 21, task.lijin_for_settlement)                                      # V, 礼金支付数额
      sheet.add_cell(row, 22, '银行卡转帐（公对私）')                                             # W, 礼金支付方式
      sheet.add_cell(row, 24, '')                                                             # Y, 支付宝/微信账号
      sheet.add_cell(row, 25, '海鄞信息咨询(上海)有限公司')                                        # Z, 招募途径
      sheet.add_cell(row, 33, '')                                                             # AH, 单招募费
      sheet.add_cell(row, 34, '')                                                             # AI, 样本总金额
      sheet.add_cell(row, 35, "#{task.duration}分钟")                                          # AJ, 访谈时长
    end

    ActiveRecord::Base.transaction do
      query.each do |task|
        task.update(charge_status: 'billed') if task.charge_status == 'unbilled'  # 自动更新收费状态
      end
      project.close! if params[:close_or_not] == 'true'  # 关闭项目选项
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/#{project.code}_定性受访信息表.xlsx"
    book.write file_path
    send_file file_path
  end

  # 信息表
  def export_settlement_20230217(project)
    template_path = 'public/templates/settlement_template_20230217.xlsx'
    raise 'template file not found' unless File.exist?(template_path)
    query = project.project_tasks.where(status: 'finished').order(started_at: :asc)
    raise 'project task not found' if query.count == 0
    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[0]

    query.each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, index + 1)                                                       # A, 序号
      sheet.add_cell(row, 1, 'hci consulting')                                                # B, 供应商
      sheet.add_cell(row, 2, project.code)                                                    # C, Internal code
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

    ActiveRecord::Base.transaction do
      query.each do |task|
        task.update(charge_status: 'billed') if task.charge_status == 'unbilled'  # 自动更新收费状态
      end
      project.close! if params[:close_or_not] == 'true'  # 关闭项目选项
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/#{project.code}_信息表.xlsx"
    book.write file_path
    send_file file_path
  end

  # 供应商对账单
  def export_settlement_20250704(project)
    template_path = 'public/templates/settlement_template_20250704.xlsx'
    raise 'template file not found' unless File.exist?(template_path)
    query = project.project_tasks.where(status: 'finished').order(started_at: :asc)
    raise 'project task not found' if query.count == 0
    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[0]

    query.each_with_index do |task, index|
      row = index + 2
      sheet.add_cell(row, 0, index + 1)                                                       # A, 序号
      sheet.add_cell(row, 1, 'hci consulting')                                                # B, 供应商
      sheet.add_cell(row, 2, project.code)                                                    # C, Internal code
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

    ActiveRecord::Base.transaction do
      query.each do |task|
        task.update(charge_status: 'billed') if task.charge_status == 'unbilled'  # 自动更新收费状态
      end
      project.close! if params[:close_or_not] == 'true'  # 关闭项目选项
    end

    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/#{project.code}_供应商对账单.xlsx"
    book.write file_path
    send_file file_path
  end
end
