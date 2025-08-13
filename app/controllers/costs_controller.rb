# frozen_string_literal: true

class CostsController < ApplicationController
  load_and_authorize_resource except: [:create_cost_type, :update_cost_type, :delete_cost_type]
  before_action :authenticate_user!

  def index
    query = CostSummary.all
    @cost_summaries = query.order(datetime: :desc).paginate(page: params[:page], per_page: 20)
  end

  def v_summary_show
    begin
      @cost_summary = CostSummary.find(params[:cost_summary_id])
      render json: { status: 0, data: { cost_summary: @cost_summary.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  # req - { datetime: '2024-01-01', costs: [ { cost_type_id: 1, price: 8.8 } ] }
  # res - { status: 0, data: { cost_summary: {...} } }
  #       { status: 1, msg: 'error message' }
  def v_summary_new; end
  def v_summary_create
    begin
      if CostSummary.exists?(datetime: params[:datetime])
        raise "该月份已有成本结算数据，#{params[:datetime].to_time.strftime('%Y-%m')}"
      end
      ActiveRecord::Base.transaction do
        @cost_summary = CostSummary.create!(datetime: params[:datetime], operator_id: current_user.id)
        if params[:costs].present?
          params[:costs].each do |k, item|
            cost_type = CostType.find(item[:cost_type_id])
            @cost_summary.costs.create!(cost_type_id: cost_type.id, name: cost_type.name, price: item[:price])
          end
          @cost_summary.update_price!
        else
          raise "成本数据不能为空"
        end
      end
      render json: { status: 0, data: { cost_summary: @cost_summary.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  # req - { cost_summary_id: 1, datetime: '2024-01-01', costs: [ { cost_type_id; 1, price: 8.8 } ] }
  # res - { status: 0, data: { cost_summary: {...} } }
  #       { status: 1, msg: 'error message' }
  def v_summary_edit; end
  def v_summary_update
    begin
      @cost_summary = CostSummary.find(params[:cost_summary_id])
      if CostSummary.where.not(id: @cost_summary.id).exists?(datetime: params[:datetime])
        raise "该月份已有成本结算数据，#{params[:datetime].to_time.strftime('%Y-%m')}"
      end
      ActiveRecord::Base.transaction do
        @cost_summary.update(operator_id: current_user.id)
        params[:costs].each do |k, item|
          cost_type = CostType.find(item[:cost_type_id])
          cost = @cost_summary.costs.where(cost_type_id: cost_type.id).first
          if cost
            cost.update(price: item[:price])
          else
            @cost_summary.costs.create!(cost_type_id: cost_type.id, name: cost_type.name, price: item[:price])
          end
        end
        @cost_summary.update_price!
      end
      render json: { status: 0, data: { cost_summary: @cost_summary.to_api } }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  # 跳过v_types和v_load_types方法的权限检查，确保所有登录用户都可以访问成本类型管理页面
  skip_authorize_resource only: [:v_types, :v_load_types]
  
  def v_types; end
  def v_load_types
    begin
      # 获取所有根节点并按ID排序
      @cost_types = CostType.root.order(:id).map(&:to_api)
      
      # 确保返回的数据结构一致
      render json: { 
        status: 0, 
        data: { 
          cost_types: @cost_types 
        } 
      }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  
  def create_cost_type
    begin
      # 获取参数
      name = params[:name]
      parent_id = params[:parent_id]
      is_parent = params[:is_parent] == 'true'
      
      # 验证参数
      return render json: { status: 1, msg: '名称不能为空' } if name.blank?
      
      # 构建路径
      if parent_id.present?
        parent = CostType.find(parent_id)
        path = "#{parent.path}/#{name}"
      else
        path = "/#{name}"
      end
      
      # 创建成本类型
      cost_type = CostType.new(
        name: name,
        path: path,
        parent_id: parent_id,
        is_parent: is_parent,
        disabled: false # 确保新创建的节点默认启用
      )
      
      if cost_type.save
        # 确保返回完整的节点数据，包括所有必要的属性
        node_data = cost_type.to_api
        
        # 如果是父节点但没有子节点，确保children属性存在
        if is_parent && !node_data.key?(:children)
          node_data[:children] = []
        end
        
        render json: { status: 0, msg: '创建成功', data: { cost_type: node_data } }
      else
        render json: { status: 1, msg: cost_type.errors.full_messages.join(', ') }
      end
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  
  def update_cost_type
    begin
      # 获取参数
      id = params[:id]
      name = params[:name]
      
      # 验证参数
      return render json: { status: 1, msg: 'ID不能为空' } if id.blank?
      return render json: { status: 1, msg: '名称不能为空' } if name.blank?
      
      # 查找成本类型
      cost_type = CostType.find(id)
      
      # 更新路径
      old_name = cost_type.name
      new_path = cost_type.path.gsub(/\/#{old_name}(\/?|$)/, "/#{name}\1")
      
      # 更新子节点路径
      CostType.transaction do
        # 更新当前节点
        cost_type.update!(name: name, path: new_path)
        
        # 更新子节点路径
        cost_type.children.each do |child|
          child_path = child.path.gsub(/\/#{old_name}\//, "/#{name}/")
          child.update!(path: child_path)
        end
      end
      
      render json: { status: 0, msg: '更新成功' }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end
  
  def delete_cost_type
    begin
      # 获取参数
      id = params[:id]
      
      # 验证参数
      return render json: { status: 1, msg: 'ID不能为空' } if id.blank?
      
      # 查找成本类型
      cost_type = CostType.find(id)
      
      # 检查是否有子节点
      if cost_type.children.exists?
        return render json: { status: 1, msg: '该节点下有子节点，无法删除' }
      end
      
      # 删除成本类型
      cost_type.destroy
      
      render json: { status: 0, msg: '删除成功' }
    rescue => e
      render json: { status: 1, msg: e.message }
    end
  end

  def summary_chart
    current_year = Time.now.year
    @year_options = ['无'] + (2024..current_year).to_a.reverse    # year options
    if ['无', '', nil].include?(params[:year])
      @year = nil
      @s_time = Time.now.beginning_of_month - 11.months # start time
    else
      @year = current_year  # statistical year
      @s_time = Time.local @year
    end
    # init result
    @result = []
    @result << { name: '总计', data: [] }
    CostType.root.order(:id).each do |type|
      @result << { name: type.name, data: [], stack: '总计' }
    end
    @x_axis = []

    12.times do |i|
      datetime = @s_time + i.month  # start time
      cost_summary = CostSummary.where(datetime: datetime).first
      if cost_summary
        @result.select{|r| r[:name] == '总计' }[0][:data] << cost_summary.price
        cost_summary.price_group_by_root_type.each do |type|
          @result.select{|r| r[:name] == type[:name]}[0][:data] << type[:price] 
        end
      else
        @result.each do |item|
          item[:data] << 0.0  # 无数据时，用0占空位
        end
      end
      @x_axis << datetime.strftime('%Y.%m')
    end
  end
end