function csc_eeg_plotter()

%TODO: Main page 
        %Scale - green lines across one of the channels
        %Video scroll with space bar - reasonable speed - pause/play?
        %Auto adjust time scale on bottom for whole night
        %left side epoch length/scale boxes
        %top center box stating what is in the epoch (much like sleep scoring)
        %highlight spikes, makes tick below
        %Scoring axis
            %ticks or mapping (like sleep scoring) only marked seizure, spike, artifact
        %Display button? way to visualize event related EEG data while scoring?
        %Options button? channel/window length and print button

%TODO: Montage
        %Green line in front of headset
        %headset electrodes smaller due to poor resolution on my computer

% make a window
% ~~~~~~~~~~~~~
handles.fig = figure(...
    'name',         'csc EEG Plotter',...
    'numberTitle',  'off',...
    'color',        [0.1, 0.1, 0.1],...
    'menuBar',      'none',...
    'units',        'normalized',...
    'outerPosition',[0 0.04 .5 0.96]);

% make the axes
% ~~~~~~~~~~~~~
% main axes
handles.main_ax = axes(...
    'parent',       handles.fig             ,...
    'position',     [0.05 0.2, 0.9, 0.75]   ,...
    'nextPlot',     'add'                   ,...
    'color',        [0.2, 0.2, 0.2]         ,...
    'xcolor',       [0.9, 0.9, 0.9]         ,...
    'ycolor',       [0.9, 0.9, 0.9]         ,...  
    'ytick',        []                      ,...
    'fontName',     'Century Gothic'        ,...
    'fontSize',     8                       );

% navigation/spike axes
handles.spike_ax = axes(...
    'parent',       handles.fig             ,...
    'position',     [0.05 0.075, 0.9, 0.05] ,...
    'nextPlot',     'add'                   ,...
    'color',        [0.2, 0.2, 0.2]         ,...
    'xcolor',       [0.9, 0.9, 0.9]         ,...
    'ycolor',       [0.9, 0.9, 0.9]         ,...   
    'ytick',        []                      ,...   
    'fontName',     'Century Gothic'        ,...
    'fontSize',     8                       );

% invisible name axis
handles.name_ax = axes(...
    'parent',       handles.fig             ,...
    'position',     [0 0.2, 0.1, 0.75]   ,...
    'visible',      'off');


% create the uicontextmenu for the main axes
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
handles.selection.menu = uicontextmenu;
handles.selection.item(1) = uimenu(handles.selection.menu,...
    'label', 'event 1');
set(handles.main_ax, 'uicontextmenu', handles.selection.menu);
set(handles.selection.item(1),...
    'callback',     {@cb_event_selection, 1});

% create the menu bar
% ~~~~~~~~~~~~~~~~~~~
handles.menu.file       = uimenu(handles.fig, 'label', 'file');
handles.menu.load       = uimenu(handles.menu.file,...
    'Label', 'load eeg',...
    'Accelerator', 'l');
handles.menu.save       = uimenu(handles.menu.file,...
    'Label', 'save eeg',...
    'Accelerator', 's');

handles.menu.montage    = uimenu(handles.fig, 'label', 'montage', 'enable', 'off');

handles.menu.events     = uimenu(handles.fig, 'label', 'events', 'accelerator', 'v');

handles.menu.options    = uimenu(handles.fig, 'label', 'options');
handles.menu.disp_chans = uimenu(handles.menu.options,...
    'label', 'display channels',...
    'accelerator', 'd');
handles.menu.epoch_length = uimenu(handles.menu.options,...
    'label', 'epoch length',...
    'accelerator', 'e');


% scale indicator
% ~~~~~~~~~~~~~~~
handles.txt_scale = uicontrol(...
    'Parent',   handles.fig,...
    'Style',    'text',...
    'String',   '100',...
    'Visible',  'off',...
    'Value',    100);


% hidden epoch tracker
% ````````````````````
handles.cPoint = uicontrol(...
    'Parent',   handles.fig,...
    'Style',    'text',...
    'Visible',  'off',...
    'Value',    1);

