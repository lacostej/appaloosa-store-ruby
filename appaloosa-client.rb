#!/usr/bin/ruby
#
# a ruby appaloosa client
#
# inspired by https://github.com/jenkinsci/appaloosa-plugin/blob/master/src/main/java/com/appaloosastore/client/AppaloosaClient.java

require 'rubygems'
require 'mechanize'
require 'json'
require 'logger'
require 'pathname'


token=ARGV[0]
file=ARGV[1]

class Appaloosa 

  def initialize
    @agent = Mechanize.new
    #@agent.log = Logger.new "appaloosa.log"
    
    @baseUrl = "https://www.appaloosa-store.com"
  end
  
  class NotificationUpdate
    def initialize(json)
      @json = json
    end
    def json
      @json
    end
    def id
      @json['id']
    end
    def status
      return -1 if @json['status'].nil?
      @json['status'].to_i
    end
    def application_id
      @json['application_id']
    end
    def status_message
      @json['status_message']
    end
    def hasError
      status > 4
    end
    def to_s
      @json.to_json
    end
    def isProcessed
      hasError() or (!application_id.nil? and application_id != '')
    end
  end
  
  def deployFile(token, file)
    uploadForm = getUploadForm(token)
    uploadFile(file, uploadForm)
    notification = notifyAppaloosaForFile(file, token, uploadForm)
    #puts notification.json
    while (!notification.isProcessed())
      sleep 1
      print "."
      notification = getNotificationUpdate(notification.id, token)
    end
    puts ""
    if (notification.hasError)
      puts "ERROR: deploying #{file} #{notification.status} #{notification.status_message}"
      return
    end
    notification = publish(notification, token)
    puts "INFO: file #{file} deployed #{notification}"    
    notification
  end
  
  def publish(notification, token)
    r = @agent.post("#{@baseUrl}/api/publish_update.json", {
      "token" => token,
      "id" => notification.id.to_s
    })
    NotificationUpdate.new(JSON r.content)
  end
  
  def getNotificationUpdate(id, token)
    url = "#{@baseUrl}/mobile_application_updates/#{id}.json?token=#{token}"
    form = @agent.get(url).content
    json = JSON form
    return NotificationUpdate.new(json)
  end
  
  def getUploadForm(token)
    form = @agent.get("#{@baseUrl}/api/upload_binary_form.json?token=#{token}").content
    JSON form
  end
  
  def uploadFile(file, json)
    r = @agent.post(json['url'], {
      "policy" => json['policy'],
      "success_action_status" => json['success_action_status'],
      "Content-Type" => json['content_type'],
      "signature" => json['signature'],
      "AWSAccessKeyId" => json['access_key'],
      "key" => json['key'],
      "acl" => json['acl'],
      "file" => File.new(file)
    })
  end
  
  def notifyAppaloosaForFile(file, token, json)
    key = json['key']
    key["${filename}"] = Pathname.new(file).basename.to_s
    r = @agent.post("#{@baseUrl}/api/on_binary_upload", {
      "token" => token,
      "key" => key
    })
    NotificationUpdate.new(JSON r.content)
  end
end
  
store = Appaloosa.new
store.deployFile(token, file)

