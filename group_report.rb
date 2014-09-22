require 'csv'
require 'date'
require 'optparse'

module Helper
	def init_from_params args
		args.each {|k,v| send("#{k}=", v)}
	end
end

class User
	include Helper
	attr_accessor :id, :created_at, :updated_at

	def initialize args
		init_from_params args
	end
end

class Order
	include Helper
	attr_accessor :id, :order_num, :user_id, :created_at, :updated_at

	def initialize args
		init_from_params args   
  end
end

class Report
	def initialize (n = 8)
		@max_weeks = n
		load_data
	end

	# todo. maybe later deal with utc/pst affair
	def cohorts
		return @cohorts if defined?(@cohorts)

		@cohorts = users.values.group_by {|u| u.created_at.cweek }
	end

	def first_time_orders_by_week
		return @first_time_orders_by_week if defined?(@first_time_orders_by_week)

		@first_time_orders_by_week = {}.tap do |hsh|
			user_orders_by_elapsed_week.each do |k,v|
				hsh[k] = v.keys.min
			end
		end
	end

	# { user_id => [array of orders] }
	def user_orders
		return @user_orders if defined?(@user_orders)

		@user_orders = orders.group_by {|o| o.user_id }
	end

	# { user_id => { elapsed_week => [array of order] } }
	def user_orders_by_elapsed_week
		return @user_orders_by_elapsed_week if defined?(@user_orders_by_elapsed_week)

		@user_orders_by_elapsed_week = {}.tap do |order|
			user_orders.each do |k,v|
				order[k] = v.group_by do |x|
					@users.has_key?(x.user_id) ? (x.created_at - @users[x.user_id].created_at).to_i / 7 : nil
				end.delete_if {|k,v| k.nil? }
			end
		end
	end

	def export
		CSV.open('group_stats.csv', 'w' ) do |csv|
			summary_header = (0..@max_weeks).map {|x| "#{7*x}-#{7*(x+1)} days"}
			csv << ['Cohort','Users'].concat(summary_header)
		  
		  cohorts.keys.sort.reverse.each do |k|
		  	grp = cohorts[k]
			  summary = group_stats(grp).map {|x| "#{percent(x[:orderers],grp.size)} orderers (#{x[:orderers]}) - #{percent(x[:firsttimers],grp.size)} 1st time (#{x[:firsttimers]})" }
			  cohort_date = [Date.commercial(2013,k,1).strftime("%-m/%-d"),Date.commercial(2013,k,7).strftime("%-m/%-d")]

		    csv << ["#{cohort_date.join('-')}","#{grp.size} users"].concat(summary)
		  end
		end
	end


	private
	def load_data
		users
		orders
	end

	def users
		return @users if defined?(@users)
		
		@users = {}.tap do |u|
			load_from_csv("users.csv") do |entry|
				# u[entry["id"]] = User.new(entry)
				u[entry["id"]] = User.new({
					:id => entry["id"],
					:created_at => parse_date(entry["created_at"]),
					:updated_at => parse_date(entry["updated_at"])
				})
			end
		end
	end

	def orders
		return @orders if defined?(@orders)

		@orders = [].tap do |ary|
			load_from_csv("orders.csv") do |entry|
				# ary << Order.new(entry)
				ary << Order.new({
					:id => entry["id"],
					:order_num => entry["order_num"],
					:user_id => entry["user_id"],
					:created_at => parse_date(entry["created_at"]),
					:updated_at => parse_date(entry["updated_at"])
				})
			end
		end
	end

	def load_from_csv(filename)
		CSV.foreach(filename, :headers => true) do |row|
			yield row if block_given?
		end
	end
	
	def group_stats(grp)
		(0..@max_weeks).map do |b|
			grp.inject({:orderers => 0, :firsttimers => 0}) do |hsh, i|
				if (user_orders_by_elapsed_week.has_key?(i.id) && user_orders_by_elapsed_week[i.id].has_key?(b))
					hsh[:orderers] += 1					
				end

				if (first_time_orders_by_week[i.id] == b)
					hsh[:firsttimers] += 1
				end

				hsh
			end
		end
	end

	def percent(x,y)
		sprintf('%.2f%', x.to_f / y * 100)
	end

	def parse_date(d)
		Date.strptime(d, "%m/%d/%Y %H:%M:%S")
	end
end


options = {:max_weeks => 8}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby group_report.rb [options]"

  opts.on("-w", "--weeks weeks", "Max Weeks since sign up to analyze") do |w|
  	options[:max_weeks] = w.to_i
  end

  opts.on("-h", "--help [HELP]", "Help") do |h|
  	puts opts.help
  	exit
  end
end.parse!

x = Report.new(options[:max_weeks] - 1)
x.export














