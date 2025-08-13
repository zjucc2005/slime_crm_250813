# frozen_literal: true

class UtilsController < ApplicationController
  before_action :authenticate_user!

  # GET /utils/loading_modal?op=newCallRecord&reference_id=1
  def loading_modal
    @op = params[:op] # operation
    case @op
    when 'newCallRecord' then set_new_call_record
    when 'editCallRecord' then set_edit_call_record
    when 'importCallRecords' then set_import_call_records
    when 'showProjectRequirement' then set_show_project_requirement
    else nil
    end
    respond_to { |f| f.js }
  end

  private

  def set_new_call_record
    @project = Project.find(params[:project_id])
    @call_record = @project.call_records.new
    @modal_title = t('action.new_model', model: t('activerecord.models.call_record'))
    @modal_body_form = 'call_records/loading_modal/new'
  end

  def set_edit_call_record
    @call_record = CallRecord.find(params[:id])
    @project = @call_record.project
    @modal_title = t('action.update_model', model: t('activerecord.models.call_record'))
    @modal_body_form = 'call_records/loading_modal/edit'
  end

  def set_import_call_records
    @project = Project.find(params[:project_id])
    @modal_title = t(:batch_import)
    @modal_body_form = 'call_records/loading_modal/import'
  end

  def set_show_project_requirement
    @project = Project.find(params[:project_id])
    @project_requirements = @project.project_requirements.order(created_at: :desc)
    @modal_title = t('activerecord.models.project_requirement')
    @modal_body_form = 'projects/work_board/project_requirements'
    @modal_dialog_max_width = 1080
  end
end