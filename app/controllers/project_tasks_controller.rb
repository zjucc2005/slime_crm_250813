# encoding: utf-8
class ProjectTasksController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /project_tasks/:id
  def show
    load_project_task
  end

  # GET /project_tasks/:id/edit
  def edit
    begin
      load_project_task
      load_active_contract
      if @project_task.status != 'ongoing'
        redirect_to project_task_path(@project_task) and return
      end
      check_editable # 只能编辑自己创建的任务
      @project = @project_task.project
      @project_task.notice_email ||= @project.company.project_task_notice_email
    rescue Exception => e
      flash[:error] = e.message
      redirect_to project_path(@project_task.project)
    end
  end

  # PUT /project_tasks/:id
  def update
    begin
      load_project_task
      if @project_task.update(project_task_params)
        if params[:commit] == t('action.preview')
          respond_to { |f| f.js }
        elsif params[:commit] == t('action.send_out')
          if ProjectTask::NOTICE_EMAIL.keys.include? @project_task.notice_email
            @project_task.send_notice_email
            flash[:success] = t(:operation_succeeded)
            redirect_to edit_project_task_path(@project_task)
          else
            respond_to { |f| f.js }
          end
        else
          if params[:commit] == t('action.submit_and_confirm')
            @project_task.finish!
          end
          flash[:success] = t(:operation_succeeded)
          redirect_to project_path(@project_task.project)
        end
      else
        render :edit
      end
    rescue Exception => e
      flash.now[:error] = e.message
      render :edit
    end
  end

  # POST /project_tasks/:id/add_cost.js, remote: true
  def add_cost
    load_project_task

    begin
      ActiveRecord::Base.transaction do
        cost = @project_task.costs.new(user_channel_id: current_user.user_channel_id)
        cost.category = params[:category]
        cost.price    = params[:price]
        cost.currency = params[:currency]
        cost.memo     = params[:memo]
        cost.lijin    = params[:lijin]

        if params[:category] == 'expert' && params[:advance_payment] == 'false'  # expert fee
          template_expert = @project_task.expert.payment_infos.where(id: params[:template_expert]).first
          if template_expert
            cost.payment_info = {
              category:   template_expert.category,
              bank:       template_expert.bank,
              sub_branch: template_expert.sub_branch,
              account:    template_expert.account,
              username:   template_expert.username,
              id_number:  template_expert.id_number
            }
          else
            cost.payment_info = params[:payment_info]  # general
            # @project_task.expert.payment_infos.create!(
            #   params.require(:payment_info).permit(:category, :bank, :sub_branch, :account, :username, :id_number).merge(created_by: current_user.id)
            # )
            candidate_payment_info = @project_task.expert.payment_infos.new(
              params.require(:payment_info).permit(:category, :bank, :sub_branch, :account, :username, :id_number).merge(created_by: current_user.id)
            )
            if candidate_payment_info.valid?
              candidate_payment_info.save
            else
              raise candidate_payment_info.errors.full_messages[0]
            end
          end
        elsif params[:category] == 'recommend'  # recommend fee
          recommender = @project_task.expert.recommender  # recommender expert
          if recommender
            template_recommend = recommender.payment_infos.where(id: params[:template_recommend]).first
            if template_recommend
              cost.payment_info = {
                category:   template_recommend.category,
                bank:       template_recommend.bank,
                sub_branch: template_recommend.sub_branch,
                account:    template_recommend.account,
                username:   template_recommend.username,
                id_number:  template_recommend.id_number
              }
            else
              cost.payment_info = params[:payment_info]  # general
              # recommender.payment_infos.create!(
              #   params.require(:payment_info).permit(:category, :bank, :sub_branch, :account, :username, :id_number).merge(created_by: current_user.id)
              # )
              candidate_payment_info = recommender.payment_infos.new(
                params.require(:payment_info).permit(:category, :bank, :sub_branch, :account, :username, :id_number).merge(created_by: current_user.id)
              )
              if candidate_payment_info.valid?
                candidate_payment_info.save
              else
                raise candidate_payment_info.errors.full_messages[0]
              end
            end
          else
            cost.payment_info = params[:payment_info]  # general
          end
        else
          cost.payment_info = params[:payment_info]  # general
        end
        cost.save!

        if cost.category == 'expert'
          cost.create_expert_tax_instance
        end
      end
    rescue Exception => e
      @error = e.message
    end

    respond_to{|f| f.js }
  end

  # DELETE /project_tasks/:id/remove_cost.js, remote: true
  def remove_cost
    load_project_task

    cost = @project_task.costs.where(id: params[:project_task_cost_id]).first
    cost&.destroy!
    if cost.category == 'expert'
      @project_task.costs.where(category: 'expert_tax').map(&:destroy)
    end
    respond_to{|f| f.js }
  end

  def edit_cost
    load_project_task
    @project_task_cost = @project_task.costs.find(params[:project_task_cost_id])
  end

  def update_cost
    load_project_task
    @project_task_cost = @project_task.costs.find(params[:project_task_cost_id])
    @project_task_cost.update(project_task_cost_params)
    if @project_task_cost.category == 'expert'
      @project_task_cost.update_expert_tax_instance
    end
    flash[:success] = t(:operation_succeeded)
    redirect_to edit_project_task_path(@project_task)
  end

  # GET /project_tasks/:id/get_base_price.json
  def get_base_price
    load_project_task
    contract    = @project_task.active_contract
    f           = params[:f] == 'true'
    is_shorthand = params[:is_shorthand] == 'true'
    base_price  = contract.base_price(params[:duration].to_i, f)
    shorthand_price = is_shorthand ? contract.shorthand_price(params[:duration].to_i) : 0
    expert_rate = params[:expert_rate].to_d
    render :json => {
             :price    => (base_price * expert_rate).round,
             :currency => ApplicationRecord::CURRENCY[contract.currency],
             :is_taxed => t(contract.is_taxed.to_s),
             :tax_rate => contract.tax_rate,
             :shorthand_price => shorthand_price,
             :recruitment_fee => contract.recruitment_rate
           }
  end

  # PUT /project_tasks/:id/cancel
  def cancel
    load_project_task

    if @project_task.can_cancel?
      @project_task.update(status: 'cancelled')
      flash[:success] = t(:operation_succeeded)
    else
      flash[:error] = t(:operation_failed)
    end
    redirect_to project_path(@project_task.project)
  end

  # PUT /project_tasks/:id/moveto
  def moveto
    load_project_task

    @project_task.update(project_id: params[:project_id])
    flash[:success] = t(:operation_succeeded)
    redirect_to project_tasks_project_path(@project_task.project)
  end

  # GET
  def draw_consent
    load_project_task
    file_path = @project_task.draw_consent
    redirect_to file_path.gsub(/^public/, '')
  end

  def v_upload_jiesuan_file
    begin
      load_project_task
      js_files = @project_task.jiesuan_files
      js_files << params[:file]
      @project_task.jiesuan_files = js_files
      @project_task.save!
      render json: { status: 0 }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_remove_jiesuan_file
    begin
      load_project_task
      js_files = @project_task.jiesuan_files
      js_files.delete_if { |f| f.identifier == params[:filename] }
      @project_task.jiesuan_files = js_files
      @project_task.save
      render json: { status: 0 }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  private
  def load_project_task
    @project_task = ProjectTask.find(params[:id])
  end

  def check_editable
    raise t(:not_authorized) unless @project_task.can_be_edited_by(current_user)
  end

  def load_active_contract
    @contract = @project_task.active_contract
    raise t(:contract_expired) if @contract.nil?
  end

  def project_task_params
    params.require(:project_task).permit(:client_id, :pm_id, :interview_form, :started_at, :expert_level, :expert_rate, :duration,
                                         :charge_duration, :actual_price, :is_shorthand, :is_recorded, :memo, :f_flag,
                                         :interview_no, :recruitment_fee, :notice_email, :expert_alias, :candidate_experience_id,
                                         :jiesuan_file)
  end

  def project_task_cost_params
    params.require(:project_task_cost).permit(:price, :lijin)
  end

end