# frozen_string_literal: true
#
class ClientsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def index
    query = user_channel_filter(Candidate.client)
    query = query.where('candidates.name ~* :name OR candidates.nickname ~* :name', { name: params[:name].strip }) if params[:name].present?
    query = query.where('candidates.phone ~* :phone OR candidates.phone1 ~* :phone', { :phone => params[:phone].strip.shellescape }) if params[:phone].present?
    %w[title].each do |field|
      query = query.where("candidates.#{field} ~* ?", params[field].strip.shellescape) if params[field].present?
    end
    %w[company_id job_status department].each do |field|
      query = query.where(field.to_sym => params[field].strip) if params[field].present?
    end
    if params[:client_active] == 'true'
      query = query.joins(:project_candidates).where('project_candidates.category': 'client').where('project_candidates.created_at > ?', Time.now - 3.months).distinct
    end
    if params[:edu_exp].present?
      query = query.joins(:experiences).where('candidate_experiences.org_cn ILIKE ?', "%#{params[:edu_exp].strip}%").distinct
    end
    @clients = query.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
  end

  def new
    @client = Candidate.client.new(company_id: params[:company_id])
    @exps = []
    3.times { @exps << @client.experiences.education.new }
  end

  def create
    begin
      ActiveRecord::Base.transaction do
        @client = Candidate.client.create!(
            candidate_params.merge({created_by: current_user.id, user_channel_id: current_user.user_channel_id, cpt: 0})
        )
        3.times do |i|
          @client.experiences.education.create!(org_cn: params[:exps][i.to_s][:org_cn])
        end
      end
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to clients_path
    rescue Exception => e
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  def edit
    load_client
    @exps = @client.experiences.education.order(:created_at)
  end

  def update
    begin
      load_client

      ActiveRecord::Base.transaction do
        @client.update!(candidate_params)
        3.times do |i|
          edu_exp = @client.experiences.education.order(:created_at)[i]
          edu_exp ? edu_exp.update!(org_cn: params[:exps][i.to_s][:org_cn]) :
              @client.experiences.education.create!(org_cn: params[:exps][i.to_s][:org_cn])
        end
      end
      flash[:success] = t(:operation_succeeded)
      redirect_with_return_to edit_client_path(@client)
    rescue Exception => e
      flash.now[:error] = e.message
      @exps = @client.experiences.education.order(:created_at)
      render :edit
    end
  end

  # POST
  def import_client
    @errors = []
    if request.post?
      begin
        sheet = open_spreadsheet(params[:file])
        raise 'excel表格里没有信息' if sheet.last_row < 2
        raise 'excel不能超过1000行' if sheet.last_row > 1000
        2.upto(sheet.last_row) do |i|
          parser = Utils::ClientTemplateParser.new(sheet.row(i), current_user.id, current_user.user_channel_id)
          @errors << "Row #{i}: #{parser.errors.join(', ')}" unless parser.import
        end
      rescue Exception => e
        @errors << e.message
      end

      if @errors.blank?
        flash[:success] = t(:operation_succeeded)
        redirect_to clients_path
      else
        render :import_client
      end
    end
  end

  private

  def load_client
    @client = Candidate.find(params[:id])
  end

  def candidate_params
    params.require(:candidate).permit(:company_id, :gender, :job_status, :contact_status,
                                      :first_name, :last_name, :nickname, :title, :department, :city, :address,
                                      :email, :email1, :phone, :phone1, :wechat, :linkedin,
                                      :employer0, :employer1, :employer2)
  end

end