% set the callbacks
% ~~~~~~~~~~~~~~~~~
set(handles.menu.load,      'callback', {@fcn_load_eeg});
set(handles.menu.montage,   'callback', {@fcn_montage_setup});
set(handles.menu.events,    'callback', {@fcn_event_browser});


set(handles.menu.disp_chans,   'callback', {@fcn_options, 'disp_chans'});
set(handles.menu.epoch_length, 'callback', {@fcn_options, 'epoch_length'});

set(handles.fig,...
    'KeyPressFcn', {@cb_key_pressed,});

set(handles.spike_ax, 'buttondownfcn', {@fcn_time_select});

guidata(handles.fig, handles)


function fcn_load_eeg(object, ~)
% get the handles structure
handles = guidata(object);

% load dialog box with file type
[dataFile, dataPath] = uigetfile('*.set', 'Please Select Sleep Data');

% just return if no datafile was actually selected
if dataFile == 0
    fprintf(1, 'Warning: No file selected \n');
    return;
end

% load the files
% ``````````````
% load the struct to the workspace
load([dataPath, dataFile], '-mat');
if ~exist('EEG', 'var')
    fprintf('Warning: No EEG structure found in file\n');
    return;
end

% memory map the actual data...
tmp = memmapfile(EEG.data,...
                'Format', {'single', [EEG.nbchan EEG.pnts EEG.trials], 'eegData'});
eegData = tmp.Data.eegData;

% set the name
set(handles.fig, 'name', ['csc: ', dataFile]);

% check for the channel locations
if isempty(EEG.chanlocs)
    if isempty(EEG.urchanlocs)
        fprintf(1, 'Warning: No channel locations found in the EEG structure \n');
    else
        fprintf(1, 'Information: Taking the EEG.urchanlocs as the channel locations \n');
        EEG.chanlocs = EEG.urchanlocs;
    end
end

% check for previous
if ~isfield(EEG, 'csc_montage')
    % assign defaults
    EEG.csc_montage.display_channels    = 12;
    EEG.csc_montage.epoch_length        = 30;
    EEG.csc_montage.label_channels      = cell(EEG.csc_montage.display_channels, 1);
    EEG.csc_montage.label_channels(:)   = deal({'undefined'});
    EEG.csc_montage.channels(:,1)       = [1:EEG.csc_montage.display_channels]';
    EEG.csc_montage.channels(:,2)       = size(eegData, 1);
    EEG.csc_montage.filter_options      = [0.5; 30]';
end
    
% update the handles structure
guidata(handles.fig, handles)
% use setappdata for data storage to avoid passing it around in handles when not necessary
setappdata(handles.fig, 'EEG', EEG);
setappdata(handles.fig, 'eegData', eegData);

% turn on the montage option
set(handles.menu.montage, 'enable', 'on');

% plot the initial data
plot_initial_data(handles.fig)


function plot_initial_data(object)
% get the handles structure
handles = guidata(object);

% get the data
EEG = getappdata(handles.fig, 'EEG');
eegData = getappdata(handles.fig, 'eegData');

% select the plotting data
range       = 1:EEG.csc_montage.epoch_length*EEG.srate;
channels    = 1:EEG.csc_montage.display_channels;
data        = eegData(EEG.csc_montage.channels(channels,1), range) - eegData(EEG.csc_montage.channels(channels,2), range);

% filter the data
% ~~~~~~~~~~~~~~~
[EEG.filter.b, EEG.filter.a] = ...
        butter(2,[EEG.csc_montage.filter_options(1)/(EEG.srate/2),...
                  EEG.csc_montage.filter_options(2)/(EEG.srate/2)]);
