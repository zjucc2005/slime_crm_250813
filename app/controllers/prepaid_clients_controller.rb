class PrepaidClientsController < ApplicationController
  before_action :set_prepaid_client, only: [:show, :edit, :update, :destroy]

  def index
    # 首先获取符合条件的公司数量
    companies_count = Company.joins(:contracts)
                            .where(contracts: { payment_way: 'advance_payment' })
                            .distinct
                            .count

    # 然后获取详细数据
    @companies = Company.joins(:contracts)
                       .where(contracts: { payment_way: 'advance_payment' })
                       .distinct
                       .left_joins(:prepaid_clients)
                       .select('companies.*, prepaid_clients.total_hours, prepaid_clients.invoice_amount, prepaid_clients.invoice_date, prepaid_clients.invoice_number, prepaid_clients.expected_payment_date')

    Rails.logger.info "查询SQL: #{@companies.to_sql}"
    Rails.logger.info "查询结果数量: #{companies_count}"
    Rails.logger.info "合同数量检查: #{Contract.where(payment_way: 'advance_payment').count}"

    @companies = @companies.map do |company|
      prepaid_client = company.prepaid_clients.first
      {
        id: prepaid_client&.id,
        company: company.as_json(only: [:id, :name]),
        total_hours: company.total_hours,
        used_hours: prepaid_client&.used_hours || 0,
        advance_payment_hours: prepaid_client&.advance_payment_hours || 0,
        remaining_hours: prepaid_client&.remaining_hours || 0,
        invoice_amount: company.invoice_amount,
        invoice_date: company.invoice_date,
        invoice_number: company.invoice_number,
        invoice_file_url: prepaid_client&.invoice_file&.present? ? prepaid_client.invoice_file.url : nil,
        contract_file_url: company.contracts.available.first&.file&.present? ? company.contracts.available.first.file.url : nil,
        expected_payment_date: company.expected_payment_date
      }
    end
  end

  def show
  end

  def new
    @prepaid_client = PrepaidClient.new
    @prepaid_client.company_id = params[:company_id] if params[:company_id].present?
  end

  def create
    @prepaid_client = PrepaidClient.new(prepaid_client_params)
    if @prepaid_client.save
      redirect_to prepaid_clients_path, notice: t('message.create_success')
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @prepaid_client.update(prepaid_client_params)
      redirect_to prepaid_clients_path, notice: t('message.update_success')
    else
      render :edit
    end
  end

  def destroy
    @prepaid_client.destroy
    redirect_to prepaid_clients_path, notice: t('message.delete_success')
  end

  private

  def set_prepaid_client
    @prepaid_client = PrepaidClient.find(params[:id])
  end

  def prepaid_client_params
    permitted_params = params.require(:prepaid_client).permit(
      :company_id, :total_hours, :invoice_amount,
      :invoice_date, :invoice_number, :expected_payment_date,
      :invoice_file, :advance_payment_hours
    )

    if params[:prepaid_client][:contract_file].present?
      company = Company.find(permitted_params[:company_id])
      contract = company.contracts.available.first
      
      if contract
        begin
          contract.update!(file: params[:prepaid_client][:contract_file])
        rescue ActiveRecord::RecordInvalid => e
          @prepaid_client.errors.add(:contract_file, e.message)
          return permitted_params
        end
      else
        begin
          Contract.create!(
            started_at: Time.current,
            ended_at: 1.year.from_now,
            charge_rate: 0,
            currency: 'CNY',
            base_duration: '60',
            progressive_duration: 60,
            payment_days: 30,
            type_of_payment_day: 'natural',
            company_id: permitted_params[:company_id],
            payment_way: 'advance_payment',
            file: params[:prepaid_client][:contract_file]
          )
        rescue ActiveRecord::RecordInvalid => e
          @prepaid_client.errors.add(:contract_file, e.message)
          return permitted_params
        end
      end
    end

    permitted_params
  end
end