<div style="margin-left:50px;padding-top:30px;padding-bottom:30px;font-weight:bold;">

    {% if not is_index %}
        <div style="float:left;text-align:center;font-size:14px;}">本文作者: <a href="https://wchoward.github.io"}>Howard WU</a></div><br />
        <div style="float:left;text-align:center;font-size:14px;">本文链接: <a href="{{ url_for(page.path) }}">{{ page.permalink }}</a></div><br />
        <div style="float:left;text-align:center;font-size:14px;">许可协议: 本博客所有文章均采用 <a href="https://creativecommons.org/licenses/by-nc-nd/4.0/">CC BY 4.0</a> 许可协议. 转载请注明出处!</div>
    {% endif %}
</div>