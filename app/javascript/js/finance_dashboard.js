document.addEventListener('DOMContentLoaded', function() {
    // 获取搜索类型单选按钮
    const searchTypeRadios = document.querySelectorAll('input[name="search_type"]');

    // 为单选按钮添加change事件监听器
    searchTypeRadios.forEach(function(radio) {
        radio.addEventListener('change', function() {
            // 移除显示/隐藏逻辑，保持时间选择器始终可见
        });
    });
});