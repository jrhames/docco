###
# GitHub Styled File Browser
# (c) Copyright 2012 Baoshan Sheng
###

# ## (Underscore) Template for Breadcrumb Navigation
breadcrumb_template = _.template [
  '<% _.each(path, function(dir, i) { %>'
  '<%   if (i < path.length - 1) { %>'
  '<a depth=<%= i %>><%- dir %></a>&nbsp;/'
  '<%   } else { %>'
  '&nbsp;<span><%- dir %></span>'
  '<%   } %>'
  '<% }) %>'
].join ''

# ## (Underscore) Template for Content Table
list_template = _.template [
  '<table depth="<%= index_depth %>">'
  '<thead><tr><td></td><td>name</td><td>size</td><td></td><td>age</td><td>author</td><td>message</td></tr></thead>'
  '<tbody>'
  '<% if(index_depth) { %>'
  '<tr class="directory"><td></td><td><a backward>..</a></td></tr>'
  '<% } %>'
  '<% _.each(entries, function(entry) { %>'
  '<tr class="<%= entry.type %>">'
  '<td class="icon"></td>'
  '<td><a '
  "<%= entry.type == 'directory' ? 'forward' :
    'href=\"' + (entry.documented ? (relative_base ? relative_base + '/' : '') + entry.document : 'https://github.com/' + user + '/' + repo + '/blob/master/' + (absolute_base ? absolute_base + '/' : '') + entry.name) + '\"' %>"
  '><%- entry.name %></a></td>'
  '<td><%- entry.type == "file" ? entry.size : "-" %></td>'
  '<td><%- isNaN(entry.sloc) ? "" : ("(" + entry.sloc + " lines)") %></td>'
  '<td><%- entry.modified %></td>'
  '<td><%- entry.author   %></td>'
  '<td><%- entry.subject  %></td>'
  '</tr>'
  '<% }); %>'
  '</tbody>'
  '</table>'
].join ''

# ## Constructor Arguments
#
# 1. `user`, used to generate correct link for undocumented sources. E.g.,
# `https://github.com/user/repo/blob/master/awesome_file`
# 2. `repo`, also used to generate above link.
# 3. `index_path`, path to `docas.index` file.
# 4. `index_depth`, the depth of the index file, `0` for root directory of the repo.
# 5. `current_depth`, optional, the depth of the current page, defaults to
# `index_depth`.
file_browser = (user, repo, index_path, index_depth = 0, current_depth = index_depth) ->

  # ### Ajax Call to Get Index
  $.get index_path, (index) ->

    # ## Breadcrumb Navigation
    breadcrumb_path  = index_path.split '/'
    breadcrumb_end   = breadcrumb_path.length - 2
    breadcrumb_start = breadcrumb_end - index_depth + 1
    breadcrumb_path  = breadcrumb_path[breadcrumb_start..breadcrumb_end]

    # ### Render Breadcrumb Navigator
    $('#breadcrumb').html breadcrumb_template
      path: [repo, breadcrumb_path...]

    # ### Handling Breadcrumb Navigation
    $('#breadcrumb a').click ->
      new_depth = $(@).attr('depth') * 1
      new_path = index_path.split '/'
      new_path.splice index_path.length - index_depth + new_depth - 1, index_depth - new_depth
      new file_browser user, repo, new_path.join('/'), new_depth, current_depth

    # ## Content Table

    # `absolute_base` is used to generate github.com links for undocumented sources.
    absolute_base = breadcrumb_path.join '/'

    # `relative_base` is used to generate links for documented sources.
    depth_offset  = index_depth - current_depth
    if depth_offset > 0
      relative_base = breadcrumb_path[breadcrumb_path.length - depth_offset..].join '/'
    else
      relative_base = new Array(-depth_offset + 1).join '../'

    # ### Render Content Table
    table = $ list_template
      user          : user
      repo          : repo
      index_depth   : index_depth
      absolute_base : absolute_base
      relative_base : relative_base
      entries       : process_index index

    # ### Handling Folder Navigation
    $(table).find('a[backward]').click ->
      new_path = index_path.split '/'
      new_path.splice new_path.length - 2, 1
      new file_browser user, repo, new_path.join('/'), index_depth - 1, current_depth
    $(table).find('a[forward]').click ->
      new_path = index_path.split '/'
      new_path.splice new_path.length - 1, 0, $(@).html()
      new file_browser user, repo, new_path.join('/'), index_depth + 1, current_depth

    # ### Pushing / Poping the Table
    current_table = $('#filelist table:first-child')[0]
    if current_table
      direction = if index_depth > parseInt $(current_table).attr('depth') then 1 else -1
      width = $('#filelist table').width()
      table.css 'left', direction * width
      $('#filelist')[if direction < 0 then 'prepend' else 'append'] table
      $('#filelist').children().animate
        left: (if direction is -1 then '+' else '-') + '=' + width
      , -> $(current_table).remove()
    else
      $('#filelist').append table

process_index = (index) ->
  lines = index.split('\n').filter((line) -> line)
  entries = []
  _.each lines, (line) ->
    # Sample lines:
    #
    #   "-","57","Mon, 23 Apr 2012 15:40:04 +0800","Me","Initial Commit","<.gitignore>","0","-"
    #   "-","0","Mon, 23 Apr 2012 15:40:04 +0800","Me","Bootstrap","<app.js>","1","0"
    #   "d","204","Fri, 27 Apr 2012 19:50:34 +0800","Me","First Build","<bin>","0","-"
    match = line.match /"(d|-)","(\d+)","([^"]+)","(.+)","(.+)","<(.+)>","(0|1)","(\d+|-)"/
    return unless match
    entry =
      type       : if match[1] is 'd' then 'directory' else 'file'
      size       : filesize (parseInt match[2], 10), 0
      modified   : moment(new Date match[3]).fromNow()
      author     : match[4]
      subject    : match[5]
      name       : match[6]
      documented : match[7] is '1'
      sloc       : parseInt match[8], 10
    # Replace source extension for `.html` to get document file name.
    entry.document = entry.name.replace(/\.[^/.]+$/, '') + '.html' if entry.documented
    # For hidden file without extension.
    entry.document = entry.name + '.html' if entry.document is '.html'
    entries.push entry
  _.sortBy entries, (entry) -> [entry.type, entry.name]

# Expose the constructor globally.
@file_browser = file_browser