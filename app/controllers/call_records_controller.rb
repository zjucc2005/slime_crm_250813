# encoding: utf-8
class CallRecordsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def v_index; end
  def v_load_index
    begin
      page = Integer(params[:page]) rescue 1
      per_page = Integer(params[:per_page]) rescue 10
      query = CallRecord.all
      query = query.where('created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
      query = query.where('created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
      %w[category].each do |field|
        query = query.where(field.to_sym => params[field.to_sym]) if params[field.to_sym].present?
      end
      %w[name phone company].each do |field|
        query = query.where("#{field} ILIKE ?", "%#{params[field.to_sym].strip}%") if params[field.to_sym].present?
      end
      @call_records = query.order(id: :desc).paginate(page: page, per_page: per_page)
      render json: { 
        status: 0, 
        data: {
          call_records: @call_records.map(&:to_api),
          total: query.count, page: page, per_page: per_page
        }
      }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  # GET /call_records
  def index
    query = current_user.admin? ? CallRecord.all : CallRecord.where(operator_id: current_user.id)
    query = user_channel_filter(query)
    query = query.where(category: 'expert')
    query = query.where('created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    query = query.where('created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    %w[name phone company title].each do |field|
      query = query.where("#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
    end
    %w[status project_id candidate_id].each do |field|
      query = query.where(field.to_sym => params[field]) if params[field].present?
    end

    @call_records = query.order(:updated_at => :desc).paginate(:page => params[:page], :per_page => 100)
  end

  def index_doctor
    query = current_user.admin? ? CallRecord.all : CallRecord.where(operator_id: current_user.id)
    query = user_channel_filter(query)
    query = query.where(category: 'doctor')
    query = query.where('created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    query = query.where('created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    %w[name phone company title].each do |field|
      query = query.where("#{field} ILIKE ?", "%#{params[field].strip}%") if params[field].present?
    end
    %w[status project_id candidate_id].each do |field|
      query = query.where(field.to_sym => params[field]) if params[field].present?
    end

    @call_records = query.order(:updated_at => :desc).paginate(:page => params[:page], :per_page => 100)
  end

  # GET /call_records/:id
  # def show
  #   load_call_record
  # end

  # GET /call_records/new
  def new
    @project = Project.where(id: params[:project_id]).first
    @candidate = Candidate.where(id: params[:candidate_id]).first
    related_params = {}
    related_params.merge!(project_id: @project.id) if @project
    if @candidate
      related_params.merge!(candidate_id: @candidate.id, name: @candidate.name, phone: @candidate.phone)
      exp = @candidate.latest_work_experience
      related_params.merge!(company: exp.org_cn, title: exp.title) if exp
    end
    @call_record = CallRecord.new(related_params)
  end

  # POST /call_records
  def create
    @call_record = CallRecord.new(call_record_params.merge(created_by: current_user.id))
    if @call_record.save
      # 自动添加通话记录中专家到项目, 补齐关联关系
      if @call_record.candidate_id && @call_record.project_id
        @call_record.project.project_candidates.expert.find_or_create_by!(candidate_id: @call_record.candidate_id)
      end
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to call_records_path
    else
      render :new
    end
  end

  def remote_create_for_candidate
    begin
      @call_record = CallRecord.new(call_record_params.merge(created_by: current_user.id))
      if params[:call_record][:memo].present?
        @call_record.add_memo(params[:call_record][:memo])
      end
      @error = nil
      if @call_record.save
        # 自动添加通话记录中专家到项目, 补齐关联关系
        if @call_record.candidate_id && @call_record.project_id
          @call_record.project.project_candidates.expert.find_or_create_by!(candidate_id: @call_record.candidate_id)
        end
        @message = t(:operation_succeeded)
      else
        @error = @call_record.errors.full_messages.join(',')
      end
    rescue Exception => e
      @error = e.message
    end
    if params[:return_to].present?
      redirect_to params[:return_to]
    else
      respond_to { |f| f.js }
    end
  end

  # GET /call_records/:id/edit
  def edit
    load_call_record
  end

  # PUT /call_records/:id
  def update
    load_call_record

    if @call_record.update(call_record_params)
      flash[:success] = t(:operation_succeeded)
      redirect_to call_records_path
    else
      render :edit
    end
  end

  # DELETE /call_records/:id
  def destroy
    load_call_record

    if @call_record.destroy
      flash[:success] = t(:operation_succeeded)
    else
      flash[:error] = t(:operation_failed)
    end
    redirect_to call_records_path
  end

  # GET /call_records/:id/edit_operator
  def edit_operator
    load_call_record
  end

  # PUT /call_records/:id/update_operator
  def update_operator
    load_call_record

    if @call_record.update(call_record_params)
      flash[:success] = t(:operation_succeeded)
      redirect_to call_records_path
    else
      render :edit_operator
    end
  end

  # PUT /call_records/:id/after_call?status=pending
  def after_call
    load_call_record

    ActiveRecord::Base.transaction do
      @call_record.number_of_calls += 1
      if params[:status] == 'accept_and_add_to_candidate'
        @call_record.status = 'accepted'
      else
        @call_record.status = params[:status]
      end
      @call_record.save!

      project_candidate = @call_record.project_candidate
      project_candidate.update_mark_by_call_record_status(@call_record.status) if project_candidate  # 同步更新项目内专家标识
    end

    if params[:status] == 'accept_and_add_to_candidate'
      first_name, last_name = Candidate.name_split(@call_record.name.strip)
      phone = @call_record.phone.strip
      redirect_to new_candidate_path(first_name: first_name, last_name: last_name, phone: phone)
    else
      flash[:success] = t(:operation_succeeded)
      redirect_to call_records_path
    end
  end

  # GET /call_records/:id/add_to_candidate
  def add_to_candidate
    load_call_record
    first_name, last_name = Candidate.name_split(@call_record.name.strip)
    phone = @call_record.phone.strip
    redirect_to new_candidate_path(first_name: first_name, last_name: last_name, phone: phone)
  end

  # POST /call_records/batch_import
  def batch_import
    @errors = []
    if request.post?
      begin
        sheet = open_spreadsheet(params[:file])
        raise 'excel表格里没有信息' if sheet.last_row < 2
        raise 'excel不能超过1000行' if sheet.last_row > 1000
        2.upto(sheet.last_row) do |i|
          parser = Utils::CallRecordTemplateParser.new(sheet.row(i), current_user.id)
          @errors << "Row #{i}: #{parser.errors.join(', ')}" unless parser.import
        end
      rescue Exception => e
        @errors << e.message
      end

      if @errors.blank?
        flash[:success] = t(:operation_succeeded)
        redirect_to call_records_path
      else
        render :batch_import
      end
    end
  end

  def remote_index
    @project = Project.find(params[:project_id])
    @call_records = @project.call_records.order(id: :desc)
    respond_to { |f| f.js }
  end

  def remote_create
    begin
      @project = Project.find(params[:project_id])
      @call_record = @project.call_records.new(call_record_params.merge(created_by: current_user.id))
      @call_record.save!
      @call_records = @project.call_records.order(id: :desc)
    rescue => e
      @error = "ERROR: #{e.message}"
    end
    respond_to { |f| f.js }
  end

  def remote_update
    begin
      @call_record = CallRecord.find(params[:id])
      operate_params = { number_of_calls: @call_record.number_of_calls + 1, operator_id: current_user.id } # 记录操作信息
      @call_record.update!(call_record_params.merge(operate_params))
      @project = @call_record.project
      @call_records = @project.call_records.order(id: :desc)
    rescue => e
      @error = "ERROR: #{e.message}"
    end
    respond_to { |f| f.js }
  end

  # 异步更新页面, 只接收提交数据, 不刷新页面
  def remote_update_silent
    begin
      @call_record = CallRecord.find(params[:id])
      operate_params = { operator_id: current_user.id } # 记录操作信息
      @call_record.update!(call_record_params.merge(operate_params))
      render json: { status: 0 }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def remote_delete
    begin
      @call_record = CallRecord.find(params[:id])
      @call_record.destroy!
      @project = @call_record.project
      @call_records = @project.call_records.order(id: :desc)
    rescue => e
      @error = "ERROR: #{e.message}"
    end
    respond_to { |f| f.js }
  end

  def remote_import
    begin
      @project = Project.find(params[:project_id])
      sheet = open_spreadsheet(params[:file])
      raise 'excel表格里没有信息' if sheet.last_row < 2
      raise 'excel不能超过100行' if sheet.last_row > 100
      2.upto(sheet.last_row) do |i|
        parser = Utils::CallRecordTemplateParser.new(sheet.row(i), current_user.id, @project.id)
        unless parser.import
          raise "Row #{i}: #{parser.errors.join(', ')}"
        end
      end
      @call_records = @project.call_records
    rescue => e
      @error = "ERROR: #{e.message}"
    end
    respond_to { |f| f.js }
  end

  # remote: true
  def two_way_call
    begin
      caller_number = current_user.phone&.strip
      callee_number = params[:callee_number]&.strip
      raise '主叫号码不能为空' if caller_number.blank?
      raise '被叫号码不能为空' if callee_number.blank?
      res = Utils::Winnerlook.two_way_call(caller_number, callee_number)
      @msg = res['message']
    rescue => e
      @msg = e.message
    end
    respond_to { |f| f.js }
  end

  # == Vue actions begin ==
  def v_create
    begin
      attrs = v_call_record_params
      attrs[:created_by] = current_user.id
      if params[:project_requirement_id].present?
        @project_requirement = ProjectRequirement.find(params[:project_requirement_id])
        attrs[:project_id] = @project_requirement.project_id
        attrs[:project_requirement_id] = @project_requirement.id
      end
      @call_record = CallRecord.new(attrs)
      if params[:memo].present?
        @call_record.add_memo(params[:memo])
      end
      @call_record.save!
      render json: { status: 0, data: { call_record:  @call_record.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_create_batch
    begin
      if params[:project_requirement_id].present?
        @project_requirement = ProjectRequirement.find(params[:project_requirement_id])
      end
      @call_records = []
      ActiveRecord::Base.transaction do
        params[:call_records].each do |k, item|
          call_record = CallRecord.new(
            created_by: current_user.id,
            project_id: @project_requirement&.project_id,
            project_requirement_id: @project_requirement&.id,
            category: item[:category], name: item[:name], nickname: item[:nickname], gender: item[:gender],
            phone: item[:phone], email: item[:email], city: item[:city],
            company: item[:company], department: item[:department], title: item[:title], title1: item[:title1],
            academic_field: item[:academic_field], remark: item[:remark]
          )
          if item[:memo].present?
            call_record.add_memo(item[:memo])
          end
          call_record.save!
          @call_records << call_record
        end
      end
      render json: { status: 0, data: { call_records:  @call_records.map(&:to_api) } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_update
    begin
      @call_record = CallRecord.find(params[:id])
      @call_record.update!(v_call_record_params)
      
      # 处理memo_logs参数（用于删除操作）和memo参数（用于新增操作）
      if params[:memo_logs].present? && !params[:memo_logs].empty?
        # 处理不同类型的memo_logs参数（删除操作）
        memo_logs_data = case params[:memo_logs]
                        when String
                          JSON.parse(params[:memo_logs])
                        when Array
                          params[:memo_logs]
                        when ActionController::Parameters
                          # 将Hash格式转换为Array格式
                          hash_data = params[:memo_logs].to_unsafe_h
                          hash_data.values
                        else
                          params[:memo_logs]
                        end
        
        # 更新memo_logs字段
        @call_record.memo_logs = memo_logs_data
        # 重新计算memo字段
        if @call_record.memo_logs.present? && !@call_record.memo_logs.empty?
          @call_record.memo = @call_record.memo_logs.map{|log| log[1]}.join('; ')
        else
          @call_record.memo = ''
        end
        
        # 如果同时有新的memo需要添加，使用add_memo方法
        if params[:memo].present?
          @call_record.add_memo(params[:memo])
        end
        
        @call_record.save!
      elsif params[:memo].present?
        # 只有新增memo的情况
        @call_record.add_memo(params[:memo])
        @call_record.save!
      end
      
      if @call_record.rec_status == 'ok'
        @project = Project.find(@call_record.project_id)
        @project.project_candidates.expert.find_or_create_by!(candidate_id: @call_record.candidate_id) # 把专家加入项目中
      end
      render json: { status: 0, data: { call_record:  @call_record.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_match_candidates
    begin
      @call_record = CallRecord.find(params[:id])
      @candidates = @call_record.match_candidates
      render json: { status: 0, data: { candidates: @candidates.map(&:to_api_match) } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_ruku
    begin
      @call_record = CallRecord.find(params[:call_record_id])
      ActiveRecord::Base.transaction do
        if params[:candidate_id].present?
          # 更新专家
          @candidate = Candidate.find_by(id: params[:candidate_id])
          raise "未找到专家信息, candidate not found, id: #{params[:candidate_id]}" if @candidate.nil?
          @candidate.update!(params.permit(:last_name, :first_name, :phone, :description))
          @exp = @candidate.work_experiences.first
          if @candidate.category == 'doctor'
            org = Hospital.where(id: params[:hospital_id]).first
            dep = HospitalDepartment.where(id: params[:hospital_department_id]).first
            @candidate.update!(city: "#{org.province} #{org.city}")
            @exp.update!(
              org_id: org.id, dep_id: dep.id,
              org_cn: org.name, org_en: org.level, department: dep.name, title: params[:title]
            )
          else
            @exp.update!(org_cn: params[:company], department: params[:department], title: params[:title])
          end
        else
          # 新增专家
          @candidate = Candidate.new(
            created_by: current_user.id,
            user_channel_id: current_user.user_channel_id,
            category: params[:category],
            last_name: params[:last_name],
            first_name: params[:first_name],
            phone: params[:phone],
            description: params[:description],
            cpt: 0, currency: 'RMB', data_source: 'manual'
          )
          @candidate.save!
          if @candidate.category == 'doctor'
            org = Hospital.where(id: params[:hospital_id]).first
            dep = HospitalDepartment.where(id: params[:hospital_department_id]).first
            @candidate.update!(city: "#{org.province} #{org.city}")
            @candidate.experiences.hospital.create!(
              org_id: org.id, dep_id: dep.id,
              org_cn: org.name, org_en: org.level, department: dep.name, title: params[:title]
            )
          else
            @exp = @candidate.experiences.work.create!(org_cn: params[:company], department: params[:department], title: params[:title])
          end
        end
        @call_record.update!(candidate_id: @candidate.id)
      end
      render json: { status: 0, data: { call_record: @call_record.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_tuijian
    begin
      @call_record = CallRecord.find(params[:id])
      @call_record.update!(rec_status: 'recommended', rec_description: params[:rec_description], memo: params[:memo])
      render json: { status: 0, data: { call_record: @call_record.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  # == Vue actions end ==

  private
  def call_record_params
    params.require(:call_record).permit(:name, :phone, :company, :department, :title, :status, :project_id,
                                        :project_requirement_id, :candidate_id, :operator_id, :category)
  end

  def v_call_record_params
    params.permit(:category, :name, :nickname, :gender, :phone, :email, :city, :company, :department,
                  :title, :title1, :academic_field, :remark, :status, :rec_status, :memo_logs)
  end

  def load_call_record
    @call_record = CallRecord.find(params[:id])
    raise t(:not_authorized) unless @call_record.can_be_edited_by(current_user)
  end

end