classdef imObject < handle
% imObject class definition for analysis w/ snow image toolbox     
%__________________________________________________________________________
% SYNTAX:
%   obj = imObject;
%   obj = imObject(filename);
%
% DESCRIPTION:
%   obj = imObject creates an imObject and prompts the user to specify and
%       image file.
%   obj = imObject(filename) same as above put uses the defined file.
%__________________________________________________________________________

% DEFINE THE PUBLIC (EDITABLE) PROPERTIES OF THE IMOBJECT CLASS
properties % Public properties 
    % Properties defining the image 
    filename; % Filename of the image being opened
    image;    % Array containing image information
    display;  % Array containing image information for display
    norm;     % Coefficient(s) for normalizing image via white region
    info;     % Structure containing image information
    type;     % String dictating the image type
    imposition = [0.15,0.25,0.5,0.5]; % Position of the imtool window

    % Properties for user selected regions
    white = imRegion.empty;
    work = imRegion.empty;

    % Properties associated with the overview window
    overview = 'off'; % Open the overview window
    ovposition = [];  % Position to keep the overview window
    
    % Other properties
    imObjectName = ''; % Filename of saved imObject class
    imObjectPath = ''; % Folder used when saving imObject class
    
    % Set general imObject options (a value must be assigned)
    workNorm = true;
end 
   
% DEFINE THE PRIVIATE PROPERTIES OF THE imObject CLASS
properties (SetAccess = private)
    imhandle; % Handle of the imtool window
    imaxes;   % Handle to the image axis
    plugins;  % Handles to the plugin object(s)
    ovhandle; % Handle of the overview window
    hprog;    % Handles for toggling imObject functionallity 
end

% DEFINE THE DYNAMIC METHODS FOR THE imObject CLASS
methods       
    % imObject: Operates on imObject creation
    function obj = imObject(varargin)
        addpath('imPlugin','bin');
        obj = openimage(obj,varargin{:});
        obj.startup;
    end

    % STARTUP: Used to initialize the creation/loading of an imObject
    function obj = startup(obj)      
        % Create the imObject tools and plugins
        addpath('imPlugin','bin');
        createtools(obj);   
        obj.plugins = addplugins(obj);

        % Setup up the overview window
        if strcmpi(obj.overview,'on'); obj.openOverview; end
    end
    
    % OPENOVERVIEW: opens the overview window
    function obj = openOverview(obj)
        obj.ovhandle = imoverview(imhandles(obj.imhandle));
        set(obj.ovhandle,'Units','Normalized');
        if length(obj.ovposition) == 4;
            set(obj.ovhandle,'Position',obj.ovposition);       
        end
    end
    
    % PLUGINPREF: Opens a window for adjuting preferences of plugins
    function obj = pluginpref(obj)
       prefGUI(obj);
    end
    
    % CALCNORM: Normalizes the data based on the white region(s)
    function obj = calcNorm(obj)
        % Gather image information and return if no region exists
        R = obj.white;
        if isempty(R); return; end
        
        % Gather the normilization array dimensions
        r = length(R);
        n = size(obj.image,3);
        
        % Disable imObject functionality
        obj.progress
        
        % Compute the mean values of the white regions
        theNorm = zeros(r,n);
        for i = 1:r;    
            I = R(i).image; 
            theNorm(i,:) = nanmean(nanmean(I));
        end
        
        % Update the normalization property
        obj.norm = mean(theNorm,1); 
        
        % Restore functionality
        obj.progress
    end
     
    % SAVEimObject: Allows user to save the imObject
    function saveimObject(obj,thepath,thefile)
        % Determine the file to save
        imFile = fullfile(thepath,thefile);
        spec = {'*.imobj','MATLAB imObject class (*.imobj)'};
        imFile = gatherfile('put','LastUsedimObjectDir',spec,imFile);
        if isempty(imFile); return; end 
 
        % Update the imtool name
        [~,imF,imE] = fileparts(obj.filename);  
        [P,F,E] = fileparts(imFile);
        obj.imObjectName = [F,E];
        obj.imObjectPath = P;
        set(imgcf,'Name',[F,E,' (',imF,imE,')']);
        
        % Update the positions
        obj.imposition = get(obj.imhandle,'position');
        if ishandle(obj.ovhandle);
            obj.ovposition = get(obj.ovhandle,'position');
        end
        
        % Copy the object and remove extenous data
        S = struct(obj);
        tmp = {'display','image','info','imhandle','ovhandle'};
        for i = 1:length(tmp); obj.(tmp{i}) = []; end
              
        % Save the object
        save(imFile,'-mat','obj');
    
        % Restore the data
        for i = 1:length(tmp); obj.(tmp{i}) = S.(tmp{i}); end
    end
    
    % PROGRESS: Toggles the funtionallity of the imObject on and off
    function progress(obj)
        % Disable handles
        if isempty(obj.hprog)
            obj.hprog = findobj('enable','on');
            set(obj.hprog,'enable','off');
            drawnow;
            
        % Enable handles    
        else
            set(obj.hprog,'enable','on');
            obj.hprog = [];
        end
    end
    
    % DELETE: operates when the imObject is being destroyed
    function delete(obj)
       if ishandle(obj.imhandle); delete(obj.imhandle); end
    end
