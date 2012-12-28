# coding: utf-8
require 'rubygems'
require 'bundler/setup'
Bundler.require

$secret = Hashie::Mash.new(YAML.load_file('./secret.yml'))

class ZaimOAuth

  attr_accessor :consumer

  def initialize(consumer_key, consumer_secret)
    @consumer = OAuth::Consumer.new(consumer_key, consumer_secret,
                                    request_token_path: $secret.Request_token_URL,
                                    authorize_path: $secret.Authorize_URL,
                                    access_token_path: $secret.Access_token_URL)
  end

end

#### ------------ ここからSinatra ------------ ####

# redirect前後でrequest_tokenを保管しておくためにsesionを有効化
set :sessions, true
enable :sessions

before do
  @zaim = ZaimOAuth.new($secret.Consumer_Key, $secret.Consumer_Secret)
end

get '/' do
  erb :index
end

get '/oauth' do
  # 登録したURLとあわせないと以下のエラーが出る
  # > 外部アプリケーションの URL 設定が誤っている（コールバック URL）
  request_token = @zaim.consumer.get_request_token( { oauth_callback: 'http://neon:4567/oauth_callback' })

  # save request_token,request_token_secret into session
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret

  redirect request_token.authorize_url
end

# リダイレクト先の認証からコールバック、アクセストークンを取得
#  -- Zaim上でアプリ作成時にクライアントアプリを選択してしまうとcallbackが発動しない.
#  -- Webアプリを選択が正しい
get '/oauth_callback' do
  request_token = OAuth::RequestToken.new(
    @zaim.consumer,
    session[:request_token],
    session[:request_token_secret])

  access_token = request_token.get_access_token(
    {},
    :oauth_verifier => params[:oauth_verifier]) # キモ

  session[:request_token] = session[:request_token_secret] = nil

  erb :oauth_callback, :locals => { :access_token => access_token }
end

__END__

@@ index
<a href="/oauth">認証開始</a>

@@ oauth_callback
<ul>
  <li>access_token: <%= access_token.params[:oauth_token] %></li>
  <li>access_token_secret: <%= access_token.params[:oauth_token_secret] %></li>
</ul>
