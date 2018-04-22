% the common #define section for all scripts

% Warning: all of the global vars below are CONSTANTS.
% UNDER NO CIRCUMSTANCES should their values be assigned/modified in other scripts.

function [] = common()
    % specify all paths as absolute paths, to avoid any issues when we 'cd' into diff folders
    
    global DataFolder; global ResultsFolder; global ResultsFolder_ROI;
    DataFolder = [pwd '\\..\\..\\RAW_DATA\\'];
    ResultsFolder = [pwd '\\..\\..\\results_ERF\\']; % all subjects' erf data will be stored here
    ResultsFolder_ROI = [pwd '\\..\\..\\results_ROI\\']; % all subjects' ROI source-reconstruction results will be stored here

    % trigger events (DO NOT change the order of this list)
    global eventcodes; global eventnames;
    eventcodes = {{'cuechstay'},{'17'};{'cuechswitch'},{'19'};{'cueenstay'},{'21'};{'cueenswitch'},{'23'}; ...
        {'targetchstay'},{'18'};{'targetchswitch'},{'20'};{'targetenstay'},{'22'};{'targetenswitch'},{'24'};{'response'},{'30'}};
    eventnames = eventcodes(:,1); % extract a list of all event names
    eventnames = [eventnames{:}]; % convert into strings

    % for ease of reference to the conditions in cue window & target window
    global conds_cue; global conds_target;
    conds_cue = 1:4;
    conds_target = 5:8;
end