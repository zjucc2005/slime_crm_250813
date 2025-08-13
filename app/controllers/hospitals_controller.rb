# encoding: utf-8
class HospitalsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def index
    query = Hospital.all
    if params[:name].present?
      query = query.where("name ILIKE ? OR kwlist @> ?", "%#{params[:name].strip}%", params[:name].strip.to_json)
    end

    if params[:ld_province_id].present?
      @province = LocationDatum.where(id: params[:ld_province_id]).first
      if @province && params[:ld_city_id].present?
        @city = @province.direct_children.where(id: params[:ld_city_id]).first
      end
    end
    query = query.where(province: @province.name) if @province
    query = query.where(city: @city.name) if @city
    if params[:level].present?
      level = case params[:level].strip
                when '三级' then %w[三级 三甲 三乙 三丙]
                when '二级' then %w[二级 二甲 二乙 二丙]
                when '一级' then %w[一级 一甲 一乙 一丙]
                else params[:level].strip
              end
      query = query.where(level: level)
    end
    if params[:ld_province_id].present?
      _province_ = LocationDatum.provinces.where(id: params[:ld_province_id]).first
      @current_province_options = [[_province_.name, _province_.id]] if _province_
    end
    @hospitals = query.order(:created_at => :desc).paginate(:page => params[:page], :per_page => 50)
  end

  def show
    load_hospital

    @data = []
    @hospital.departments.each do |dep|
      count = Candidate.doctor.joins(:experiences).where('candidate_experiences.org_id': @hospital.id, 'candidate_experiences.dep_id': dep.id).count
      @data << { id: dep.id, name: dep.name, count: count }
    end
  end

  def new
    @hospital = Hospital.new
  end

  def create
    @hospital = Hospital.new(hospital_params)
    @province = LocationDatum.provinces.where(id: params[:ld_province_id]).first
    @city = @province.direct_children.where(id: params[:ld_city_id]).first
    @hospital.province = @province.name
    @hospital.city = @city.name
    if @hospital.save
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to(hospitals_path)
    else
      render :new
    end
  end

  def edit
    load_hospital
  end

  def update
    load_hospital

    if @hospital.update(hospital_params)
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to(hospitals_path)
    else
      render :edit
    end
  end

  def create_department
    load_hospital
    @department = @hospital.departments.new(name: params[:name].strip)
    if @department.save
      flash[:success] = t(:operation_succeeded)
      redirect_to hospital_path(@hospital)
    else
      flash[:error] = @department.errors.full_messages[0]
      redirect_to hospital_path(@hospital)
    end
  end

  def delete_department
    load_hospital
    @department = @hospital.departments.where(id: params[:hospital_department_id]).first
    if @department && @department.can_delete?
      @department.destroy!
      flash[:success] = t(:operation_succeeded)
      redirect_to hospital_path(@hospital)
    else
      flash[:error] = t(:not_authorized)
      redirect_to hospital_path(@hospital)
    end
  end

  # GET, format.json
  def load_departments
    load_hospital
    @data = []
    @hospital.departments.each do |dep|
      count = Candidate.doctor.joins(:experiences).where('candidate_experiences.org_id': @hospital.id, 'candidate_experiences.dep_id': dep.id).count
      @data << { id: dep.id, name: dep.name, count: count }
    end
    render :json => @data.to_json
  end

  # GET, js
  def change_hospital_for_doctor_form
    load_hospital
    @city = "#{@hospital.province} #{@hospital.city}"
    @department_options = '<option>Please select</option>' +
        @hospital.departments.map { |dep| "<option value=\"#{dep.id}\">#{dep.name}</option>" }.join
    respond_to { |f| f.js }
  end

  # def load_hospital_options
  #   @hospital_options = '<option value>Please select</option>'
  #   @hospital_options += Hospital.all.order(created_at: :asc).map { |hos| "<option value=\"#{hos.id}\">#{hos.name}</option>" }.join
  #   respond_to { |f| f.js }
  # end

  # GET, json
  def hospital_options
    query = Hospital.all
    query = query.where('name ILIKE ? OR kwlist @> ?', "%#{params[:name].strip}%", params[:name].strip.to_json) if params[:name].present?
    @data = query.order(id: :asc).limit(100).map { |item| { id: item.id, name: item.name } }
    render json: @data.to_json
  end

  # GET, js
  def load_children
    load_hospital
    @hospital_departments = @hospital.departments
    @hospital_department_options = '<option value>Please select</option>'
    @hospital_department_options += @hospital.departments.map { |dep| "<option value=\"#{dep.id}\">#{dep.name}</option>" }.join
    if params[:hospital_department_id].present? && @hospital.departments.exists?(id: params[:hospital_department_id])
      @hospital_department_id = params[:hospital_department_id]
    end
    respond_to { |f| f.js }
  end

  # == Vue actions begin ==
  def v_create_department
    begin
      @hospital = Hospital.find(params[:id])
      @department = @hospital.departments.new(name: params[:name].strip)
      @department.save!
      render json: { status: 0 }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  # == Vue actions end ==

  private
  def load_hospital
    @hospital = Hospital.find(params[:id])
  end

  def hospital_params
    params.require(:hospital).permit(:name, :category, :level, :kwlist)
  end

end