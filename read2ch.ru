require 'open-uri'
require 'sinatra/base'
require 'json'
require 'ostruct'

class Array
  
  def to_h
    reduce({}) { |r, e| r[e[0]] = e[1]; r }
  end
  
end

class Object

  def map(&f)
    f.(self)
  end
  
end

class SearchPhraseWebApp < Sinatra::Application
  
  get '/:board/res/:thread.html' do
    #
    headers "Content-Type" => "text/html; charset=utf8"
    # 
    uri = "https://2ch.hk/makaba/mobile.fcgi?task=get_thread&board=#{params[:board]}&thread=#{params[:thread]}&post=0"
    #
    posts =
      begin
        open(uri, HEADERS) { |io| io.read }.
          map { |s| JSON.parse("{\"data\": #{s}}")['data'] }.
          tap { |r| halt 404, r["Error"] if r.is_a? Hash and r.key? "Error" }.
          map do |post|
            post = OpenStruct.new(post)
            post.files ||= []
            post.files.map! { |file| OpenStruct.new(file) }
            post
          end.
          each_with_index { |post, i| post.rel_num = i+1 }
      rescue OpenURI::HTTPError => e
        halt 503, e.message
      end
    #
    erb <<-HTML, :locals => { posts: posts, params: params }
<html>
<head>
  <style>
    * {
      font-family: serif;
    }
    .reply {
      padding: 0.8em;
      margin-bottom: 0.25em;
      border: 1px solid #CCC;
      border-radius: 5px;
    }
    .post_file {
      display: inline;
      margin-right: 0.8em;
      margin-top: 0.8em;
      margin-bottom: 0.8em;
    }
    .post_header {
      margin-bottom: 0.5em;
      font-size: smaller;
      color: #999;
    }
    .post_rel_num {
      color: inherit;
      font-weight: bold;
      text-decoration: none;
    }
    .post_num {
      color: inherit;
      text-decoration: none;
    }
    .post_name {
      color: inherit;
      /*font-style: italic;*/
    }
    .post_date {
    }
    .post_subject {
      color: inherit;
      font-weight: bold;
    }
    span.spoiler {
      background: #BBB;
      color: #BBB;
    }
    span.spoiler:hover {
      background: #FFFFFF;
      color: #000000
    }
  </style>
</head>
<body>

<% for post in posts %>
<div class="reply">
  <div class="post_header">
    <a class="post_rel_num" id="rel<%=post.rel_num%>" href="#rel<%=post.rel_num%>">№<%=post.rel_num%>.</a>
    <a class="post_num" id="<%=post.num%>" href="#<%=post.num%>">#<%=post.num%></a>
    <% if post.email.empty? %> <span class="post_name"><%=post.name%></span> <% else %> <a class="post_name" href="<%=post.email%>"><%=post.name%></a> <% end %>
    <span class="post_subject"><%=post.subject%></span>
    (<span class="post_date"><%=post.date%></span>)
  </div>
  <% for post_file in post.files %>
  <div class="post_file"><a href="https://2ch.hk/<%=params[:board]%>/<%=post_file.path%>"><img src="https://2ch.hk/<%=params[:board]%>/<%=post_file.thumbnail%>" name="<%=post_file.name%>"/></a></div>
  <% end %>
  <% if not post.files.empty? then %> <p/> <% end %>
  <%=post.comment%>
</div>
<% end %>

</body>
</html>
    HTML
  end
  
  # Headers for unhiding boards forbidden by Mizulina.
  HEADERS =
    <<-TXT.
Host: 2ch.hk
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:41.0) Gecko/20100101 Firefox/41.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Cookie: ageallow=1; __cfduid=d50ae52b0a244dd09a09e0bfb1cbdc4011444542009; cf_clearance=d6f03e7093daba873b774c7f6449b98930a98ea6-1444542014-604800; usercode_auth=24ffaf6d82692d95746a61ef1c1436ce
Connection: keep-alive
Cache-Control: max-age=0
    TXT
    lines.
    reject { |line| line.strip.empty? }.
    map { |line| line.split(": ", 2).map(&:strip) }.
    reject { |key, value| key == 'Accept-Encoding' }.
    to_h
  
end

run SearchPhraseWebApp.new
