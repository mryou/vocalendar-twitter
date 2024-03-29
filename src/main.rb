#! /usr/local/bin/ruby
# -*- encoding: utf-8 -*-
#
# Vocalendar bot | Twitter Developers
# https://dev.twitter.com/apps/1995843/show

require 'rubygems';
require 'net/https';
require 'uri';
require 'rexml/document';
require 'date'
require 'active_support'
require 'twitter'
require 'pp'


# Proxy設定（不要なら、proxy_hostをnilに設定
proxy_host = nil;
proxy_port = 8080;

# 認証設定
consumer_key = '';
consumer_secret = '';
oauth_token = '';
oauth_token_secret = '';


Net::HTTP.version_1_2;

# 現在時間、いつからいつまでの予定を呟き対象とするかの時間
now = DateTime.now()
totime = now + Rational(1, 24) * 4
fromtime = totime - Rational(1, 24 * 60 ) * 10

puts '----- start -----'
puts now
puts fromtime
puts totime

# カレンダーの予定の取得条件
# 左から、開始時刻順、現在時刻からの予定、昇順、繰り返し予定を1つずつ取得
query_hash = { 'orderby' => 'starttime', 'start-min' => now.new_offset.strftime('%FT%T'), 'sortorder' => 'a', 'singleevents' => 'true'};
query_string = query_hash.map{ |key,value|
	"#{URI.encode(key)}=#{URI.encode(value)}" }.join("&");

res = nil;

begin

	# Google Feedを利用して予定を取得
	https = Net::HTTP::Proxy( proxy_host, proxy_port).new('www.google.com', 443);
	https.use_ssl = true;
	https.verify_mode = OpenSSL::SSL::VERIFY_NONE;
	https.verify_depth = 5;
	https.start {
		res = https.get('/calendar/feeds/0mprpb041vjq02lk80vtu6ajgo@group.calendar.google.com/public/full?' + query_string).body;
	}

rescue Exception
  puts $!;
end

# XMLをパース
document = REXML::Document.new(res);
if document.elements.to_a('feed/entry').size == 0 then
	# つぶやきがなければ終了
	puts "対象なし";
	exit(true);
end

# Twitter ログイン
Twitter.configure do |config|
  config.consumer_key = consumer_key;
  config.consumer_secret = consumer_secret;
  config.oauth_token = oauth_token
  config.oauth_token_secret = oauth_token_secret
  if proxy_host != nil then
	  config.proxy = 'http://' + proxy_host + ':' + proxy_port.to_s
  end
end

# 予定の数だけ繰り返す
document.elements.each('feed/entry') do |entry|

	title = entry.elements['title'].text;

	time = entry.elements['gd:when'];

	url = '';
	entry.elements.each('link') do |link|
		if link.attributes['rel'] == 'alternate' then
			url = link.attributes['href'];
		end

	end

	starttimeStr = time.attributes['startTime'];
	endtimeStr = time.attributes['endTime'];
	timeEvent = starttimeStr.count('T') > 0;
	if !timeEvent then
		starttimeStr = starttimeStr + 'T00:00:00+09:00';
	end
	starttime = DateTime.rfc3339(starttimeStr);

	puts title;
	puts starttime;
	puts url;

	if fromtime < starttime and starttime <= totime then

		tweetsStr = nil;
		puts 'つぶやき対象';
		if timeEvent then
			tweetsStr = starttime.strftime('%F %T') + 'は、' + title + 'の予定がありますよ。 ' + url + ' #vocalendar';
		else
			tweetsStr = starttime.strftime('%F') + 'は、' + title + 'の予定がありますよ。 ' + url + ' #vocalendar';
		end

		Twitter.update(tweetsStr);

	end

#	Twitter.update("テスト(´ー｀)")


end
