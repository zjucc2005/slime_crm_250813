# encoding: utf-8
class DoctorsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /doctors
  def index
    set_per_page
    @hl_words = [] # 高亮关键词
    query = user_channel_filter(Candidate.doctor)
    # query code here >>
    # query = query.joins(:experiences).where('candidate_experiences.category': 'hospital')
    query = query.where('candidates.name ~* :name OR candidates.nickname ~* :name', { name: params[:name].strip }) if params[:name].present?
    query = query.where('candidates.phone ILIKE ?', "%#{params[:phone].strip}%") if params[:phone].present?
    query = query.where('candidates.email ILIKE ?', "%#{params[:email].strip}%") if params[:email].present?
    query = query.where('candidates.is_available' => params[:is_available] == 'nil' ? nil : params[:is_available] ) if params[:is_available].present?
    %w[id user_channel_id category2].each do |field|
      query = query.where(field.to_sym => params[field].strip) if params[field].present?
    end
    if params[:yibaotanpan_year].present?
      query = query.where("property->'yibaotanpan_year' @> ?", [params[:yibaotanpan_year]].to_json)
    end
    # -- 省份/城市 --
    if params[:city_level].present?
      query = query.joins(:experiences).where('candidates.city ~* ?', LocationDatum::CITY_TIER[params[:city_level]].join('|'))
    elsif params[:ld_province_id].present?
      @province = LocationDatum.where(id: params[:ld_province_id]).first
      if @province && params[:ld_city_id].present?
        @city = @province.direct_children.where(id: params[:ld_city_id]).first
      end
    elsif params[:ld_city_id].present?
      @city = LocationDatum.where(id: params[:ld_city_id]).first
    end
    if @province && @city
      query = query.joins(:experiences).where('candidates.city': "#{@province.name} #{@city.name}")
    elsif @province
      query = query.joins(:experiences).where('candidates.city ILIKE ?', "#{@province.name} %")
    elsif @city
      query = query.joins(:experiences).where('candidates.city ILIKE ?', "% #{@city.name}")
    end
    # -- 医院/科室 --
    query = query.joins(:experiences).where('candidate_experiences.org_id': params[:hospital_id]) if params[:hospital_id].present?
    query = query.joins(:experiences).where('candidate_experiences.dep_id': params[:hospital_department_id]) if params[:hospital_department_id].present?
    query = query.joins(:experiences).where('candidate_experiences.title ILIKE ?', "%#{params[:title].strip}%") if params[:title].present?
    if params[:hospital_level].present?
      hospital_level = case params[:hospital_level].strip
              when '三级' then %w[三级 三甲 三乙 三丙]
              when '二级' then %w[二级 二甲 二乙 二丙]
              when '一级' then %w[一级 一甲 一乙 一丙]
              else params[:hospital_level].strip
              end
      query = query.joins(:experiences).joins('LEFT JOIN hospitals on hospitals.id = candidate_experiences.org_id').where('hospitals.level': hospital_level)
    end

    if params[:name_or].present?
      name_arr = params[:name_or].split
      query = query.where('name ~* ?', "^(#{name_arr.join('|')})$")
    end

    if params[:description].present?
      @terms = params[:description].split
      if @terms.length > 5
        flash[:error] = t(:keywords_at_most, limit: 5)
        redirect_to doctors_path and return
      end

      and_conditions = []
      or_fields = %w[candidates.description candidates.expertise candidate_experiences.org_cn candidate_experiences.department candidate_experiences.title]
      @terms.uniq.each do |term|
        sa = SearchAlias.where('kwlist @> ?', term.to_json).first
        if sa
          term_plus = sa.kwlist.join('|')
          @hl_words += sa.kwlist
        else
          term_plus = term
          @hl_words << term
        end
        and_conditions << "(#{or_fields.map{|f| "coalesce(#{f},'')" }.join(' || ')} ~* '#{term_plus}')"
      end
      @hl_words.uniq!
      @logical_operator = params[:logical_operator] == 'OR' ? 'OR' : 'AND'
      query = query.joins(:experiences).where(and_conditions.join(" #{@logical_operator} "))
    end

    # 保留动态搜索条件
    if params[:ld_province_id].present?
      _province_ = LocationDatum.provinces.where(id: params[:ld_province_id]).first
      @current_province_options = [[_province_.name, _province_.id]] if _province_
    end
    if params[:hospital_id].present?
      _hospital_ = Hospital.where(id: params[:hospital_id]).first
      @current_hospital_options = [[_hospital_.name, _hospital_.id]] if _hospital_
    end
    @doctors = query.order(coef: :desc, id: :desc).paginate(page: params[:page], per_page: @per_page)
  end

  # GET /doctors/:id
  def show
    begin
      load_doctor
      @call_records = @doctor.call_records.order(id: :desc).limit(6)
      @candidate_comments = @doctor.comments.order(id: :desc).limit(6)
      # session_cache_show_history
    rescue Exception => e
      flash[:error] = e.message
      redirect_to doctors_path
    end
  end

  # GET /doctors/new
  def new
    @doctor = Candidate.doctor.new
    @exp = @doctor.experiences.hospital.new
  end

  # POST /doctors
  def create
    begin
      @doctor = Candidate.doctor.new(doctor_params.merge(created_by: current_user.id, user_channel_id: current_user.user_channel_id))
      if params[:candidate][:yibaotanpan_year].present?
        @doctor.yibaotanpan_year = params[:candidate][:yibaotanpan_year] - ['']
      end
      if @doctor.valid?
        ActiveRecord::Base.transaction do
          @doctor.save!
          org = Hospital.where(id: exp_params[:org_id]).first
          dep = HospitalDepartment.where(id: exp_params[:dep_id]).first
          @doctor.experiences.hospital.create!(exp_params.merge(org_cn: org.name, org_en: org.level, department: dep.name))
          unless @doctor.validates_presence_of_experiences
            raise t(:operation_failed)
          end
        end

        flash[:success] = t(:operation_succeeded)
        if params[:commit] == t('action.submit_and_call')
          redirect_to new_call_record_candidate_path(@doctor)
        else
          redirect_to doctor_path(@doctor)
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

  # GET /doctors/:id/edit
  def edit
    load_doctor
    @exp = @doctor.experiences.hospital.first || @doctor.experiences.hospital.new
    @current_hospital_options = [[@exp.org_cn, @exp.org_id]] if @exp
  end

  # PATCH /doctors/:id
  def update
    begin
      load_doctor
      @exp = @doctor.experiences.hospital.first

      ActiveRecord::Base.transaction do
        @doctor.update!(doctor_params)
        if params[:candidate][:yibaotanpan_year].present?
          @doctor.yibaotanpan_year = params[:candidate][:yibaotanpan_year] - ['']
          @doctor.save!
        end
        org = Hospital.where(id: exp_params[:org_id]).first
        dep = HospitalDepartment.where(id: exp_params[:dep_id]).first
        @exp ? @exp.update!(exp_params.merge(org_cn: org.name, org_en: org.level, department: dep.name)) :
            @doctor.experiences.hospital.create!(exp_params.merge(org_cn: org.name, org_en: org.level, department: dep.name))
        unless @doctor.validates_presence_of_experiences
          raise t(:operation_failed)
        end
      end

      flash[:success] = t(:operation_succeeded)
      redirect_to doctor_path(@doctor)
    rescue Exception => e
      flash[:error] = e.message
      @exp ||= @doctor.experiences.hospital.new
      @current_hospital_options = [[@exp.org_cn, @exp.org_id]] if @exp
      render :edit
    end
  end

  # DELETE /doctors/:id
  def destroy
    begin
      load_doctor
      raise t(:cannot_delete) unless @doctor.can_delete?
      @doctor.destroy!
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to(doctors_path)
    rescue Exception => e
      logger.info "delete doctor failed: #{e.message}"
      flash[:error] = e.message
      redirect_with_return_to(doctors_path)
    end
  end

  # POST /doctors/import_haodf
  def import_haodf
    @errors = []
    if request.post?
      begin
        sheet = open_spreadsheet(params[:file])
        raise 'excel表格里没有信息' if sheet.last_row < 2
        raise 'excel不能超过一百万行' if sheet.last_row > 1000000
        sheet_head = %w[id province hospital department name url title educate_title expertise inquiry level]
        raise '表头不一致, 请检查数据文件' if sheet.row(1) != sheet_head  # 检查表头

        2.upto(sheet.last_row) do |i|
          parser = Utils::HaodfTemplateParser.new(sheet.row(i), current_user.id, current_user.user_channel_id)
          @errors << "Row #{i}: #{parser.errors.join(', ')}" unless parser.import
        end
      rescue Exception => e
        @errors << e.message
      end

      if @errors.blank?
        flash[:success] = t(:operation_succeeded)
        redirect_to doctors_path
      else
        render :import_haodf
      end
    end
  end

  private
  def load_doctor
    @doctor = Candidate.find(params[:id])
    current_user.access_candidate(@doctor)  # 访问次数统计/访问权限
  end

  def doctor_params
    params.require(:candidate).permit(
      :last_name, :first_name, :nickname, :category2, :gender, :date_of_birth, :phone, :phone1, :email, :wechat,
      :file, :sign_file, :city, :is_available, :cpt, :cpt_taxed, :currency, :is_kol, :expertise, :description,
      :is_yibao,
      medical_insurance_infos_attributes: [
        :id, :year, :is_clinical, :non_clinical_type, :sub_type, :_destroy
      ]
    )
  end

  def exp_params
    params.require(:exp).permit(:org_id, :dep_id, :title, :title1)
  end

end