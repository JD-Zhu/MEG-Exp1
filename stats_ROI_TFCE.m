%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% stats_ROI_TFCE.m
%
% statistical analysis on reconstructed ROI activities using the TFCE method:
% https://github.com/Mensen/ept_TFCE-matlab
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function stats_ROI_TFCE()
    
    clear all;

    % run the #define section
    global conds_cue; global conds_target; global eventnames;
    global ResultsFolder_ROI; % all subjects' ROI data are stored here
    common();

    % remove the 'response' event type, leaving us with 8 actual event types
    eventnames_8 = eventnames(1:8);


    %% Read data

    % initialise this variable (to enable loading without error)
    ROI_activity = [];

    % find all .mat files in ResultsFolder_ROI
    files = dir([ResultsFolder_ROI '*_ROI.mat']);

    % each cycle reads in one '.mat' file (ie. one subject's ROI results)
    for i = 1:length(files)
        filename = [ResultsFolder_ROI files(i).name];
        load(filename);
        allSubjects_ROIs_bySubjects(i) = ROI_activity;
    end

    % get a list of all the ROI labels
    ROIs_label = fieldnames(allSubjects_ROIs_bySubjects(1));

    % reformat allSubjects_ROIs: Subject|ROI|condition -> ROI|condition|Subjects
    for k = 1:length(ROIs_label)
        ROI_name = ROIs_label{k};
        allSubjects_ROIs.(ROI_name) = allSubjects_reformat(allSubjects_ROIs_bySubjects, ROI_name, eventnames_8);
    end

    % reformat again into eeglab format (which TFCE accepts):
    % each ROI|condition contains a 3d ("subject x channel x time") matrix
    for k = 1:length(ROIs_label)
        ROI_name = ROIs_label{k};

        for j = 1:length(eventnames_8) % loop thru each condition, to create the 3d matrix for this cond
            data_for_this_cond = allSubjects_ROIs.(ROI_name).(eventnames_8{j});
            subj_chan_time = []; % initialise the 3d matrix for this condition

            for subject = 1:length(data_for_this_cond) % loop thru all subjects
                % because the format requires a "channel" dimension, fake that by making 2 copies of the only channel (so we now have 2 channels)
                chan_time = vertcat(data_for_this_cond{subject}.avg, data_for_this_cond{subject}.avg);
                % add this subject's "chan x time" matrix to the 3d matrix
                subj_chan_time = cat(3, subj_chan_time, chan_time); % concatenate along the 3rd dimension
            end
            % subj_chan_time is now the 3d matrix containing all subjects ("subject" being the 3rd dimension)
            % change the order of matrix dimensions to: subj x chan x time
            subj_chan_time = permute(subj_chan_time, [3 1 2]); 

            % store the 3d matrix in new variable (eeglab format), under the correct ROI & condition name
            allSubjects_ROIs_eeglab.(ROI_name).(eventnames_8{j}) = subj_chan_time; 
            %allSubjects_ROIs_eeglab.(ROI_name).(eventnames_8{j}).label = ROI_name;
            %allSubjects_ROIs_eeglab.(ROI_name).(eventnames_8{j}).dimord = 'subj_chan_time';
        end
    end


    %% Statistical analysis using TFCE method

    fprintf('\n= STATS: Threshold-free cluster enhancement (TFCE method) =\n');

    % each cycle processes one ROI
    for k = 1:length(ROIs_label)

        ROI_name = ROIs_label{k};
        fprintf(['\nROI: ' ROI_name '\n']);

        data = allSubjects_ROIs_eeglab.(ROI_name); % data for the current ROI

        % run TFCE
                
        % Interaction (i.e. calc sw$ in each lang, then submit the 2 sw$ for comparison)
        fprintf('\nCUE window -> Testing lang x ttype interaction:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'interaction', data.cuechstay, data.cuechswitch, data.cueenstay, data.cueenswitch);
        [cue_interaction.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);
        fprintf('\nTARGET window -> Testing lang x ttype interaction:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'interaction', data.targetchstay, data.targetchswitch, data.targetenstay, data.targetenswitch); %'2-1 vs 4-3');
        [target_interaction.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);
    
        % Main effect of lang (collapse across stay-switch)
        fprintf('\nCUE window -> Main effect of lang:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'main_12vs34', data.cuechstay, data.cuechswitch, data.cueenstay, data.cueenswitch);
        [cue_lang.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);
        fprintf('\nTARGET window -> Main effect of lang:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'main_12vs34', data.targetchstay, data.targetchswitch, data.targetenstay, data.targetenswitch); %'2-1 vs 4-3');
        [target_lang.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);

        % Main effect of switch (collapse across langs)
        fprintf('\nCUE window -> Main effect of ttype:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'main_13vs24', data.cuechstay, data.cuechswitch, data.cueenstay, data.cueenswitch);
        [cue_ttype.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);
        fprintf('\nTARGET window -> Main effect of ttype:\n');
        [timelock1, timelock2] = combine_conds_for_T_test('eeglab', 'main_13vs24', data.targetchstay, data.targetchswitch, data.targetenstay, data.targetenswitch); %'2-1 vs 4-3');
        [target_ttype.(ROI_name)] = myWrapper_ept_TFCE(timelock1, timelock2);

    end
    
    save([ResultsFolder_ROI 'stats_TFCE.mat'], 'cue_interaction', 'cue_lang', 'cue_ttype', 'target_interaction', 'target_lang', 'target_ttype');

    
    %% Find the effects & plot them
%{
    % Automatically check all the stats output & read out the time interval
    % of each effect (from the stat.mask field)

    stats = load([ResultsFolder_ROI 'stats.mat']);
    load([ResultsFolder_ROI 'GA.mat']); % if you don't have this file, run stats_ROI.m to obtain it
    fprintf('\nThe following effects were detected:\n');

    % loop thru all 6 stats output (cue/target lang/ttype/interxn) and loop thru all ROIs in each,
    % check if any p-values in the results are significant (these are the effects)
    stats_names = fieldnames(stats);
    for i = 1:length(stats_names) % each cycle handles one effect (e.g. cue_lang)
        stat_name = stats_names{i};
        ROIs_names = fieldnames(stats.(stat_name)); % get the list of ROI names
        for k = 1:length(ROIs_names) % each cycle handles one ROI
            ROI_name = ROIs_names{k};
            % if any p-value is sig, that's an effect
            effect = find(stats.(stat_name).(ROI_name).P_Values < 0.05); %TODO: read out the correct time interval.
                                                                         %have a look at example effects in my email,
                                                                         %check the corresponding stats.stat_name.ROI_name entry to see how the index is organised -> it goes vertical then next col, so maybe index / 2 would give the time point
            if ~isempty(effect) % if there is an effect, we print it out
                %time_points = sprintf(' %d', effect);
                %fprintf('%s has an effect in %s, at these time points:%s.\n', ROI_name, stat_name, time_points);            
                start_time = stats.(stat_name).(ROI_name).time(effect(1));
                end_time = stats.(stat_name).(ROI_name).time(effect(end));
                fprintf('%s has an effect in %s, between %.f~%.f ms.\n', ROI_name, stat_name, start_time*1000, end_time*1000); % convert units to ms

                % plot the effect period, overlaid onto the GA plot for this ROI
                if strcmp(stat_name(1:3), 'cue') % this effect occurs in cue window
                    figure('Name', [stat_name ' in ' ROI_name]); hold on
                    for j = conds_cue
                        plot(GA.(ROI_name).(eventnames_8{j}).time, GA.(ROI_name).(eventnames_8{j}).avg);
                        xlim([-0.2 0.75]); 
                    end
                    line([start_time start_time], ylim, 'Color','black'); % plot a vertical line at start_time
                    line([end_time end_time], ylim, 'Color','black'); % plot a vertical line at end_time
                    % make a colour patch for the time interval of the effect
                    % (this keeps occupying the front layer, blocking the GA plot)
                    %x = [start_time end_time end_time start_time]; % shade between 2 values on x-axis
                    %y = [min(ylim)*[1 1] max(ylim)*[1 1]]; % fill up throughout y-axis
                    %patch(x,y,'white'); % choose colour
                    legend(eventnames_8(conds_cue));
                elseif strcmp(stat_name(1:6), 'target') % this effect occurs in target window
                    figure('Name', [stat_name ' in ' ROI_name]); hold on
                    for j = conds_target
                        plot(GA.(ROI_name).(eventnames_8{j}).time, GA.(ROI_name).(eventnames_8{j}).avg);
                        xlim([-0.2 0.75]); 
                    end
                    line([start_time start_time], ylim, 'Color','black'); % plot a vertical line at start_time
                    line([end_time end_time], ylim, 'Color','black'); % plot a vertical line at end_time
                    legend(eventnames_8(conds_target));                
                else % should never be here
                    fprintf('Error: an effect is found, but its not in either cue nor target window.\n');
                end
            else % output a msg even if there's no effect, just so we know the script ran correctly
                %fprintf('%s: No effect in %s\n', stat_name, ROI_name);
            end
        end
    end
%}
    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SUBFUNCTIONS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % wrapper function for calling ept_TFCE(), so that settings only need to be changed in one place
    function Results = myWrapper_ept_TFCE(data1, data2)
        Results = ept_TFCE(data1, data2, ...
            [], ...
            'type', 'd', ...
            'flag_ft', true, ...
            'flag_tfce', true, ... % set this to 'true' to use the TFCE method
            'nPerm', 1000, ...
            'rSample', 200, ...
            'saveName', [ResultsFolder_ROI 'TFCE_temp\\ept_' ROI_name '.mat']); % set a location to temporarily store the output. we don't need to save it, but if you don't set a location, it will litter arond your current directory
    end

end
