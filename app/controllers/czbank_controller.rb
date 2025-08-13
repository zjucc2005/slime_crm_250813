# frozen_string_literal: true

class CzbankController < ApplicationController

  def xibao
    start_date = (CzbankXibao.minimum(:belong_date) || Time.now).to_date
    end_date = Time.now.to_date
    @date_options = (start_date..end_date).map{|t| t.to_s}.reverse
  end

  def xibao_gen_pic
    options = {
        org_name: params[:org_name].to_s.strip,
        staff_name: params[:staff_name].to_s.strip,
        sale_value: "#{params[:sale_value]} 万",
        trans_date: (Date.parse(params[:trans_date]) rescue Time.now.to_date).strftime('%Y年%m月%d日')
    }
    @pic_path = CzbankXibao.draw_xibao_pic(options)
    redirect_to @pic_path.gsub(/^public/, '')
  end

  def xibao_create
    begin
      if params[:commit] == '保存并生成喜报'
        @xibao = CzbankXibao.find_or_create_by(czbank_xibao_params)
        redirect_to xibao_gen_pic_czbank_index_path(@xibao.to_api)
      else
        if CzbankXibao.exists?(czbank_xibao_params)
          flash[:success] = '该数据已存在'
        else
          @xibao = CzbankXibao.create(czbank_xibao_params)
        end
        redirect_to xibao_czbank_index_path
      end
    rescue => e
      logger.info e.message
      flash[:danger] = '操作失败'
      redirect_to xibao_czbank_index_path
    end
  end

  def xibao_import
    begin
      sheet = open_spreadsheet(params[:file])
      raise 'excel表格里没有信息' if sheet.last_row < 2
      raise 'excel不能超过2000行' if sheet.last_row > 2000
      2.upto(sheet.last_row) do |i|
        parser = Utils::CzbankXibaoTemplateParser.new(sheet.row(i))
        unless parser.import
          logger.info "Row #{i}: #{parser.errors.join(', ')}"
        end
      end
      flash[:success] = '导入成功'
      redirect_to xibao_czbank_index_path
    rescue => e
      flash[:danger] = "导入失败: #{e.message}"
      redirect_to xibao_czbank_index_path
    end
  end

  def xibao_list
    if params[:belong_date].present?
      query = CzbankXibao.where(belong_date: params[:belong_date])
      @xibao_list = query.order(id: :desc)
      org_ranking_o = query.select('org_name, SUM(sale_value) AS sum_sale_value, SUM(bill_count) AS sum_bill_count').group(:org_name).order(sum_sale_value: :desc)
      @org_ranking = org_ranking_o.map{ |item|
        { org_name: item.org_name, sale_value: item.sum_sale_value, bill_count: item.sum_bill_count }
      }
      CzbankXibao::ORG_LIST.each do |org_name|
        if @org_ranking.select{|item| item[:org_name] == org_name }[0].nil?
          @org_ranking << { org_name: org_name, sale_value: 0, bill_count: 0 }
        end
      end
    else
      query = CzbankXibao.all
      @xibao_list = query.order(id: :desc)
      sum_ranking_o = query.select('org_name, SUM(sale_value) AS sum_sale_value, SUM(bill_count) AS sum_bill_count').group(:org_name)
      @sum_ranking = sum_ranking_o.map { |item|
        target = CzbankXibao::TARGET[item.org_name]
        staff_active = CzbankXibao.where(org_name: item.org_name, is_public: false).select('staff_name').distinct.count
        staff_total = CzbankXibao::STAFF_COUNT[item.org_name]
        {
            org_name: item.org_name,
            sale_value: item.sum_sale_value,
            bill_count: item.sum_bill_count,
            sale_target: target,
            sale_rate: target.zero? ? -1 : (item.sum_sale_value.to_f / target).round(2),
            staff_active: staff_active,
            staff_total: staff_total,
            staff_active_rate: staff_active.to_f / staff_total
        }
      }
      CzbankXibao::ORG_LIST.each do |org_name|
        if @sum_ranking.select{ |item| item[:org_name] == org_name}[0].nil?
          @sum_ranking << {
              org_name: org_name,
              sale_value: 0,
              bill_count: 0,
              sale_target: CzbankXibao::TARGET[org_name],
              sale_rate: 0,
              staff_active: 0,
              staff_total: CzbankXibao::STAFF_COUNT[org_name],
              staff_active_rate: 0
          }
        end
      end
      @sum_ranking.sort_by!{ |item| item[:sale_rate] }.reverse!
      @period = [(CzbankXibao.minimum(:belong_date) || Time.now).to_date, Time.now.to_date]
    end

    @date = params[:belong_date]
    respond_to { |f| f.js }
  end

  private
  def czbank_xibao_params
    params.require(:czbank_xibao).permit(:org_name, :staff_name, :sale_value, :belong_date, :bill_count)
  end
end