end % end dynamic methods

% DEFINE THE STATIC METHODS FOR imObject CLASS
methods (Static)
    % LOADOBJ: Operates when the object is loaded via load function
    function obj = loadobj(obj)
        % Add required paths
        addpath('imPlugin','bin');
    
        % Load the image, tool, plugins, etc...
        obj = openimage(obj,obj.filename); % Opens the desired image
        obj.startup; % Initilizes the image (as created)

        % Restore work regions
        for i = 1:length(obj.work);
            obj.work(i).createregion('load');
            obj.work(i).addlabel(obj.work(i).label);
        end
        % Restore white regions
        for i = 1:length(obj.white);
            obj.white(i).createregion('load');
            obj.white(i).addlabel(obj.white(i).label);
        end
    end
end % ends static methods
end % ends the main classdef

%--------------------------------------------------------------------------
function obj = openimage(obj,varargin)
% OPENIMAGE opens the desired image upon creation/loading of imObject class

% SET/GATHER THE IMAGE FILENAME
spec = {'*.bip','HSI Image (*.bip)'; '*.jpg','JPEG Image (*.jpg)'};
obj.filename = gatherfile('get','LastUsedDir',spec,varargin{:});

% OPEN THE IMAGE
[~,~,ext] = fileparts(obj.filename);   
switch ext;
    case '.bip'; % Opens a hyperspectral image
        
        % Reads the *.bip and *.bip.hdr files
        [obj.image, obj.info] = readBIP(obj.filename);
        obj.type = 'HSI';
        
        % Creates and image for display base on RGB wavelenghts
        rgb = [620,750; 495,570; 380,450];
        w = obj.info.wavelength;
        for i = 1:size(rgb,1);
           idx = w >= rgb(i,1) & w <= rgb(i,2);
           obj.display(:,:,i) = mean(obj.image(:,:,idx),3); 
        end
        
    otherwise; % Opens a traditional image file
        obj.type = 'VIS|NIR';
        obj.image = imread(obj.filename);
        obj.info = imfinfo(obj.filename);
        obj.display = obj.image;     
end

% OPEN THE IMAGE IN WITH IMTOOL 
if ~isempty(obj.imObjectName);
    [~,f,e] = fileparts(obj.imObjectName);
    name = [f,e,' (',obj.filename,')'];
else
    name = obj.filename;
end

h = imtool(obj.display); 
guidata(h,obj);
set(h,'BusyAction','cancel','Units','Normalize','Name',name,...
    'Position',obj.imposition,'CloseRequestFcn',@callback_closefcn);
obj.imhandle = h;
obj.imaxes = imgca;
end   

%--------------------------------------------------------------------------
function createtools(obj)
% CREATETOOLS adds the desired 

% DEFINE THE imObject MENU
h = obj.imhandle; % imtool handle
im = uimenu(h,'Label','imObject'); % The Regions menu
    uimenu(im,'Label','imObject Save','callback',...
        @(src,event)saveimObject(obj,obj.imObjectPath,...
        obj.imObjectName));
    uimenu(im,'Label','imObject Save as...','callback',...
        @(src,event)saveimObject(obj,''));
    uimenu(im,'Label','Open Overview','separator','on','Checked',...
        obj.overview,'callback',@callback_overview);
    uimenu(im,'Label','Plugin Preferences','separator','on',...
        'callback',@(src,event)pluginpref(obj));    

% DEFINE THE REGIONS MENU
type = {'Rectangle','Ellipse','Polygon','Freehand'}; % Sub-menu items
m = uimenu(h,'Label','Regions'); % The Regions menu

