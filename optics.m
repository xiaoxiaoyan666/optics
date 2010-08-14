classdef optics < handle
% OPTICS defines the class for viewing snow optics image files
    
% DEFINE THE PUBLIC PROPERTIES    
properties
    FTP;        % FTP object
    fig;        % Handle of the Program Control Window
    position;   % Position of the Program Control
    exp;        % Folder for the experiment(s) (top level)
    folder;     % Sub folder(s) of the experiment (second level)
    type;       % Folder indicating the type of image (third level)
    angle;      % Angle folder (ZxxVxxY, fourth level)
    thepath;    % Current folder path for ftp download
    
    opticsPath = ''; % Path of savde workspace
    opticsFile = ''; % Filename of saved workspace (*.sws)
    
    % Define the user preferences
    keeplocal = true;           % Toggle for saving/removing local files
    target = 'database';        % The location of the image database
    appendWorkspace = true;     % Toggle for clearing exiting files 
end

% DEFINE THE PRIVATE PROPERTIES
properties (SetAccess = private)
    host = 'caesar.ce.montana.edu';         
    username = 'anonymous';                 
    password = 'snowoptics';
    thedir = '/pub/snow/optics';
    extensions = {'.jpg','.bip','.bil'}; % File extensions to allow
    handles = imObject.empty; % Initilize the imObject handles
    hprog; % Handles for toggling imObject functionallity 
end

% DEFINE THE METHODS
methods
    % OPTICS: operates on creation of optics object
    function obj = optics
        obj.fig = open('controlGUI.fig'); % Opens the GUI
        obj.startup; % Initlizes the optics class
    end
    
    % STARTUP: initilizes the optics class
    function obj = startup(obj);
       % Connect to the ftp site
       try
            obj.FTP = ftp(obj.host,obj.username,obj.password);
            cd(obj.FTP,obj.thedir);
       catch
           error('optics:FTP:fail','Failed to connect to the FTP server!');
       end
            
       % Initilize the GUI
       initControlGUI(obj);
    end
           
    % GETFILES: gathers the image files based on the folders selected
    function obj = getFiles(obj)
        % Gather the gui handles and existing images files
        h = guihandles(obj.fig);
        data = dir(obj.FTP,[obj.thepath,'/*.*']);
        
        % Cycle through each file and build a list of images only
        list = {}; k = 1;
        for i = 1:length(data);
            [~,~,e] = fileparts(data(i).name);
            if sum(strcmpi(e,obj.extensions)) == 1
                list{k} = data(i).name;
                k = k + 1;
            end
        end
        
        % Update the GUI object containing the list of images
        if isempty(list);
            set(h.images,'enable','off','String',{},'Value',0);
        else
            set(h.images,'enable','on','String',list,'Value',1);
        end
    end
    
    % OPENIMAGES: operates upon selection of the open button
    function obj = openImages(obj)
        % Gather guihandles and the selected files
        h = guihandles(obj.fig);
        str = get(h.images,'String');
        files = str(get(h.images,'Value'));

        % Change the directory to the current folder and build local path
        cd(obj.FTP,obj.thepath);
        localpath = regexprep(obj.thepath,'/',filesep);
        localpath = [obj.target,filesep,localpath];
        
        % Create the local directory if it does not exist
        if ~exist(localpath,'dir');
            mkdir(localpath);
        end
        
        % Cylce through the images and download to local directory
        for i = 1:length(files);
            filename = [localpath,filesep,files{i}];
            if ~exist(filename,'file');
                mget(obj.FTP,files{i},localpath);
            end
            obj.handles(end+1) = imObject(filename);  
        end
        
        % Return the ftp directory to the base
        cd(obj.FTP,obj.thedir);
        
        % Update the imObject handle list
        idx = isvalid(obj.handles);
        obj.handles = obj.handles(idx);
    end
    
    % SAVEWORKSPACE: operates to save the current workspace
    function saveWS(obj,thepath,thefile)
                % Determine the file to save
        filename = fullfile(thepath,thefile);
        spec = {'*.sws','MATLAB snow optics workspace (*.sws)'};
        filename = gatherfile('put','LastUsedWorkSpaceDir',spec,filename);
        if isempty(filename); return; end 
        
        % Remove invalid (delete) imObjects
        idx = isvalid(obj.handles);
        obj.handles = obj.handles(idx);
        
        % Cycle through each imObject and remove image data (saves space)
        tmp = {'display','image','info'};
        [pth,fname,ext] = fileparts(filename);  
        for i = 1:length(obj.handles);
            % Set the imObject path and filename (used for saving *.figs)
            obj.handles(i).imObjectPath = pth;
            obj.handles(i).imObjectName = [fname,ext];
            
            % Copy the object and remove extenous data
            S(i) = struct(obj.handles(i));
            for j = 1:length(tmp); obj.handles(i).(tmp{j}) = []; end
        end
        
        % Update the control window position
        set(obj.fig,'Units','normalized');
        obj.position = get(obj.fig,'position');
                     
        % Remove . directory if it exits
        [pth,fn] = fileparts(filename);
        dotdir = [pth,filesep,'.',fn];
        if exist(dotdir,'dir'); rmdir(dotdir,'s'); end
        
        % Save the optics object
        obj.opticsPath = pth;
        obj.opticsFile = [fname,ext];
        save(filename,'-mat','obj');
        
        % Restore the imObject data
        for i = 1:length(obj.handles);
            for j = 1:length(tmp); 
                obj.handles(i).(tmp{j}) = S.(tmp{j}); 
            end
        end

    end
    
    % LOADWS: operates when loading a workspace
    function obj = loadWS(obj);
        % Load the *.sws file
        spec = {'*.sws','MATLAB snow optics workspace (*.sws)'};
        filename = gatherfile('get','LastUsedWorkSpaceDir',spec);
        newObj = load(filename,'-mat'); newObj = newObj.obj;
            
        % Update the handles structure
        if obj.appendWorkspace % adds workspace to existing
            obj.handles = [obj.handles,newObj.handles];
            idx = isvalid(obj.handles);
            obj.handles = obj.handles(idx);
            
        else % removes existing images
            idx = isvalid(obj.handles);
            delete(obj.handles(idx));
            obj.handles = newObj.handles;
            set(obj.fig,'Units','normalized','Position',newObj.position);
        end
        
        % Update the workspace file information and update the folders
        obj.opticsPath = newObj.opticsPath;
        obj.opticsFile = newObj.opticsFile;
        obj.updateFolders;
    end
    
    % UPDATEFOLDERS: updates the GUI folder structure
    function obj = updateFolders(obj)
        
       disp('Update the folder structure.'); 
    end
    
    % CLOSEOPTICS: operates when the GUI is being closed
    function closeOptics(obj)
        % Close the ftp connection
        close(obj.FTP);
        
        % Delete the imObjects
        idx = isvalid(obj.handles)
        obj.handles = obj.handles(idx);
        for i = 1:length(obj.handles);
            delete(obj.handles(i));
        end
        
        % Delete the program control window
        delete(obj.fig);
    end   
