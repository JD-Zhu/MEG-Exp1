%{
Version log:

v3: latest stable working version with all the features
v4: most EVAL statements are replaced by using dynamic field names rather
than dynamic variable names (script should run faster)
v5: added baseline correction after calc'ing erf -> later removed, in order to preserve cov matrix;
    added error-trial rejection, based on "errorsheet" from beh data checking;
    added downsampling (for saving);
    added computation of cov matrix in timelockanalysis (to enable creation of spatial filters in sourceanalysis)
v6: split whole script into 3 main stages of processing & each stage now loops thru all subjects;
    abstracted certain sections into its own function;
    created "common.m" - equivalent to a .h file which can be included/executed at the top of each script
%}

%%
close all
clear all % disable this line if u want breakpoints to work
clc

% run the #define section
global DataFolder; global ResultsFolder;
global eventnames;
common();

S1_output_filename = 'S1_preprocessed_data.mat'; % Stage 1 output (stored inside each Subject folder)
S2_output_filename = 'S2_after_visual_rejection.mat'; % Stage 2 output (stored inside each Subject folder)
S3_output_filename = '_erf.mat'; % ERF output (stored in ResultsFolder for all subjects)


% enable access to 'SubjectID' from inside "trig_fun_160_...", so that 
% correct code_delay value can be set for each subject (30ms for first 5 subjects, 100ms for the others)
global SubjectID; 

% find all subject folders containing raw MEG recording
SubjectIDs = dir([DataFolder 'M*']);
SubjectIDs = {SubjectIDs.name}; % extract the names into a cell array
%SubjectIDs = {'M03-AG-2784', 'M04-LL-2727'}; % or manually select which subjects to process


%% Stage 1: preprocessing & downsampling

for i = 1:length(SubjectIDs)
    
    SubjectID = cell2mat(SubjectIDs(i));
    SubjectFolder = [DataFolder SubjectID '\\'];
    S1_output_file = [SubjectFolder S1_output_filename];

    % if haven't already processed this stage before, do it now & save a copy
    if (exist(S1_output_file, 'file') ~= 2)    
        [all_blocks, trialinfo_b] = preprocessing(SubjectFolder);

        % downsample the data for saving
        %all_blocks.time(1:end) = all_blocks.time(1); % this avoids numeric round off issues in the time axes upon resampling
        cfg            = [];
        cfg.resamplefs = 200; % sampling freq was 1000Hz, best to use a divisor of it (200Hz is commonly used)
        cfg.detrend    = 'no';
        all_blocks     = ft_resampledata(cfg, all_blocks);

        % SAVE preprocessed data - takes a while!!
        save(S1_output_file, 'all_blocks', 'trialinfo_b');
    end
end


%%  Stage 2: trial exclusions

for k = 1:length(SubjectIDs)
    
    SubjectID = cell2mat(SubjectIDs(k));
    SubjectFolder = [DataFolder SubjectID '\\'];
    S2_output_file = [SubjectFolder S2_output_filename];

    % if haven't already processed this stage before, do it now & save a copy
    if (exist(S2_output_file, 'file') ~= 2)    

        load([SubjectFolder S1_output_filename]);

        events_allBlocks = identify_event_types(SubjectID, trialinfo_b);
        
        events_allBlocks = exclude_beh_errors(SubjectID, events_allBlocks);

        load([ResultsFolder 'lay.mat']);
        [all_blocks_clean, response_comp] = reject_response_component(all_blocks, events_allBlocks, lay);
        
        
        % === Reject Outlier Trials ===

        % Print out SubjectID so we know which subject we are working on
        fprintf(['\nCURRENT SUBJECT: ' SubjectID '\n\n']); 

        % Display visual trial summary to reject deviant trials.
        cfg              = [];
        cfg.feedback     = 'no'; % suppress console output (so that it's easy to find the SubjectID we printed out above)
        cfg.method       = 'summary';
        cfg.keepchannel  = 'no';
        cfg.keeptrial    = 'nan'; % we keep the rejected trials as 'NaN' here,
            % because if we remove them, that will change the indices of all subsequent trials,
            % which will no longer match the indices we are using in events_allBlocks
        all_blocks_clean = ft_rejectvisual(cfg, all_blocks_clean);
        
    
        save([SubjectFolder S2_output_filename], 'all_blocks_clean', 'events_allBlocks', 'response_comp'); 
        % 'all_blocks' was not changed in Stage 2, so don't need to save again
    end
end


%% Stage 3: time-domain analysis (i.e. compute erf)

for i = 1:length(SubjectIDs)
    
    SubjectID = cell2mat(SubjectIDs(i));
    SubjectFolder = [DataFolder SubjectID '\\'];
    S3_output_file = [ResultsFolder SubjectID S3_output_filename];

    % if haven't already processed this stage before, do it now & save a copy
    if (exist(S3_output_file, 'file') ~= 2)    

        load([SubjectFolder S1_output_filename]); % to load 'all_blocks'
        load([SubjectFolder S2_output_filename]);

        % make sure we have a clean start (i.e. no leftover var contents from last subject)
        clear erf; clear erf_clean;
        clear trials; clear trials_clean;

        % === ft_redefine all event types (i.e. 8 real conditions + 'response' event) ===

        % in uncleaned data
        for j = 1:length(eventnames)
            cfg = [];
            cfg.trials = events_allBlocks.(eventnames{j});
            trials.(eventnames{j}) = ft_redefinetrial(cfg, all_blocks);
        end

        % in cleaned data
        for j = 1:length(eventnames)
            cfg = [];
            cfg.trials = events_allBlocks.(eventnames{j});
            trials_clean.(eventnames{j}) = ft_redefinetrial(cfg, all_blocks_clean);
        end

        % delete vars that are no longer needed (to clear up some memory)
        clear all_blocks;
        clear all_blocks_clean;
        clear trialinfo_b;

        %save([SubjectFolder 'before_computing_erf.mat'], 'trials', 'trials_clean', 'response_comp');


        % === compute ERFs ===

        % in uncleaned data (just for quality check of PCA component rejection)
        for j = 1:length(eventnames)
            cfg         = [];
            %cfg.nanmean = 'yes';
            %trials.(eventnames{j}) = ft_selectdata(cfg, trials.(eventnames{j})); % Do this because we kept bad trials as NaN
            erf.(eventnames{j}) = ft_timelockanalysis(cfg, trials.(eventnames{j})); % Do this to create average field and timelock struct
        end

        % in cleaned data (compute erfs & cov matrices)
        [erf_clean, erf_cue_combined, erf_target_combined] = compute_ERF(trials_clean);

        % Do not perform baseline correction here, because it will remove the cov matrix from the timelock output:
        % "baseline correction invalidates previous covariance estimate, removing cov"
        %{
        % baseline correction
        for j = 1:length(eventnames)
            cfg = [];
            cfg.baseline = [-0.2 0];
            erf.(eventnames{j}) = ft_timelockbaseline(cfg, erf.(eventnames{j})); % uncleaned data
            erf_clean.(eventnames{j}) = ft_timelockbaseline(cfg, erf_clean.(eventnames{j})); % cleaned data
        end
        %}

        % SAVE all relevant variables from the workspace
        save([ResultsFolder SubjectID '_erf.mat'], 'SubjectFolder', ...
            'erf', 'erf_clean', 'erf_cue_combined', 'erf_target_combined');       
    end

    % === Plot ERF & GFP (can use this to regen all plots from saved erf results) ===

    %load([ResultsFolder SubjectID S3_output_filename]);
    %load([ResultsFolder 'lay.mat']); 
    %plot_ERF(erf, erf_clean, lay);
    
end