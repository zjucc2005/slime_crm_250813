document.addEventListener('DOMContentLoaded', function() {
    // 获取相关DOM元素
    const singleMonthRadio = document.getElementById('search_type_single_month');
    const allToDateRadio = document.getElementById('search_type_all_to_date');
    const monthSelector = document.getElementById('month_selector');
    const monthSelect = document.getElementById('month');
    const form = monthSelector.closest('form');

    // 设置月份选择器的默认值为当前月份
    if (!monthSelect.value) {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const currentMonth = `${year}-${month}-01`;
        monthSelect.value = currentMonth;
    }

    // 监听单选按钮变化事件
    function handleSearchTypeChange(event) {
        const isSingleMonth = event.target.value === 'single_month';
        monthSelector.style.display = isSingleMonth ? 'block' : 'none';
        
        // 自动提交表单以更新数据
        form.submit();
    }

    // 绑定事件监听器
    singleMonthRadio.addEventListener('change', handleSearchTypeChange);
    allToDateRadio.addEventListener('change', handleSearchTypeChange);

    // 初始化所有模态框
    $('.modal').modal({
        keyboard: true,
        backdrop: 'static'
    });

    // 处理表单提交
    $('form[data-remote="true"]').on('ajax:success', function(event) {
        var [data, status, xhr] = event.detail;
        // 关闭模态框
        $(this).closest('.modal').modal('hide');
        // 刷新页面以显示更新后的数据
        window.location.reload();
    }).on('ajax:error', function(event) {
        var [data, status, xhr] = event.detail;
        alert('更新失败，请重试');
    });
});