end

% DEFINE THE STATIC METHODS FOR optics CLASS
methods (Static)
    % LOADOBJ: Operates when the object is loaded via load function
    function obj = loadobj(obj)
        % Add required paths
        addpath('imPlugin','bin');
        obj.fig = findobj('Name','Optics Program Control');
        if isempty(obj.fig);
            obj.fig = open('controlGUI.fig');
            set(obj.fig,'Units','Normalized','Position',obj.position);
        end
        
        obj.startup; % Initilizes the image (as created)
        
    end
end % ends static methods
end

%--------------------------------------------------------------------------
function initControlGUI(obj)
% INITCONTROLGUI initilizes the control GUI

% Gather the handles to the GUI and store optics object handle
h = guihandles(obj.fig);
guidata(obj.fig,obj);

% Set the window name and callbacks for closing the GUI
set(obj.fig,'Name','Optics Program Control');
set(obj.fig,'CloseRequestFcn',@(src,event)closeOptics(obj));
set(h.exit,'Callback',@(src,event)closeOptics(obj));

% Define callbacks for folder selection
set(h.exp,'Callback',@callback_exp,'Value',1);
set(h.folder,'Callback',@callback_folder,'Value',1);
set(h.type,'Callback',@callback_type,'Value',1);
set([h.angles,h.zenith,h.viewer,h.azimuth],'Callback',@callback_angle,...
    'Value',1);

% Define callback for opening the images
set(h.openimages,'Callback',@(src,event)openImages(obj));

% Define callbacks for the menu items
set(h.WSsave,'callback',@(src,event)saveWS(obj,obj.opticsPath,...
        obj.opticsFile));
