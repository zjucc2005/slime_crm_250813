# frozen_string_literal: true

class CompanySummariesController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def v_index
    if params[:datetime]
      begin
        @company_summaries = CompanySummary.where(datetime: params[:datetime]).order(:company_id)
        render json: { status: 0, data: { company_summaries: @company_summaries.map(&:to_api) } }
      rescue => e
        render json: { status: 1, msg: e.message }
      end
    end
  end

  # req - data: [{ datetime: '2024-01-01', company_id: 1, infos: [ { name: '访谈小时', price: 8.8, remark: '备注' } ] }]
  # res - { status: 0, data: { company_summaries: [{...}] } }
  #       { status: 1, msg: 'error message' }
  def v_summary_edit; end
  def v_summary_update
    begin
      ActiveRecord::Base.transaction do
        params[:data].each do |i, i_item|
          company_summary = CompanySummary.where(datetime: i_item[:datetime], company_id: i_item[:company_id]).first
          if company_summary
            company_summary.update(operator_id: current_user.id)
          else
            company_summary = CompanySummary.create!(datetime: i_item[:datetime], company_id: i_item[:company_id], operator_id: current_user.id)
          end
          i_item[:infos].each do |j, j_item|
            info = company_summary.infos.where(name: j_item[:name]).first
            if info
              info.update(price: j_item[:price], remark: j_item[:remark])
            else
              company_summary.infos.create!(name: j_item[:name], price: j_item[:price], remark: j_item[:remark])
            end
          end
        end
      end

      # @company_summary = CompanySummary.where(datetime: params[:datetime], company_id: params[:company_id]).first
      # ActiveRecord::Base.transaction do
      #   if @company_summary
      #     @company_summary.update(operator_id: current_user.id)
      #   else
      #     @company_summary = CompanySummary.create!(datetime: params[:datetime], company_id: params[:company_id], operator_id: current_user.id)
      #   end
      #   params[:infos].each do |k, item|
      #     info = @company_summary.infos.where(name: item[:name]).first
      #     if info
      #       info.update(price: item[:price], remark: item[:remark])
      #     else
      #       @company_summary.infos.create!(name: item[:name], price: item[:price], remark: item[:remark])
      #     end
      #   end
      # end
      render json: { status: 0 }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_summary_show
    begin
      @company_summary = CompanySummary.find(params[:company_summary_id])
      render json: { status: 0, data: { company_summary: @company_summary.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_summary_init
    begin
      raise 'datetime is required' if params[:datetime].blank?
      raise '请选择历史月份' if params[:datetime].to_time >= Time.now.beginning_of_month
      @data = []
      if params[:company_id].present?
        company_ids = [params[:company_id]]
      else
        s_month = Time.parse(params[:datetime]).beginning_of_month
        company_ids =  ProjectTask.joins(:project).where('project_tasks.status': 'finished').
          where('project_tasks.started_at BETWEEN ? AND ?', s_month, s_month + 1.month).
          select('projects.company_id as company_id').distinct.pluck(:company_id)
      end
      company_ids.each do |company_id|
        # company_summary = CompanySummary.where(datetime: params[:datetime], company_id: company_id).first
        # if company_summary
        #   @data << company_summary.to_init_data
        # else
        #   @data << CompanySummary.init_data(params[:datetime], company_id)
        # end
        @data << CompanySummary.init_data(params[:datetime], company_id)
      end

      render json: { status: 0, data: @data }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def v_summary_chart
    if params[:datetime]
      begin
        @company_summaries = CompanySummary.where(datetime: params[:datetime]).order(:company_id)
        arr = @company_summaries.map { |s| 
          {
            name: s.company.name_abbr,
            income: s.infos.where(name: '总访谈收入').first&.price&.to_f,
            profit: s.infos.where(name: '总访谈毛利').first&.price&.to_f
          }
        }
        arr = arr.sort_by { |e| e[:income] }.reverse # 按访谈收入降序
        @data = arr[0, 12]                   # 取前12名，后面汇总到其他
        rest_arr = arr[12, arr.length - 1]
        if rest_arr.present?
          @data << { name: '其他', income: rest_arr.sum{ |e| e[:income] }, profit: rest_arr.sum{ |e| e[:profit] } }
        end
        render json: { status: 0, data: @data }
      rescue => e
        render json: { status: 1, msg: e.message }
      end
    end
  end

  def v_company_options
    begin
      if params[:datetime].present?
        s_month = Time.parse(params[:datetime]).beginning_of_month
        company_ids =  ProjectTask.joins(:project).where('project_tasks.status': 'finished').
          where('project_tasks.started_at BETWEEN ? AND ?', s_month, s_month + 1.month).
          select('projects.company_id as company_id').distinct.pluck(:company_id)
        query = Company.where(id: company_ids)
      else
        query = Company.all
      end
      @companies = user_channel_filter(query).order(:id)
      render json: { status: 0, data: { companies: @companies.map{ |c| [c.uid_name_abbr, c.id] } } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

end