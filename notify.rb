##
# Credit to Carlos Perez for the foundation of this - it's a Frankenstein of an old, simialr plugin of his
# Before you get started, run: gem install slack-notifier
# Then add this line to the metasploit-framework.gemspec file
# Near the top, under "spec.require_paths = ["lib"]"
# spec.add_runtime_dependency 'slack-notifier'
##
require 'slack-notifier'

module Msf

	class Plugin::Notify < Msf::Plugin
		include Msf::SessionEvent

		# Checks if the constant is already set, if not it is set
		if not defined?(Notify_yaml)
			Notify_yaml = "#{Msf::Config.get_config_root}/Notify.yaml"
		end

		# Initialize the Class
		def initialize(framework, opts)
			super
			add_console_dispatcher(NotifyDispatcher)
		end

		# Cleans up the event subscriber on unload
		def cleanup
			self.framework.events.remove_session_subscriber(self)
			remove_console_dispatcher('notify')
		end

		# Sets the name of the plugin
		def name
			"notify"
		end

		# Sets the description of the plugin
		def desc
			"Automatically send Slack notifications when sessions are created and closed"
		end

		# Notify Dispatcher Class
		class NotifyDispatcher
			include Msf::Ui::Console::CommandDispatcher

			@webhook_url =  nil
			@user_name = nil

			# Action for when a session is created
			def on_session_open(session)
				print_status("Session received, sending push notification")
				sendslack("Source: #{@source} Session: #{session.sid} IP: #{session.session_host} Peer: #{session.tunnel_peer} Platform: #{session.platform} Type: #{session.type}")
				return
			end

			# Action for when the session is closed
			def on_session_close(session,reason = "")
				begin
					print_status("Session:#{session.sid} Type:#{session.type} is shutting down")
					sendslack()"Bad news about session... Source: #{@source} Session:#{session.sid} Type:#{session.type} is shutting down")
				rescue
					return
				end
				return
			end

			# Name of the Plug-In
			def name
				"notify"
			end

			def sendslack(message)
				notifier = Slack::Notifier.new @webhook_url, channel: @user_name, username: 'Meterpreter Helper'
				notifier.ping message
		 end

			# Reads and set the valued from a YAML File
			def read_settings
				read = nil
				if File.exist?("#{Notify_yaml}")
					ldconfig = YAML.load_file("#{Notify_yaml}")
					@webhook_url = ldconfig['webhook_url']
					@user_name = ldconfig['user_name']
					read = true
				else
					print_error("You must create a YAML File with the options")
					print_error("as: #{Notify_yaml}")
					return read
				end
				return read
			end

			# Sets the commands for the Plug-In
			def commands
				{
					'notify_help'								=> "Displays help",
					'notify_start'							=> "Start Notify Plugin after saving settings.",
					'notify_stop'								=> "Stop monitoring for new sessions.",
					'notify_test'								=> "Send test message to make sure confoguration is working.",
					'notify_save'								=> "Save Settings to YAML File #{Notify_yaml}.",
					'notify_set_webhook'				=> "Sets Slack Webhook URL.",
					'notify_set_user'						=> "Set Slack username for messages.",
					'notify_show_parms'			   	=> "Shows currently set parameters."

				}
			end

			# Help Command
			def cmd_notify_help
				puts "Run notify_set_user and notify_set_webhook to setup Slack config. Then run notify_save to save them for later. Use notify_test to test your config and load it from the YAML file in the future. Finally, run notify_start when you have your listener setup."
			end

			# Re-Read YAML file and set Slack Web API Configuration
			def cmd_notify_start
				print_status "Session activity will be sent to you via Slack Webhooks"
				if read_settings()
					self.framework.events.add_session_subscriber(self)
					notifier = Slack::Notifier.new @webhook_url, channel: @user_name, username: 'Meterpreter Helper'
					print_good("Notify Plugin Started, Monitoring Sessions")
				else
					print_error("Could not set Slack Web API settings.")
				end

			end

			def cmd_notify_stop
				print_status("Stopping the monitoring of sessions to Slack")
				self.framework.events.remove_session_subscriber(self)
			end

			def cmd_notify_test
				print_status("Sending tests message")
				if read_settings()
					self.framework.events.add_session_subscriber(self)
					notifier = Slack::Notifier.new @webhook_url, channel: @user_name, username: 'Meterpreter Helper'
					notifier.ping "Metasploit is online! Hack the Planet!"
				else
					print_error("Could not set Slack Web API settings.")
				end

			end

			# Save Parameters to text file
			def cmd_notify_save
				print_status("Saving paramters to config file")
				if @user_name and @webhook_url
					config = {'user_name' => @user_name, 'webhook_url' => @webhook_url}
					File.open(Notify_yaml, 'w') do |out|
						YAML.dump(config, out)
					end
					print_good("All parameters saved to #{Notify_yaml}")
				else
					print_error("You have not provided all the parameters!")
				end
			end

			# Get user key
			def cmd_notify_set_user(*args)
				if args.length > 0
					print_status("Setting the Slack handle to #{args[0]}")
					@user_name = args[0]
				else
					print_error("Please provide a value")
				end
			end

			# Get app key
			def cmd_notify_set_webhook(*args)
				if args.length > 0
					print_status("Setting the Webhook URL to #{args[0]}")
					@webhook_url = args[0]
				else
					print_error("Please provide a value")
				end
			end


			# Show the parameters set on the Plug-In
			def cmd_notify_show_parms
				print_status("Parameters:")
				print_good("Webhook URL: #{@webhook_url}")
				print_good("Slack User: #{@user_name}")
			end


		end
	end
end