set(h.WSsaveas,'callback',@(src,event)saveWS(obj,'',''));
set(h.WSopen,'callback',@(src,event)loadWS(obj));
   
% Intilize the GUI by calling the experiment folder callback
callback_exp(h.exp,[]);
end

%--------------------------------------------------------------------------
function callback_exp(hObject,~)
% CALLBACK_EXP operates when the user selects an experiment

% Gather the optics object and GUI handles
obj = guidata(hObject);
h = guihandles(hObject);

% Gather the folder structure from the FTP site
data = struct2cell(dir(obj.FTP));
str = data(1,:);
set(hObject,'String',str);

% Update the optics object properties and move to the next folder level
obj.exp = str{get(hObject,'Value')};
callback_folder(h.folder,[]);
end

%--------------------------------------------------------------------------
function callback_folder(hObject,~)
% CALLBACK_FOLDER operates when the user selects a folder

% Gather the optics object and GUI handles
obj = guidata(hObject);
h = guihandles(hObject);

% Gather the folder structure from the FTP site
data = struct2cell(dir(obj.FTP,obj.exp));
idx = cell2mat(data(3,:)); % Only considers folders
str = data(1,idx);
set(hObject,'String',str);

% Update the optics object properties and move to the next folder level
obj.folder = str{get(hObject,'Value')};
callback_type(h.type,[]);
end

%--------------------------------------------------------------------------
function callback_type(hObject,~)
% CALLBACK_TYPE operates when the user selects a type

% Gather the optics object
obj = guidata(hObject);

% Gather the folder structure from the FTP site
thepath = buildpath(obj.exp,obj.folder);
data = struct2cell(dir(obj.FTP,thepath));
idx = cell2mat(data(3,:)); % Only considers folders
str = data(1,idx);
set(hObject,'String',str);

% Update the optics object properties and move to the next folder level
obj.type = str{get(hObject,'Value')};
callback_angle(hObject,[]);
end

%--------------------------------------------------------------------------
function callback_angle(hObject,~)
% CALLBACK_ANGLE operates when angle panel is changed or toggled

% Gather the optics object and GUI handles
obj = guidata(hObject);
h = guihandles(hObject);

% Gather files from current directory if toggle is 'off'
value = get(h.angles,'Value');
if ~value
    set([h.zenith,h.viewer,h.azimuth],'enable','off');
    obj.thepath = buildpath(obj.exp,obj.folder,obj.type); 
    obj.angle = '';
    obj.getFiles;
else
    set([h.zenith,h.viewer,h.azimuth],'enable','on');
    obj.angle = getAngleFolder(h,obj);
    obj.thepath = buildpath(obj.exp,obj.folder,obj.type,obj.angle); 
    obj.getFiles;
end
end

%--------------------------------------------------------------------------
function angle = getAngleFolder(h,obj)
% GETANGLEFOLDER gathers the angle, viewer, zintth folder    
    
% Gather the current path based on selected folders
thepath = buildpath(obj.exp,obj.folder,obj.type);

% Define the available zenith angles
data = struct2cell(dir(obj.FTP,[thepath,'/Z*']));
str = char(data(1,:));
Z = unique(cellstr(str(:,2:3)));
set(h.zenith,'String',Z);
z = Z{get(h.zenith,'Value')};

% Define the available viewer angles
data = struct2cell(dir(obj.FTP,[thepath,'/Z',z,'*']));
str = char(data(1,:));
V = unique(cellstr(str(:,5:6)));
set(h.viewer,'String',V);
val = get(h.viewer,'Value');
if length(V) < val; set(h.viewer,'Value',1); end
v = V{get(h.viewer,'Value')};

% Define the available azimuths
data = struct2cell(dir(obj.FTP,[thepath,'/Z',z,'V',v,'*']));
str = char(data(1,:)); 
A = unique(cellstr(str(:,7)));
set(h.azimuth,'String',A);
val = get(h.azimuth,'Value');
if length(A) < val; set(h.azimuth,'Value',1); end
a = A{get(h.azimuth,'Value')};

% Output the current angle folder
angle = ['Z',z,'V',v,a];

end

%--------------------------------------------------------------------------
function thepath =  buildpath(varargin)
% BUILDPATH: construct the path for accessing images in the ftp server
thepath = varargin{1};
for i = 2:length(varargin);
    if ~isempty(varargin{i});
       thepath = [thepath,'/',varargin{i}]; 
    end
end
end




