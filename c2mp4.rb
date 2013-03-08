#!/usr/local/bin/ruby
POPDBG = true
class C2mp4
	@@usage = "USAGE: #{File.basename(__FILE__)} source destination"
	
	def exec_ffmpeg opts
		st = Time.now
		puts "ffmpeg %s @ %s" % [opts, st]
		puts "press 'q' to quit"
		progress = nil
		dur_secs = nil
		frame_rate = nil
		frames = 0
		dur_str = '00:00:00.000'
		ostr = ''
		hit_time = Time.now
		ffmpeg_log = []
		ffmpeg = IO.popen("ffmpeg " + opts + " 2>&1")
		ffmpeg.each("\r") do |line|
			ffmpeg_log << line + "\r"
			if((Time.now - hit_time).to_f > 30.0)
				begin
					puts " "
					ostr = "Timeout: %s" % [line.strip]
					print ostr + ("\b" * (ostr.length + 4)) 
				rescue
				end
			end
			if dur_secs == nil && line =~ /Duration:\s*(\d*):(\d*):(\d*\.\d*)/
				dur_str = $1.to_s + ":" + $2.to_s + ":" + $3.to_s
				dur_secs = ($3.to_f + ($2.to_i * 60).to_f + ($1.to_i * 3600).to_f)
				puts "Video Duration:" + dur_str + "(" + dur_secs.to_s + " secs)"
			end
			if frame_rate == nil 
				if line.strip =~ /Stream.+\, (\d+\.{0,1}\d{0,3}) fps\,/ or line =~ /Stream.+\, (\d+\.{0,1}\d{0,3}) tbc$/
					frame_rate = $1.to_f
					frames = dur_secs * frame_rate
					puts "Total Frames: %i" % frames.to_i
					puts "Frame Rate: %.3f fps" % frame_rate
				end
			end
			if line =~ /frame=\s*(\d*)/
				cframe = $1.to_i
				csecs = 0
				if line =~ /time=\s*(\d*):(\d*):(\d*\.\d*)/
					csecs = ($3.to_f + ($2.to_i * 60).to_f + ($1.to_i * 3600).to_f)
					csecs_str = $1.to_s + ":" + $2.to_s + ":" + $3.to_s
				elsif line =~ /time=\s*(\d*\.\d*)/
					csecs $1.to_f
					t = Time.at(csecs).gmtime
					csecs_str = "%0.2i:%0.2i:%0.2i.%3i" % [t.hour, t.min, t.sec, t.nsec]
				end
				if line =~ /fps=\s*(\d*)/
					cfps = $1.to_i
				else
					cfps = 0
				end
				if line =~ /bitrate=\s*(\d*\.\d*kbits)/
					br = $1
				else
					br = "???"
				end
				hit_time = Time.now
				rt = Time.at(0.0).gmtime
				if(cfps != 0)
					rt = Time.at(((frames.to_f-cframe.to_f)/cfps.to_f).to_f).gmtime
				end
				ostr = "  %3.2f%% ( %s ) @frame:%i fps:%i bitrate:%s (~%s) " % 
					[((csecs/dur_secs)*100), csecs_str, cframe, cfps, br, rt.strftime("%H:%M:%S.%3N")]
				print ostr + ("\b" * (ostr.length + 4))
			end
		end
		Process.wait
		#ffmpeg.close
		rtn = false
		tt = Time.at(Time.now - st).gmtime
		if($?.exitstatus == 0)
			puts ("SUCCESS: %s" + (" " * (ostr.length+4))) % [tt.strftime("%H:%M:%S.%3N")]
			rtn = true
		else
			puts ("FAILURE: %s - Exit code: %s" + (" " * (ostr.length+4))) % [tt.strftime("%H:%M:%S.%3N"), $?.exitstatus.to_s]
			puts "enter \"d\" to dump log, otherwise hit <enter> to exit."
			choice = $stdin.gets
			if(choice.strip == "d")
				puts ffmpeg_log.join
			end
			rtn = false
		end
		return rtn
	end
	
	def initialize
		puts "|----------------------------- c2mp4 -----------------------------|"
		puts "|                 Convert file to mp4 with ffmpeg                 |"
		puts "|*****************************************************************|"

		if ARGV.length == 1 or ARGV.length == 2
			@src_paths = Dir[ARGV[0]]
			if(@src_paths.length == 0)
				if(File.exists? ARGV[0])
					@src_paths = Array.new ARGV[0]
					if ARGV.length == 1
						ARGV[1] = "%s.mp4" % ARGV[0].chomp(File.extname(ARGV[0]))
					end
					dst_path = ARGV[1].clone
					i = 0;while File.exists? dst_path; dst_path = "%s(%i).mp4" % [ARGV[1].chomp(File.extname(ARGV[1])), i=i+1] end
					@dst_paths = Array.new dst_path
				else
					raise "SRC FILE DOES NOT EXIST! \"%s\"" % @src_path
				end
			else
				if(ARGV.length == 1)
					dst_dir_path = File.dirname(ARGV[0])
				else
					if(!File.directory? ARGV[1])
						raise "If using a glob, then destination MUST be a directory."
					end
					dst_dir_path = ARGV[1]
				end
				@dst_paths = Array.new
				@src_paths.each do |src_path|
					dst_path = "%s/%s.mp4" % [dst_dir_path.gsub(/\/$/, ''), File.basename(src_path).chomp(File.extname(src_path))]
					i = 0;while File.exists? dst_path; dst_path = "%s/%s(%i).mp4" % [dst_dir_path, File.basename(src_path).chomp(File.extname(src_path)), i=i+1] end
					@dst_paths << dst_path
				end	
			end
		else
			raise @@usage
		end
	end
	
	def main
		puts " Converting:"
		i = 0
		while i < @src_paths.length
			puts "  %s -> %s" % [@src_paths[i], @dst_paths[i]]
			i = i + 1
		end
		i = 0
		while i < @src_paths.length
			puts "%s %i of %i" % [@src_paths[i], i+1, @src_paths.length]
			opts = "-i \"%s\" -acodec libfaac -ac 2 -ab 128k -vcodec libx264 -threads 0 \"%s\"" %
								[@src_paths[i], @dst_paths[i]]
			if exec_ffmpeg opts
				puts "SUCCESS"
			else
				puts "FAILURE"
			end
			i = i + 1
		end		
	end
end

begin
	C2mp4.new.main
rescue => e
	puts e.message
	if(POPDBG)
		e.backtrace.each do |msg| puts "    " + msg end
	end
end
