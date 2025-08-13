# encoding: utf-8
class CandidatesController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /candidates
  def index
    set_per_page
    @hl_words = [] # 高亮关键词
    query = user_channel_filter(Candidate.expert)
    # query code here >>
    query = query.where('candidates.name ~* :name OR candidates.nickname ~* :name', { :name => params[:name].strip }) if params[:name].present?
    query = query.where('candidates.phone ~* :phone OR candidates.phone1 ~* :phone', { :phone => params[:phone].strip.shellescape }) if params[:phone].present?
    query = query.where('candidates.email ~* :email OR candidates.email1 ~* :email', { :email => params[:email].strip.shellescape }) if params[:email].present?
    query = query.where('candidates.industry' => params[:industry].strip) if params[:industry].present?
    query = query.where('candidates.is_available' => params[:is_available] == 'nil' ? nil : params[:is_available] ) if params[:is_available].present?
    %w[id recommender_id data_channel user_channel_id].each do |field|
      query = query.where(field.to_sym => params[field].strip) if params[field].present?
    end

    # 专家说明
    if params[:description].present?
      @terms = params[:description].split
      if @terms.length > 5
        flash[:error] = t(:keywords_at_most, :limit => 5)
        redirect_to candidates_path and return
      end
      and_conditions = []
      # or_fields = %w[candidates.description candidate_experiences.org_cn candidate_experiences.org_en candidate_experiences.title candidate_experiences.description]
      or_fields = %w[candidates.description candidate_experiences.org_cn candidate_experiences.org_en candidate_experiences.title candidate_comments.content]
      @terms.uniq.each do |term|
        sa = SearchAlias.where('kwlist @> ?', term.to_json).first
        if sa
          term_plus = sa.kwlist.join('|')
          @hl_words += sa.kwlist
        else
          term_plus = term
          @hl_words << term
        end
        # and_conditions << "(#{or_fields.map{|field| "#{field} ~* '#{term}'" }.join(' OR ')})"
        and_conditions << "(#{or_fields.map{|f| "coalesce(#{f},'')" }.join(' || ')} ~* '#{term_plus}')"
      end
      @hl_words.uniq!
      # 是否只搜索当前公司, 默认规则 true
      if params[:current_company] == 'false'
        query = query.joins('LEFT JOIN candidate_experiences on candidates.id = candidate_experiences.candidate_id')
      else
        query = query.joins('LEFT JOIN candidate_experiences on candidates.id = candidate_experiences.candidate_id AND candidate_experiences.ended_at IS NULL')
      end
      query = query.joins('LEFT JOIN candidate_comments ON candidates.id = candidate_comments.candidate_id')  # 加入搜索备注
      @logical_operator = params[:logical_operator] == 'OR' ? 'OR' : 'AND'
      query = query.where(and_conditions.join(" #{@logical_operator} "))
      query = query.distinct  # 去重
    end
    @candidates = query.order(coef: :desc, id: :desc).paginate(page: params[:page], per_page: @per_page)
  end

  def yibao
    query = Candidate.where(category: %w[expert doctor], is_yibao: true)
    query = user_channel_filter(query)
    
    # 姓名筛选
    if params[:name].present?
      query = query.where('candidates.name ~* ?', params[:name])
    end
    
    # 机构筛选
    if params[:institution].present?
      query = query.joins('LEFT JOIN candidate_experiences ON candidates.id = candidate_experiences.candidate_id')
                  .where('candidate_experiences.org_cn ~* ?', params[:institution])
                  .distinct
    end
    
    # 费用范围筛选
    if params[:min_fee].present?
      query = query.where('candidates.cpt >= ?', params[:min_fee])
    end
    if params[:max_fee].present?
      query = query.where('candidates.cpt <= ?', params[:max_fee])
    end
    
    # 访谈意愿筛选
    if params[:is_available].present?
      query = query.where(is_available: params[:is_available] == 'true')
    end
    
    # 临床/非临床筛选
    if params[:is_clinical].present?
      is_clinical = params[:is_clinical] == 'true'
      query = query.joins(:medical_insurance_infos)
                  .where(medical_insurance_infos: { is_clinical: is_clinical })
                  .distinct
      
      # 非临床类型筛选
      if params[:non_clinical_type].present? && !is_clinical
        query = query.where(medical_insurance_infos: { non_clinical_type: params[:non_clinical_type] })
      end
      
      # 非临床子类型筛选
      if params[:sub_type].present? && !is_clinical
        query = query.where(medical_insurance_infos: { sub_type: params[:sub_type] })
      end
    end
    
    # 年份范围筛选
    if params[:start_year].present? && params[:end_year].present?
      start_year = params[:start_year].to_i
      end_year = params[:end_year].to_i
      
      # 确保开始年份小于等于结束年份
      if start_year > end_year
        temp = start_year
        start_year = end_year
        end_year = temp
      end
      
      query = query.joins(:medical_insurance_infos)
                 .where('medical_insurance_infos.year >= ? AND medical_insurance_infos.year <= ?', start_year, end_year)
                 .distinct
    end
    
    @candidates = query.order(id: :desc).paginate(page: params[:page], per_page: 20)
  end

  # GET /candidates/:id
  def show
    begin
      load_candidate
      @call_records = @candidate.call_records.order(id: :desc).limit(6)
      @candidate_comments = @candidate.comments.order(id: :desc).limit(6)
      session_cache_show_history
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # GET /candidates/new
  def new
    @candidate = Candidate.new(
      last_name: params[:last_name],
      first_name: params[:first_name],
      phone: params[:phone],
      recommender_id: params[:recommender_id]
    )
  end

  # POST /candidates
  def create
    begin
      @candidate = Candidate.new(candidate_params.merge(created_by: current_user.id, user_channel_id: current_user.user_channel_id))

      if @candidate.valid?
        ActiveRecord::Base.transaction do
          @candidate.save!
          (params[:work_exp] || {}).each do |key, val|
            %w[started_at ended_at].each do |field|
              if val[field].to_s.match(/^\d{4}-(0?[1-9]|1[0-2])$/)
                val[field] = "#{val[field]}-01"
              end
            end
            @candidate.experiences.work.create!(val.permit(experience_fields))
          end
          unless @candidate.validates_presence_of_experiences
            raise t(:operation_failed)
          end
        end

        flash[:success] = t(:operation_succeeded)
        if params[:commit] == t('action.submit_and_call')
          redirect_to new_call_record_candidate_path(@candidate)
        else
          redirect_to candidate_path(@candidate)
        end
      else
        flash.now[:error] = t(:operation_failed)
        render :new
      end
    rescue Exception => e
      flash.now[:error] = e.message
      render :new
    end
  end

  # GET /candidates/:id/edit
  def edit
    begin
      load_candidate
      Rails.logger.info "==== Candidate edit action for ID: #{@candidate.id} ===="
      Rails.logger.info "Candidate attributes: #{@candidate.attributes.inspect}"
      Rails.logger.info "Medical insurance info count: #{@candidate.medical_insurance_infos.count}"
      if @candidate.medical_insurance_infos.any?
        Rails.logger.info "Medical insurance info details:"
        @candidate.medical_insurance_infos.each do |mi|
          Rails.logger.info "  ID: #{mi.id}, Year: #{mi.year}, Clinical: #{mi.is_clinical}, Type: #{mi.non_clinical_type}, Subtype: #{mi.sub_type}"
        end
      else
        Rails.logger.info "No medical insurance info records found"
      end
    rescue Exception => e
      Rails.logger.error "=== Error in edit action: #{e.message} ==="
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # PUT /candidates/:id
  def update
    begin
      load_candidate
      Rails.logger.info "==== Candidate update action for ID: #{@candidate.id} ===="
      Rails.logger.info "Medical insurance params: #{params[:candidate][:medical_insurance_infos_attributes].inspect}" if params[:candidate][:medical_insurance_infos_attributes]

      ActiveRecord::Base.transaction do
        _work_exp = params[:_work_exp] || {}  # old work_exp
        work_exp  = params[:work_exp]  || {}  # new work_exp
        @candidate.experiences.work.where.not(id: _work_exp.keys).destroy_all  # update existed experiences
        @candidate.experiences.work.where(id: _work_exp.keys).each do |exp|
          %w[started_at ended_at].each do |field|
            if _work_exp[exp.id.to_s][field].to_s.match(/^\d{4}-(0?[1-9]|1[0-2])$/)
              _work_exp[exp.id.to_s][field] = "#{_work_exp[exp.id.to_s][field]}-01"
            end
          end
          exp.update!(_work_exp[exp.id.to_s].permit(experience_fields))
        end
        work_exp.each do |key, val|
          @candidate.experiences.work.create!(val.permit(experience_fields))   # create new experiences
        end
        @candidate.update!(candidate_params)                                   # update candidate
        unless @candidate.validates_presence_of_experiences
          raise t(:operation_failed)
        end
      end

      flash[:success] = t(:operation_succeeded)
      redirect_to candidate_path(@candidate)
    rescue Exception => e
      flash[:error] = e.message
      render :edit
    end
  end

  # PUT /candidates/:id/update_is_available.js, remote: true
  def update_is_available
    load_candidate
    @candidate.update(is_available: params[:is_available])
    respond_to{ |f| f.js }
  end

  # DELETE /candidates/:id
  def destroy
    begin
      load_candidate

      raise t(:cannot_delete) unless @candidate.can_delete?
      @candidate.destroy!
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to(candidates_path)
    rescue Exception => e
      logger.info "delete candidate failed: #{e.message}"
      flash[:error] = e.message
      redirect_with_return_to(candidates_path)
    end
  end

  # GET /candidates/add_experience
  def add_experience
    @seq = "#{Time.now.to_i}#{sprintf('%02d', rand(100))}"
    respond_to { |f| f.js }
  end

  # GET /candidates/:id/show_phone.js, remote: true
  def show_phone
    begin
      load_candidate
      @response = { status: 'succ' }
    rescue Exception => e
      @response = { status: 'fail', reason: e.message }
    end
    respond_to{|f| f.js }
  end

  # GET /candidates/gen_card
  def gen_card
    @card_template = CardTemplate.find(params[:card_template_id])
    @candidates = Candidate.where(id: params[:uids])
  end

  # GET /candidates/expert_template
  def expert_template
    if params[:project_id].present?
      @candidates = Candidate.joins(:project_candidates).
        where('candidates.id': params[:uids], 'project_candidates.project_id': params[:project_id]).
        order('project_candidates.created_at': :asc)
    else
      @candidates = Candidate.where(id: params[:uids]).order(id: :desc)
    end
    case params[:template]
    when 'expert' then export_expert_template(@candidates)
    when 'doctor' then export_doctor_template(@candidates)
    when 'classify' then export_classify_template(@candidates)
    else raise 'params error'
    end
  end

  # POST /candidates/import_expert
  def import_expert
    @errors = []
    if request.post?
      begin
        sheet = open_spreadsheet(params[:file])
        raise 'excel表格里没有信息' if sheet.last_row < 2
        raise 'excel不能超过10000行' if sheet.last_row > 10000
        2.upto(sheet.last_row) do |i|
          parser = Utils::ExpertTemplateParser.new(sheet.row(i), current_user.id, current_user.user_channel_id)
          @errors << "Row #{i}: #{parser.errors.join(', ')}" unless parser.import
        end
      rescue Exception => e
        @errors << e.message
      end

      if @errors.blank?
        flash[:success] = t(:operation_succeeded)
        redirect_to candidates_path
      else
        render :import_expert
      end
    end
  end

  # GET /candidates/:id/payment_infos
  def payment_infos
    begin
      load_candidate
      @payment_infos = @candidate.payment_infos
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # GET /candidates/:id/new_payment_info
  def new_payment_info
    begin
      load_candidate
      @payment_info = @candidate.payment_infos.new
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # POST /candidates/:id/create_payment_info
  def create_payment_info
    begin
      load_candidate

      @payment_info = @candidate.payment_infos.new(candidate_payment_info_params.merge({created_by: current_user.id}))
      if @payment_info.save
        flash[:success] = t(:operation_succeeded)
        redirect_with_return_to candidate_path(@candidate)
      else
        render :new_payment_info
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  # GET /candidates/:id/project_tasks
  def project_tasks
    begin
      load_candidate
      query = @candidate.project_tasks.where(status: %w[ongoing finished])
      query = user_channel_filter(query)
      @project_tasks = query.order(:started_at => :desc).paginate(:page => params[:page], :per_page => 20)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  def call_records
    begin
      load_candidate
      @call_records = @candidate.call_records.order(id: :desc)
      @candidate_comments = @candidate.comments.order(is_top: :desc, created_at: :desc)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # GET /candidates/:id/comments
  def comments
    begin
      load_candidate
      @candidate_comments = @candidate.comments.joins(:creator).where('users.user_channel_id': current_user.user_channel_id).
        order(:is_top => :desc, :created_at => :desc).paginate(:page => params[:page], :per_page => 20)
    rescue Exception => e
      flash[:error] = e.message
      redirect_to candidates_path
    end
  end

  # GET /candidates/:id/new_comment
  def new_comment
    @candidate_comment = CandidateComment.new
  end

  # GET /candidates/:id/expert_info_for_clipboard
  def expert_info_for_clipboard
    @candidate = Candidate.find(params[:id])
    render :json => { :data => "#{@candidate.name}|#{@candidate.phone}" }
  end

  # GET /candidates/recommender_info?recommender_id=1
  def recommender_info
    begin
      @recommender = Candidate.expert.where(id: params[:recommender_id]).first
      raise "expert not found with id #{params[:id]}" if @recommender.nil?
      render :json => { status: '0', name: @recommender.name }
    rescue Exception => e
      render :json => { status: '1', reason: e.message }
    end
  end

  # GET /candidates/loading_modal?category=newCallRecord&reference_id=1
  def loading_modal
    @category = params[:category]
    if @category == 'newCallRecord'
      @candidate = Candidate.find(params[:reference_id])
      exp = @candidate.latest_work_experience
      @call_record = CallRecord.new(
        candidate_id: @candidate.id, 
        name: @candidate.name, 
        phone: @candidate.phone, 
        company: exp.try(:org_cn), 
        department: exp.try(:department), 
        title: exp.try(:title), 
        category: @candidate.category
      )
      # 查询操作员最近的通话记录
      @latest_cr = CallRecord.where(operator_id: current_user.id).order(id: :desc).first
      if @latest_cr
        @call_record.project_id = @latest_cr.project_id
        @call_record.project_requirement_id = @latest_cr.project_requirement_id
      end

      @remote = params[:return_to].blank?
      @return_to = params[:return_to] || (@candidate.category == 'doctor' ? doctors_path : candidates_path)
      @modal_title = t('action.new_model', :model => t('activerecord.models.call_record'))
      @modal_body_form = 'candidates/loading_modal/new_call_record_form'
    end

    respond_to { |f| f.js }
  end

  # POST /candidates/batch_update_file
  def batch_update_file
    @files = params[:file]
    @files.each do |file|
      filename  = file.original_filename
      extname   = File.extname(filename)
      basename  = filename.split(extname)[0]
      candidate = Candidate.where(id: basename).first
      candidate.update!(file: file) if candidate
    end
    flash[:success] = t(:operation_succeeded)
    redirect_to candidates_path
  end

  def new_call_record
    @candidate = Candidate.find(params[:id])
    exp = @candidate.latest_work_experience
    @call_record = CallRecord.new(candidate_id: @candidate.id, name: @candidate.name, phone: @candidate.phone, company: exp.try(:org_cn), title: exp.try(:title), category: @candidate.category)
    @return_to = @candidate.category == 'doctor' ? doctors_path : candidates_path
  end

  # remote
  def load_work_experiences_for_project_task
    @candidate = Candidate.find(params[:id])
    @work_experiences_options = '<option value>Please select</option>'
    @work_experiences_options += @candidate.work_experiences.map { |exp| "<option value=\"#{exp.id}\">#{exp.org_cn}</option>" }.join
    respond_to { |f| f.js }
  end

  def v_index_data
    begin
      page = Integer(params[:page]) rescue 1
      per_page = Integer(params[:per_page]) rescue 10
      query = user_channel_filter(Candidate.expert)
      @candidates = query.order(coef: :desc, id: :desc).paginate(page: page, per_page: per_page)
      render json: {
        status: 0,
        data: {
          candidates: @candidates.map(&:to_api_expert),
          total: query.count, page: page, per_page: per_page
        }
      }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  private
  def load_candidate
    @candidate = Candidate.find(params[:id])
    Rails.logger.info "=== Loading candidate ID: #{params[:id]} ==="
    current_user.access_candidate(@candidate)  # 访问次数统计/访问权限
    Rails.logger.info "=== Successfully loaded candidate and accessed with current user ==="
  end

  def load_client
    @client = Candidate.find(params[:id])
  end

  def candidate_params
    params.require(:candidate).permit(
      :category, :data_source, :last_name, :first_name, :nickname, :gender, :date_of_birth, :phone, :phone1,
      :city, :industry, :email, :email1, :wechat, :recommender_id, :data_channel, :haodf_id, :file, :sign_file,
      :is_available, :cpt, :cpt_taxed, :currency, :cpt_face_to_face, :description, :job_status, :is_kol, :expertise,
      :is_yibao,
      medical_insurance_infos_attributes: [
        :id, :year, :is_clinical, :non_clinical_type, :sub_type, :_destroy
      ])
  end

  def experience_fields
    [:started_at, :ended_at, :org_cn, :org_en, :title, :description]
  end

  def candidate_payment_info_params
    params.require(:candidate_payment_info).permit(:category, :bank, :sub_branch, :account, :username, :id_number)
  end

  def export_expert_template(query)
    template_path = 'public/templates/expert_template_20200518.xlsx'
    raise 'template file not found' unless File.exist?(template_path)

    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[0]
    query.each_with_index do |expert, index|
      row = index + 3
      exp = expert.latest_work_experience
      sheet.add_cell(row, 1, "##{expert.uid}")    # Expert Code
      sheet.add_cell(row, 2, exp.try(:org_cn))    # Company
      sheet.add_cell(row, 3, exp.try(:title))     # Position
      sheet.add_cell(row, 4, expert.city)         # Region
      sheet.add_cell(row, 5, expert.description)  # Key Insights
    end
    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/expert_#{current_user.id}_#{Time.now.strftime('%H%M%S')}.xlsx"
    book.write file_path
    send_file file_path
  end

  def export_doctor_template(query)
    template_path = 'public/templates/expert_template_20211205.xlsx'
    raise 'template file not found' unless File.exist?(template_path)

    book = ::RubyXL::Parser.parse(template_path)  # read from template file
    sheet = book[0]
    query.each_with_index do |expert, index|
      row = index + 1
      exp = expert.latest_work_experience
      sheet.add_cell(row, 0, "##{expert.uid}")    # ID
      sheet.add_cell(row, 1, expert.mr_name)      # B, 姓名
      sheet.add_cell(row, 2, exp.try(:org_cn))    # C, 公司
      sheet.add_cell(row, 3, exp.try(:title))     # D, 职位
      sheet.add_cell(row, 4, expert.description)  # E, 简介
      sheet.add_cell(row, 5, '')                  # F, 专家Comment
      sheet.add_cell(row, 6, "#{expert._gj_rate_}/小时")  # G, 价格
      sheet.add_cell(row, 7, '')                  # H, 方便时间
      sheet.add_cell(row, 8, '')                  # I, 是否与BDA合作过以及合作时间
      sheet.add_cell(row, 9, '')                  # J, 专家身份验证
    end
    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/doctor_#{current_user.id}_#{Time.now.strftime('%H%M%S')}.xlsx"
    book.write file_path
    send_file file_path
  end

  def export_classify_template(query)
    template_path = 'public/templates/expert_template_20230516.xlsx'
    raise 'template file not found' unless File.exist?(template_path)
    book = ::RubyXL::Parser.parse(template_path)
    sheet0 = book[0]
    query.expert.each_with_index do |expert, index|
      row = index + 3
      exp = expert.latest_work_experience
      sheet0.add_cell(row, 0, "##{expert.uid}")
      sheet0.add_cell(row, 1, exp.try(:org_cn))
      sheet0.add_cell(row, 2, exp.try(:title))
      sheet0.add_cell(row, 3, expert.description)
    end
    sheet1 = book[1]
    query.doctor.each_with_index do |doctor, index|
      row = index + 3
      exp = doctor.latest_work_experience
      sheet1.add_cell(row, 1, "##{doctor.uid}")
      sheet1.add_cell(row, 2, exp.org_cn)
      sheet1.add_cell(row, 3, [exp.department, exp.title, exp.title1].join(' '))
      sheet1.add_cell(row, 5, doctor.expertise)
    end
    file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p file_dir unless File.exist? file_dir
    file_path = "#{file_dir}/classify_#{current_user.id}_#{Time.now.strftime('%H%M%S')}.xlsx"
    book.write file_path
    send_file file_path
  end

  def session_cache_show_history
    begin
      fifo = Utils::Fifo.new(session[:cache_show_history], len: 10, dup: false)
      exp = @candidate.latest_work_experience
      if exp
        text = "##{@candidate.uid} #{@candidate.name}, #{exp.org_cn}, #{exp.title}"  # include work experience info
      else
        text = "##{@candidate.uid} #{@candidate.name}"  # base info
      end
      fifo.push([@candidate.id, text])
      session[:cache_show_history] = fifo.to_a
    rescue
      session[:cache_show_history] = nil
    end
  end
end