data = single(filtfilt(EEG.filter.b, EEG.filter.a, double(data'))'); %transpose data twice

% plot the data
% ~~~~~~~~~~~~~
% define accurate spacing
scale = get(handles.txt_scale, 'value')*-1;
toAdd = [1:EEG.csc_montage.display_channels]'*scale;
toAdd = repmat(toAdd, [1, length(range)]);

% space out the data for the single plot
data = data+toAdd;

set([handles.main_ax, handles.name_ax], 'yLim', [scale 0]*(EEG.csc_montage.display_channels+1))

% in the case of replotting delete the old handles
if isfield(handles, 'plot_eeg')
    delete(handles.plot_eeg);
    delete(handles.labels);
    delete(handles.indicator);
end

% calculate the time in seconds
time = range/EEG.srate;
set(handles.main_ax,  'xlim', [time(1), time(end)]);
handles.plot_eeg = line(time, data,...
                        'color', [0.9, 0.9, 0.9],...
                        'parent', handles.main_ax);
                  
% plot the labels in their own boxes
handles.labels = zeros(length(EEG.csc_montage.label_channels(channels)), 1);
for chn = 1:length(EEG.csc_montage.label_channels(channels))
    handles.labels(chn) = ...
        text(0.5, toAdd(chn,1)+scale/5, EEG.csc_montage.label_channels{chn},...
        'parent', handles.name_ax,...
        'fontsize',   12,...
        'fontweight', 'bold',...
        'color',      [0.8, 0.8, 0.8],...
        'backgroundcolor', [0.1 0.1 0.1],...
        'horizontalAlignment', 'center',...
        'buttondownfcn', {@fcn_hide_channel});
end
                    
% change the x limits of the indicator plot
set(handles.spike_ax,   'xlim', [0, size(eegData, 2)],...
                        'ylim', [0, 1]);
                    
% add indicator line to lower plot
handles.indicator = line([range(1), range(1)], [0, 1],...
                        'color', [0.9, 0.9, 0.9],...
                        'linewidth', 3,...
                        'parent', handles.spike_ax,...
                        'hittest', 'off');
                    
% set the new parameters
guidata(handles.fig, handles);
setappdata(handles.fig, 'EEG', EEG);
             

function fcn_update_axes(object, ~)
% get the handles structure
handles = guidata(object);

% get the data
EEG = getappdata(handles.fig, 'EEG');
eegData = getappdata(handles.fig, 'eegData');
        
% select the plotting data
current_point = get(handles.cPoint, 'value');
range       = current_point:current_point+EEG.csc_montage.epoch_length*EEG.srate-1;
channels    = 1:EEG.csc_montage.display_channels;
data        = eegData(EEG.csc_montage.channels(channels, 1), range) - eegData(EEG.csc_montage.channels(channels, 2), range);

data = single(filtfilt(EEG.filter.b, EEG.filter.a, double(data'))'); %transpose data twice

% plot the data
% ~~~~~~~~~~~~~
% define accurate spacing
scale = get(handles.txt_scale, 'value')*-1;
toAdd = [1:EEG.csc_montage.display_channels]'*scale;
toAdd = repmat(toAdd, [1, length(range)]);

% space out the data for the single plot
data = data+toAdd;

% calculate the time in seconds corresponding to the range in samples
time = range/EEG.srate;

% set the xlimits explicitely just in case matlab decides to give space
set(handles.main_ax,  'xlim', [time(1), time(end)]);

% set the x-axis to the time in seconds
set(handles.plot_eeg, 'xdata', time);

% reset the ydata of each line to represent the new data calculated
for n = 1:EEG.csc_montage.display_channels
    set(handles.plot_eeg(n), 'ydata', data(n,:));
end 


function fcn_change_time(object, ~)
% get the handles from the guidata
handles = guidata(object);
% Get the EEG from the figure's appdata
EEG = getappdata(handles.fig, 'EEG');

current_point = get(handles.cPoint, 'value');
if current_point < 1
    fprintf(1, 'This is the first sample \n');
    set(handles.cPoint, 'value', 1);
elseif current_point > EEG.pnts
    fprintf(1, 'No more data \n');
    set(handles.cPoint, 'value', EEG.pnts-(EEG.csc_montage.epoch_length*EEG.srate));
end
current_point = get(handles.cPoint, 'value');

% update the hypnogram indicator line
set(handles.indicator, 'Xdata', [current_point, current_point]);

% update the GUI handles
guidata(handles.fig, handles)
setappdata(handles.fig, 'EEG', EEG);

% update all the axes
fcn_update_axes(handles.fig);


function fcn_hide_channel(object, ~)
% get the handles from the guidata
handles = guidata(object);

% find the indice of the selected channel
ch = find(handles.labels == object);

% get its current state ('on' or 'off')
state = get(handles.plot_eeg(ch), 'visible');

switch state
    case 'on'
        set(handles.plot_eeg(ch), 'visible', 'off');
    case 'off'
        set(handles.plot_eeg(ch), 'visible', 'on');
end


function fcn_time_select(object, ~)
handles = guidata(object);

% get position of click
clicked_position = get(handles.spike_ax, 'currentPoint');

set(handles.cPoint, 'Value', floor(clicked_position(1,1)));
fcn_change_time(object, []);


function cb_key_pressed(object, event)
% get the relevant data
handles = guidata(object);
EEG = getappdata(handles.fig, 'EEG');

% movement keys
if isempty(event.Modifier)
    switch event.Key
        case 'leftarrow'
            % move to the previous epoch
            set(handles.cPoint, 'Value',...
                get(handles.cPoint, 'Value') - EEG.csc_montage.epoch_length*EEG.srate);
            fcn_change_time(object, [])
            
        case 'rightarrow'
            % move to the next epoch
            set(handles.cPoint, 'Value',...
                get(handles.cPoint, 'Value') + EEG.csc_montage.epoch_length*EEG.srate);
            fcn_change_time(object, [])
            
        case 'uparrow'
            scale = get(handles.txt_scale, 'value');
            if scale <= 20
                value = scale / 2;
                set(handles.txt_scale, 'value', value);
            else
                value = scale - 20;
                set(handles.txt_scale, 'value', value);
            end
            
            set(handles.txt_scale, 'string', get(handles.txt_scale, 'value'));
            set(handles.main_ax, 'yLim', [get(handles.txt_scale, 'value')*-1, 0]*(EEG.csc_montage.display_channels+1))
            fcn_update_axes(object)
            
        case 'downarrow'
            scale = get(handles.txt_scale, 'value');
            if scale <= 20
                value = scale * 2;
                set(handles.txt_scale, 'value', value);
            else
                value = scale + 20;
                set(handles.txt_scale, 'value', value);
            end
            
            set(handles.txt_scale, 'string', get(handles.txt_scale, 'value'));
            set(handles.main_ax, 'yLim', [get(handles.txt_scale, 'value')*-1, 0]*(EEG.csc_montage.display_channels+1))
            fcn_update_axes(object)
    end

% check whether the ctrl is pressed also
elseif strcmp(event.Modifier, 'control')
    
    switch event.Key
        case 'c'
            %TODO: pop_up for channel number
            
        case 'uparrow'
            %             fprintf(1, 'more channels \n');
    end
    
end


function cb_event_selection(object, ~, event_type)
% get the handles
handles = guidata(object);

% check if its the first item
if ~isfield(handles, 'events')
   handles.events{event_type} = []; 
end

current_point = get(handles.main_ax, 'currentPoint');

% mark the main axes
% ~~~~~~~~~~~~~~~~~~
x = current_point(1);
y = get(handles.main_ax, 'ylim');

% draw bottom triangle
handles.events{event_type}(end+1, 1) = plot(x, y(1),...
    'lineStyle', 'none',...
    'marker', '^',...
    'markerSize', 20,...
    'markerEdgeColor', [0.6, 0.9, 0.9],...
    'markerFaceColor', [0.9, 0.9, 0.6],...
    'userData', event_type,...
    'parent', handles.main_ax,...
    'buttonDownFcn', {@bdf_delete_event, event_type});

% draw top triangle
handles.events{event_type}(end, 2) = plot(x, y(2),...
    'lineStyle', 'none',...
    'marker', 'v',...
    'markerSize', 20,...
    'markerEdgeColor', [0.6, 0.9, 0.9],...
    'markerFaceColor', [0.9, 0.9, 0.6],...
    'userData', event_type,...
    'parent', handles.main_ax,...
    'buttonDownFcn', {@bdf_delete_event, event_type});

% mark the spike axes
% ~~~~~~~~~~~~~~~~~~~
y = get(handles.spike_ax, 'ylim');
handles.events{event_type}(end, 3) = line([x, x], y,...
    'color', [0.6, 0.9, 0.9],...
    'parent', handles.spike_ax,...
    'userData', event_type,...
    'hitTest', 'off');

% update the GUI handles
guidata(handles.fig, handles)


function bdf_delete_event(object, ~, event_type)
% get the handles
handles = guidata(object);

event_number = get(object, 'userData');

% erase the object from the main and spike axes
delete(handles.events{event_type}(event_number, :));

% erase the event from the list
handles.events{event_type}(event_number, :) = [];

% update the GUI handles
guidata(handles.fig, handles)


function fcn_event_browser(object, ~)
% get the handles
handles.csc_plotter = guidata(object);

handles.fig = figure(...
    'name',         'csc event browser',...
    'numberTitle',  'off',...
    'color',        [0.1, 0.1, 0.1],...
    'menuBar',      'none',...
    'units',        'normalized',...
    'outerPosition',[0 0.5 0.1 0.5]);

% montage table
handles.table = uitable(...
    'parent',       handles.fig             ,...
    'units',        'normalized'            ,...
    'position',     [0.05, 0.1, 0.9, 0.8]   ,...
    'backgroundcolor', [0.1, 0.1, 0.1; 0.2, 0.2, 0.2],...
    'foregroundcolor', [0.9, 0.9, 0.9]      ,...
    'columnName',   {'type','time'});

% get the underlying java properties
jscroll = findjobj(handles.table);
jscroll.setVerticalScrollBarPolicy(jscroll.java.VERTICAL_SCROLLBAR_ALWAYS);

% make the table sortable
% get the java table from the jscroll
jtable = jscroll.getViewport.getView;
jtable.setSortable(true);
jtable.setMultiColumnSortable(true);

% auto-adjust the column width
jtable.setAutoResizeMode(jtable.AUTO_RESIZE_ALL_COLUMNS);

% set the callback for table cell selection
set(handles.table, 'cellSelectionCallback', {@cb_select_table});

% calculate the event_data from the handles
event_data = fcn_compute_events(handles.csc_plotter);

% put the data into the table
set(handles.table, 'data', event_data);

% update the GUI handles
guidata(handles.fig, handles)


function event_data = fcn_compute_events(handles)
% function used to create the event_table from the handle structure

% pull out the events from the handles structure
events = handles.events;

% calculate the number of events
no_events = cellfun(@(x) size(x,1), events);

% pre-allocate the event data
event_data = cell(sum(no_events), 2);

% loop for each event type
for type = 1:length(no_events)
    % skip event type if there are no events
    if isempty(events{type})
        continue;
    end
    
    % calculate the rows to be inserted
    range = sum(no_events(1:type)) - sum(no_events(1:type)) + 1 : sum(no_events(1:type));
    
    % deal the event type into the event_data
    event_data(range, 1) = {get(handles.selection.item(type), 'label')};
    
    % return the xdata from the handles
    event_data(range, 2) = get(events{type}(:,1), 'xdata');
    
end


function cb_select_table(object, event_data)
% when a cell in the table is selected, jump to that time point

% get the handles
handles = guidata(object);

% get the data
EEG = getappdata(handles.csc_plotter.fig, 'EEG');

% if the event column was selected return
if event_data.Indices(2) == 1
    return
end

% return the data from the table
table_data = get(object, 'data');

% retrieve the time from the table
selected_time = table_data{event_data.Indices(1), 2};
go_to_time = selected_time - EEG.csc_montage.epoch_length/2;
selected_sample = floor(go_to_time * EEG.srate);

% change the hidden time keeper
set(handles.csc_plotter.cPoint, 'Value', selected_sample);

fcn_change_time(handles.csc_plotter.fig, []);


function fcn_options(object, ~, type)
% get the handles
handles = guidata(object);
% Get the EEG from the figure's appdata
EEG = getappdata(handles.fig, 'EEG');

switch type
    case 'disp_chans'
     
        answer = inputdlg('number of channels',...
            '', 1, {num2str( EEG.csc_montage.display_channels )});

        % if different from previous
        if ~isempty(answer)
            newNumber = str2double(answer{1});
            if newNumber ~= EEG.csc_montage.display_channels && newNumber <= length(EEG.csc_montage.label_channels); 
                EEG.csc_montage.display_channels = newNumber;
                % update the eeg structure before call
                setappdata(handles.fig, 'EEG', EEG);
                plot_initial_data(object)
            else
                fprintf(1, 'Warning: You requested more channels than available in the montage');
            end
        end
        
    case 'epoch_length'
        
        answer = inputdlg('length of epoch',...
            '', 1, {num2str( EEG.csc_montage.epoch_length )});
        
        % if different from previous
        if ~isempty(answer)
            newNumber = str2double(answer{1});
            if newNumber ~= EEG.csc_montage.epoch_length 
                EEG.csc_montage.epoch_length = newNumber;
                % update the eeg structure before call
                setappdata(handles.fig, 'EEG', EEG);
                plot_initial_data(object)
            end
        end
        
end


% Montage Functions
% ^^^^^^^^^^^^^^^^^
function fcn_montage_setup(object, ~)
% get the original figure handles
handles.csc_plotter = guidata(object);
EEG = getappdata(handles.csc_plotter.fig, 'EEG');

% make a window
% ~~~~~~~~~~~~~
handles.fig = figure(...
    'name',         'csc montage setup',...
    'numberTitle',  'off',...
    'color',        [0.1, 0.1, 0.1],...
    'menuBar',      'none',...
    'units',        'normalized',...
    'outerPosition',[0 0.04 .8 0.96]);

% make the axes
% ~~~~~~~~~~~~~
% main axes
handles.main_ax = axes(...
    'parent',       handles.fig             ,...
    'position',     [0.05 0.1, 0.6, 0.8]   ,...
    'nextPlot',     'add'                   ,...
    'color',        [0.2, 0.2, 0.2]         ,...
    'xcolor',       [0.9, 0.9, 0.9]         ,...
    'ycolor',       [0.9, 0.9, 0.9]         ,...
    'xtick',        []                      ,...    
    'ytick',        []                      ,...
    'fontName',     'Century Gothic'        ,...
    'fontSize',     8                       );

% drop-down list of montages
% ~~~~~~~~~~~~~~~~~~~~~~~~~~
montage_dir  = which('csc_eeg_plotter.m');
montage_dir  = fullfile(fileparts(montage_dir), 'Montages');
montage_list = dir(fullfile(montage_dir, '*.emo'));

% check 
if ~isempty(montage_list)
    montage_list = [{''}; {montage_list.name}'];
else
    montage_list = {''};
end

% create the drop down
handles.montage_list = uicontrol(       ...
    'parent',       handles.fig         ,...
    'style',        'popupmenu'         ,...
    'backgroundColor', [0.2, 0.2, 0.2]  ,...
    'units',        'normalized'        ,...
    'position',     [0.05 0.9 0.2, 0.05],...
    'string',       montage_list        ,...
    'selectionHighlight', 'off'         ,...
    'foregroundColor', [0.9, 0.9, 0.9]  ,...
    'fontName',     'Century Gothic'    ,...
    'fontSize',     8);
set(handles.montage_list, 'callback', {@fcn_select_montage});

% create the save button
handles.save_montage = uicontrol(...
    'parent',       handles.fig,...
    'style',        'push',...    
    'string',       '+',...
    'foregroundColor', 'k',...
    'units',        'normalized',...
    'position',     [0.275 0.93 0.02 0.02],...
    'fontName',     'Century Gothic',...
    'fontWeight',   'bold',...   
    'fontSize',     10);
set(handles.save_montage, 'callback', {@fcn_save_montage});


% montage table
handles.table = uitable(...
    'parent',       handles.fig             ,...
    'units',        'normalized'            ,...
    'position',     [0.7, 0.05, 0.25, 0.9]  ,...
    'backgroundcolor', [0.1, 0.1, 0.1; 0.2, 0.2, 0.2],...
    'foregroundcolor', [0.9, 0.9, 0.9]      ,...
    'columnName',   {'name','chn','ref'},...
    'columnEditable', [true, true, true]);

% automatically adjust the column width using java handle
jscroll = findjobj(handles.table);
jtable  = jscroll.getViewport.getView;
jtable.setAutoResizeMode(jtable.AUTO_RESIZE_ALL_COLUMNS);


% create the buttons
handles.button_delete = uicontrol(...
    'Parent',   handles.fig,...
    'Style',    'push',...    
    'String',   'delete',...
    'ForegroundColor', 'k',...
    'Units',    'normalized',...
    'Position', [0.75 0.075 0.05 0.02],...
    'FontName', 'Century Gothic',...
    'FontWeight', 'bold',...   
    'FontSize', 10);

set(handles.button_delete, 'callback', {@fcn_button_delete});

handles.button_apply = uicontrol(...
    'Parent',   handles.fig,...
    'Style',    'push',...    
    'String',   'apply',...
    'ForegroundColor', 'k',...
    'Units',    'normalized',...
    'Position', [0.85 0.075 0.05 0.02],...
    'FontName', 'Century Gothic',...
    'FontWeight', 'bold',...   
    'FontSize', 10);

set(handles.button_apply, 'callback', {@fcn_button_apply});

% set the initial table values
data = cell(length(EEG.csc_montage.label_channels), 3);
% current montage
data(:,1) = deal(EEG.csc_montage.label_channels);
data(:,[2,3]) = num2cell(EEG.csc_montage.channels);

% put the data into the table
set(handles.table, 'data', data);

% update handle structure
guidata(handles.fig, handles);

% plot the net
plot_net(handles.fig)


function plot_net(montage_handle)
% get the handles and EEG structure
handles  = guidata(montage_handle);
EEG = getappdata(handles.csc_plotter.fig, 'EEG');

if ~isfield(EEG.chanlocs(1), 'x')
   EEG.chanlocs = swa_add2dlocations(EEG.chanlocs); 
end

x = [EEG.chanlocs.x];
y = [EEG.chanlocs.y];
labels = {EEG.chanlocs.labels};

% make sure the circles are in the lines
set(handles.main_ax, 'xlim', [0, 41], 'ylim', [0, 41]);

for n = 1:length(EEG.chanlocs)
    handles.plt_markers(n) = plot(handles.main_ax, y(n), x(n),...
        'lineStyle', 'none',...
        'lineWidth', 3,...
        'marker', 'o',...
        'markersize', 25,...
        'markerfacecolor', [0.15, 0.15, 0.15],...
        'markeredgecolor', [0.08, 0.08, 0.08],...
        'selectionHighlight', 'off',...
        'userData', n);
    
    handles.txt_labels(n) = text(...
        y(n), x(n), labels{n},...
        'parent', handles.main_ax,...
        'fontname', 'liberation sans narrow',...
        'fontsize',  8,...
        'fontweight', 'bold',...
        'color',  [0.9, 0.9, 0.9],...
        'horizontalAlignment', 'center',...
        'selectionHighlight', 'off',...
        'hitTest', 'off');
end

set(handles.plt_markers, 'ButtonDownFcn', {@bdf_select_channel});

guidata(handles.fig, handles);
setappdata(handles.csc_plotter.fig, 'EEG', EEG);

update_net_arrows(handles.fig)


function update_net_arrows(montage_handle)
% get the handles and EEG structure
handles     = guidata(montage_handle);
EEG         = getappdata(handles.csc_plotter.fig, 'EEG');

x = [EEG.chanlocs.x];
y = [EEG.chanlocs.y];

if isfield(handles, 'line_arrows')
    try
        delete(handles.line_arrows);
        handles.line_arrows = [];
    end
end

% get the table data
data = get(handles.table, 'data');

% make an arrow from each channel to each reference
for n = 1:size(data, 1)
    handles.line_arrows(n) = line([y(data{n,2}), y(data{n,3})],...
                                  [x(data{n,2}), x(data{n,3})],...
                                  'parent', handles.main_ax,...
                                  'color', [0.3, 0.8, 0.3]);
end

uistack(handles.plt_markers, 'top');
uistack(handles.txt_labels, 'top');

guidata(handles.fig, handles);


function bdf_select_channel(object, ~)
% get the handles
handles = guidata(object);

% get the mouse button
event = get(handles.fig, 'selectionType');
ch    = get(object, 'userData');  

switch event
    case 'normal'
        data = get(handles.table, 'data');
        data{end+1, 1} = [num2str(ch), ' - '];
        data{end, 2} = ch;
        set(handles.table, 'data', data);
        
    case 'alt'
        data = get(handles.table, 'data');
        ind  = cellfun(@(x) isempty(x), data(:,3));
        data(ind,3) = deal({ch});
        set(handles.table, 'data', data);
        
        % replot the arrows
        update_net_arrows(handles.fig)
end

set(handles.montage_list, 'value', 1);


function fcn_button_delete(object, ~)
% get the handles
handles = guidata(object);

% find the row indices to delete
jscroll = findjobj(handles.table);
del_ind = jscroll.getComponent(0).getComponent(0).getSelectedRows+1;

% get the table, delete the rows and reset the table
data = get(handles.table, 'data');
data(del_ind, :) = [];
set(handles.table, 'data', data);

% update the arrows on the montage plot
update_net_arrows(handles.fig)


function fcn_button_apply(object, ~)
% get the montage handles
handles = guidata(object);
EEG     = getappdata(handles.csc_plotter.fig, 'EEG');

% get the table data
data = get(handles.table, 'data');

% check the all inputs are valid
if any(any(cellfun(@(x) ~isa(x, 'double'), data(:,[2,3]))))
    fprintf(1, 'Warning: check that all channel inputs are numbers\n');
end

EEG.csc_montage.label_channels  = data(:,1);
EEG.csc_montage.channels        = cell2mat(data(:,[2,3]));

if length(EEG.csc_montage.label_channels) < EEG.csc_montage.display_channels
    EEG.csc_montage.display_channels = length(EEG.csc_montage.label_channels);
    fprintf(1, 'Warning: reduced number of display channels to match montage\n');
end

guidata(handles.fig, handles);
setappdata(handles.csc_plotter.fig, 'EEG', EEG);

plot_initial_data(handles.csc_plotter.fig);


function fcn_select_montage(object, ~)
% get the montage handles
handles = guidata(object);
EEG     = getappdata(handles.csc_plotter.fig, 'EEG');

% find the montage directory
montage_dir  = which('csc_eeg_plotter.m');
montage_dir  = fullfile(fileparts(montage_dir), 'Montages');

% get the file name
montage_name = get(handles.montage_list, 'string');
montage_name = montage_name{get(handles.montage_list, 'value')};

% check if the empty string was selected
if ~isempty(montage_name)
    montage = load(fullfile(montage_dir, montage_name), '-mat');
    if isfield(montage, 'data')
        set(handles.table, 'data', montage.data);
    else
        fprintf(1, 'Warning: could not find montage data in the file');
    end
end

% update the handles in the structure
guidata(handles.fig, handles);
setappdata(handles.csc_plotter.fig, 'EEG', EEG);

% update the arrows on the montage plot
update_net_arrows(handles.fig)


function fcn_save_montage(object, ~)
% get the montage handles
handles = guidata(object);

% get the montage data
data = get(handles.table, 'data');

% find the montage directory
montage_dir  = which('csc_eeg_plotter.m');
montage_dir  = fullfile(fileparts(montage_dir), 'Montages');

% ask user for the filename
fileName = inputdlg('new montage name',...
    '', 1, {'new_montage'});

% check to see if user cancels
if isempty(fileName)
    return;
else
    % if not then get the string
    fileName = fileName{1};
end

% check to make sure it ends with '.emo' extension
if ~strcmp(fileName(end-3: end), '.emo')
    fileName = [fileName, '.emo'];
end

% save the file
save(fullfile(montage_dir, fileName), 'data', '-mat')

% update the montage list
montage_list = dir(fullfile(montage_dir, '*.emo'));
montage_list = [{''}; {montage_list.name}'];

new_index = find(strcmp(fileName, montage_list));

% set the drop-down menu
set(handles.montage_list,...
    'string', montage_list,...
    'value', new_index);