% DEFINE THE WHITE BACKGROUND REGION MENUS
w = uimenu(m,'Label','Add White Reference','Separator','on');
    for i = 1:length(type);
        uimenu(w,'Label',type{i},'callback',...
            @(src,event)callback_createregion(obj,'white',type{i}));
    end
    uimenu(m,'Label','Clear White Reference(s)','callback',...
        @(src,event)callback_rmregion(obj,'white'));
    
% DEFINE THE WORK REGION MENUS    
w = uimenu(m,'Label','Add Work Region','Separator','on');
    for i = 1:length(type);
        uimenu(w,'Label',type{i},'callback',...
            @(src,event)callback_createregion(obj,'work',type{i}));
    end
    uimenu(m,'Label','Clear Work Region(s)','callback',...
        @(src,event)callback_rmregion(obj,'work'));   
    
% DEFINE THE TOOLBAR W/ PREFERENCES BUTTON
    icon = load('icon/icons.ico','-mat');
    tbar = uitoolbar(h,'Tag','TheToolBar');
    uipushtool(tbar,'Cdata',icon.save,'TooltipString','Save imObject',...
        'ClickedCallback',@(src,event)saveimObject(obj,obj.imObjectPath,...
        obj.imObjectName));   
    uipushtool(tbar,'Cdata',icon.pref,'TooltipString',...
        'imObject Preferences','ClickedCallback',...
        @(src,event)pluginpref(obj));   
end

%--------------------------------------------------------------------------
function plugin = addplugins(obj)
% ADDPLUGINS searchs the plugin directory and adds plugin options

% LOCATE THE M-FILES IN PLUGIN DIRECTORY
pth = [cd,filesep,'imPlugin',filesep];           
addpath(pth); 
f = dir([pth,'im*.m']);

% EVALUATE ALL M-FILES IN PLUGINS DIRECTORY 
% (use if it returns imPlugin object)
k = 1;
for i = 1:length(f);
    [~,name] = fileparts(f(i).name);
    p = feval(name,obj);
    if strcmpi(class(p),'imPlugin');
        plugin(k) = p; % Plugin handle
        Morder(k) = p.MenuOrder; % Desired order for menu item
        Porder(k) = p.PushtoolOrder; % Desired order for pushtool button
        k = k + 1;
    end
end
          
% CREATE THE MENU AND PUSHTOOL CONTROLS 
[~,Mix] = sort(Morder); % Re-orders the menu items
[~,Pix] = sort(Porder); % Re-orders the pushtool items

    % Create the menus items, using appropriate plugin class method
    for i = 1:length(Mix);
        plugin(Mix(i)).createmenuitem;
    end

    % Create the pushtool items, using appropriate plugin class method
    for i = 1:length(Pix);
        plugin(Pix(i)).createpushtool;
    end    
end

%--------------------------------------------------------------------------
function obj = callback_createregion(obj,type,func)
% CALLBACK_CREATEREGION gathers/creates regions via the imRegion class

n = length(obj.(type)) + 1; 
R = imRegion(obj,type,func);
R.addlabel([' ',num2str(n)]); 
drawnow;
R.getRegion;
obj.(type)(n) = R;
if strcmpi(type,'white'); obj.calcNorm; end; 

end

%--------------------------------------------------------------------------      
function obj = callback_rmregion(obj,item)
% CALLBACK_RMREGION removes regions
    delete(obj.(item));  
    obj.(item)= imRegion.empty;
    if strcmpi(item,'white'); obj.norm = []; end
end

%--------------------------------------------------------------------------
function callback_overview(hObject,~)
% CALLBACK_OVERVIEW toggle the overview window  
obj = guidata(hObject);
status = get(hObject,'Checked');
switch status;
    case 'on'; 
        obj.overview = 'off';
        set(hObject,'Checked','off');
        close(obj.ovhandle);
    case 'off';
        obj.overview = 'on';
        set(hObject,'Checked','on');
        obj.openOverview;
end
end

%--------------------------------------------------------------------------
function callback_closefcn(hObject,~)
% CALLBACK_CLOSEFCN closes the imObject by deleting the class and figure
    obj = guidata(hObject);
    figs = obj.plugins.children;
    for i = 1:length(figs); 
        if ishandle(figs(i)); delete(figs(i)); end; 
    end
    delete(obj.plugins);
    delete(obj);
    cur = findobj('Name','Plugin Preferences'); delete(cur);
    close(imgcf);
end
