class ApplicationController < ActionController::Base

  # handle unauthorized access
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden, content_type: 'text/html' }
      format.html { redirect_to main_app.root_url, notice: exception.message }
      format.js   { head :forbidden, content_type: 'text/html' }
    end
  end

  # Add global error handling to log errors
  rescue_from StandardError do |exception|
    Rails.logger.error "==== 500 ERROR CAUGHT IN APPLICATION CONTROLLER ===="
    Rails.logger.error "Error type: #{exception.class.name}"
    Rails.logger.error "Error message: #{exception.message}"
    Rails.logger.error "Backtrace:\n#{exception.backtrace.join("\n")}"
    Rails.logger.error "Request parameters: #{params.inspect}"
    Rails.logger.error "Controller: #{controller_name}, Action: #{action_name}"
    
    # Check if it's related to MedicalInsuranceInfo
    if exception.message.include?('MedicalInsuranceInfo') || exception.backtrace.any? { |line| line.include?('medical_insurance') }
      Rails.logger.error "Medical Insurance related error detected!"
      
      # Log MedicalInsuranceInfo constants
      begin
        Rails.logger.info "MedicalInsuranceInfo::NON_CLINICAL_TYPES: #{MedicalInsuranceInfo::NON_CLINICAL_TYPES.inspect}"
        Rails.logger.info "MedicalInsuranceInfo::COMPREHENSIVE_SUB_TYPES: #{MedicalInsuranceInfo::COMPREHENSIVE_SUB_TYPES.inspect}"
        Rails.logger.info "MedicalInsuranceInfo::CALCULATION_SUB_TYPES: #{MedicalInsuranceInfo::CALCULATION_SUB_TYPES.inspect}"
      rescue => e
        Rails.logger.error "Error logging MedicalInsuranceInfo constants: #{e.message}"
      end
      
      # Try to log candidate details if we have an ID
      if params[:id].present? && defined?(Candidate)
        begin
          candidate = Candidate.find(params[:id])
          Rails.logger.info "Candidate: #{candidate.attributes.inspect}"
          Rails.logger.info "Medical insurance records: #{candidate.medical_insurance_infos.to_a.inspect}"
        rescue => e
          Rails.logger.error "Error logging candidate details: #{e.message}"
        end
      end
    end
    
    # Re-raise the exception to maintain default error handling
    raise exception
  end

  private
  def current_user
    if super&.su? && super.title.present?
      User.find_by(id: super.title) || super  # 账号模拟
    else
      super
    end
  end

  def open_spreadsheet(file)
    begin
      Roo::Spreadsheet.open file
    rescue
      raise '文件格式错误'
    end
  end

  def user_channel_filter(query, field='user_channel_id')
    if current_user.su? && current_user.user_channel_id.blank?
      query
    else
      query.where(field => current_user.user_channel_id)
    end
  end

  def redirect_with_return_to(default_path)
    if params[:return_to].present?
      redirect_to params[:return_to]
    else
      redirect_to default_path
    end
  end

  def set_per_page(maxlength=100)
    if (1..maxlength).include?(params[:per_page].to_i)
      @per_page = params[:per_page].to_i
    else
      @per_page = 50
    end
  end

end
