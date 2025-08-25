# encoding: utf-8
class ProjectRequirementsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /project_requirements
  def index
    query = ProjectRequirement.joins(:project)
    query = user_channel_filter(query, 'projects.user_channel_id')
    query = (current_user.admin? || current_user.finance? || current_user.pd?) ? query : query.where('project_requirements.operator_id': current_user.id)
    query = query.where('created_at >= ?', params[:created_at_ge]) if params[:created_at_ge].present?
    query = query.where('created_at <= ?', params[:created_at_le]) if params[:created_at_le].present?
    %w[status project_id operator_id].each do |field|
      query = query.where(field.to_sym => params[field]) if params[field].present?
    end
    @project_requirements = query.order(:updated_at => :desc).paginate(:page => params[:page], :per_page => 20)
  end

  # GET /project_requirements/:id
  def show
    load_project_requirement
  end

  # GET /project_requirements/new
  def new
    @project_requirement = ProjectRequirement.new
  end

  # POST /project_requirements
  def create
    @project_requirement = ProjectRequirement.new(project_requirement_params.merge(created_by: current_user.id))

    if @project_requirement.save
      flash[:success] = t(:operation_succeeded)
      redirect_to project_requirements_path
    else
      render :new
    end
  end

  # GET /project_requirements/:id/edit
  def edit
    load_project_requirement
  end

  # PUT /project_requirements/:id
  def update
    begin
      load_project_requirement

      raise t(:not_authorized) unless @project_requirement.can_edit?

      if @project_requirement.update(project_requirement_params)
        flash[:success] = t(:operation_succeeded)
        redirect_to project_path(@project_requirement.project)
      else
        render :edit
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  # PUT /project_requirements/:id/finish
  def finish
    begin
      load_project_requirement
      raise t(:not_authorized) unless @project_requirement.can_edit?
      @project_requirement.update!(status: 'finished')
      flash[:success] = t(:operation_succeeded)
    rescue Exception => e
      flash[:error] = e.message
    end
    redirect_to project_requirements_path
  end

  # PUT /project_requirements/:id/unfinish
  def unfinish
    begin
      load_project_requirement
      raise t(:not_authorized) unless @project_requirement.can_edit?
      @project_requirement.update!(status: 'unfinished')
      flash[:success] = t(:operation_succeeded)
    rescue Exception => e
      flash[:error] = e.message
    end
    redirect_to project_requirements_path
  end

  # PUT /project_requirements/:id/cancel
  def cancel
    begin
      load_project_requirement
      raise t(:not_authorized) unless @project_requirement.can_edit?
      @project_requirement.update!(status: 'cancelled')
      flash[:success] = t(:operation_succeeded)
    rescue Exception => e
      flash[:error] = e.message
    end
    redirect_to project_requirements_path
  end

  # GET /project_requirements/:id/edit_operator
  def edit_operator
    load_project_requirement
  end

  # PUT /project_requirements/:id/update_operator
  def update_operator
    begin
      load_project_requirement

      raise t(:not_authorized) unless @project_requirement.can_edit?
      if @project_requirement.update(project_requirement_params)
        flash[:success] = t(:operation_succeeded)
        redirect_to project_requirements_path
      else
        render :edit
      end
    rescue Exception => e
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  # == Vue actions begin ==
  def v_create
    begin
      @project_requirement = ProjectRequirement.new(v_project_requirement_params.merge(created_by: current_user.id))
      @project_requirement.save!
      render json: { status: 0, data: { project_requirement: @project_requirement.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_update
    begin
      @project_requirement = ProjectRequirement.find(params[:id])
      @project_requirement.update!(v_project_requirement_params)
      render json: { status: 0, data: { project_requirement: @project_requirement.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_show
    begin
      @project_requirement = ProjectRequirement.find_by(id: params[:id])
      raise "project_requirement not found with id #{params[:id]}" if @project_requirement.nil?
      render json: { status: 0, data: { project_requirement: @project_requirement.to_api_dashboard } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_update_demand_number
    begin
      raise "只有管理员可以修改需求人数" unless current_user.is_role?('admin')
      @project_requirement = ProjectRequirement.find_by(id: params[:id])
      raise "project_requirement not found with id #{params[:id]}" if @project_requirement.nil?
      
      demand_number = params[:demand_number].to_i
      raise "需求人数必须大于0" if demand_number < 1
      
      @project_requirement.update!(demand_number: demand_number)
      render json: { status: 0, msg: '需求人数更新成功', data: { project_requirement: @project_requirement.to_api_dashboard } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  # == Vue actions end ==

  private
  def project_requirement_params
    params.require(:project_requirement).permit(:title, :content, :category, :demand_number, :file, :file1, :file2, :project_id, :operator_id)
  end

  def v_project_requirement_params
    params.permit(:title, :content, :category, :demand_number, :file, :file1, :file2, :project_id, :operator_id, :status, :priority)
  end

  def load_project_requirement
    @project_requirement = ProjectRequirement.find(params[:id])
  end

end