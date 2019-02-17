require 'parallel'

def gui_file_finder()
    l = []
    $select_keys = ['h', 'l', 'f', 'd', 's', 'a', 'g', 'z']
    #Thread.new{recursively_find_files}
    if $dir_list==nil
        #        recursively_find_files
        $dirlt = Thread.new{recursively_find_files()}
        # t2 = Thread.new{1e6.to_i.times{|x| puts "Sleep #{x}"; 1e8.to_i.times{|y|y*3};sleep(1);$footest=1}}
        #        t.join
        #sleep(3.05)
    end
    qt_select_update_window(l,$select_keys.collect {|x| x.upcase},
    "gui_file_finder_select_callback",
    "gui_file_finder_update_callback")
    #method(:gui_file_finder_update_callback))
end

def update_file_index()
    message("Start updating file index")
    Thread.new{
        recursively_find_files()
        message("Finnish updating file index")
    }
end

def recursively_find_files()
    debug("START find files")
    dlist=[]
    
    for d in $search_dirs
        debug("FIND FILEs IN #{d}")
        dlist = dlist + Dir.glob("#{d}/**/*").select { |e| File.file?(e) and $find_extensions.include?(File.extname(e))}
        debug("FIND FILEs IN #{d} END")
    end
    #$dir_list = Dir.glob('./**/*').select { |e| File.file? e }
    debug("END find files2")
    $dir_list = dlist
    debug("END find files")
    return $dir_list
end

def filter_files(search_str)
    #dir_list = Dir.glob('/home/sjs/notes/**/*').select{ |e| File.file? e }
    #puts dir_list.inspect
    dir_hash = {}
    if false
        for file in $dir_list

            #d = srn_dst(search_str, File.basename(file))
            #d = srn_dst(search_str, file)
            d = 0
            if d > 0
                dir_hash[file] = d
                #puts "D:#{d} #{file}" 
            end
        end
    end
    scores = Parallel.map($dir_list, in_threads: 8) do |file|
        [file, srn_dst(search_str, file)]
    end
    for s in scores
        dir_hash[s[0]] = s[1]  if s[1] > 0
    end
    # puts scores
    #puts dir_hash
    dir_hash = dir_hash.sort_by{|k, v| -v}
    dir_hash = dir_hash[0..20]
    #puts dir_hash
    dir_hash.map  do |file, d|
        puts "D:#{d} #{file}"
    end
    #    Ripl.start :binding => binding
    return dir_hash
end



def gui_file_finder_update_callback(search_str = "")
    puts "FILE FINDER UPDATE CALLBACK: #{search_str}"
    if (search_str.size > 1)
        files = filter_files(search_str)
        $file_search_list = files
        return files
        #puts files.inspect
        #return files.values
    end
    return []
end

def gui_file_finder_select_callback(search_str)
    selected_file = $file_search_list[0][0]
    puts "FILE FINDER SELECT CALLBACK: #{search_str}: #{selected_file}"
    qt_select_window_close(0)
    new_file_opened(selected_file)

end


def gui_file_finder_handle_char(c)
    puts "BUFFER SELECTOR INPUT CHAR: #{c}"
    buffer_i = $select_keys.index(c)
    if buffer_i != nil
        gui_file_finder_callback(buffer_i)
    end
end

def gui_file_finder_init()
    $at.add_mode('Z')
    bindkey 'Z enter', '$at.set_mode(COMMAND)'
    bindkey 'Z return', '$at.set_mode(COMMAND)'
    #bindkey 'S j', '$at.set_mode(COMMAND)'
    #bindkey 'S /[hlfdsagz]/', 'gui_file_finder_handle_char(<char>)'
    #bindkey 'Z <char>', 'gui_file_finder_handle_char(<char>)'
end
