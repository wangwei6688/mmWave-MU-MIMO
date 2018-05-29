% Setup the environment
clear; clc; close all;
addpath('utilities','-end');  % Add utilities folder at the end of search path
% Define several experiments here and override variable values accordingly
experimentList = 5;
if any(experimentList(:)==1);    experiment1();   end
if any(experimentList(:)==2);    experiment2();   end
if any(experimentList(:)==3);    experiment3();   end
if any(experimentList(:)==4)
    nUsers = 2;
%     nAntennasList = [4 5 6 7 8 9 10].^2;
    nAntennasList = [2 3].^2;
    nIter = 2;
    plotFLAG = true;
    experiment4(nIter,nUsers,nAntennasList,plotFLAG);
end
if any(experimentList(:)==5)
    nIter = 1;  % Iterations over shich to average the results
    nUsers = 2;  % Static number of users in simulation
%     nAntennasList = [4 8 12 16 20 24 28 32].^2;  % Number of antennas in array
    nAntennasList = [4 8 12].^2;  % Number of antennas in array
    plotFLAG = true;  % Plotting flag
    [Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd] = ...
                          experiment5(nIter,nUsers,nAntennasList,plotFLAG);
    experiment5_plot(nUsers,nAntennasList,Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd);
end
if any(experimentList(:)==51)
    fileName = 'temp/exp5-results';
    load(fileName,'nUsers','nAntennasList','Cap','SINR_BB','SINR_PB','DirOK','DirNOK_gntd','DirNOK_pcvd');
    experiment5_plot(nUsers,nAntennasList,Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd);
end

function experiment1(varargin)
    % EXPERIMENT 1 - Capacity offered
    % In this experiment we evaluate the capacity that the heuristics are able
    % to offer to the devices. Heuristics assigns antennas as a function of the
    % priority. The traffic is overloaded. The users location and channel
    % varies across simulations.
    %
    %------------- BEGIN CODE EXPERIMENT 1 --------------
    %
    fprintf('Running experiment 1...\n');
    % Load basic configuration - static and/or default
    problem = o_read_input_problem('data/metaproblem_test.dat');
    conf = o_read_config('data/config_test.dat');
    % Override parameters
    problem.iat = 60;
    problem.deadline = 50;
    problem.payload = 1500*8*5e3;
    % Configure the simulation environment
    [problem,~,flows] = f_configuration(conf,problem);
    baseFlows = flows;  % For printing purposes at the end of execution
    % Main function
    [flows,CapTot,TXbitsTot,THTot,lastSlotSimm,lastSelFlow] = main(conf,problem,flows);
    % Report of single execution
    [ratioOK,ratioNOK] = f_generateReport(flows,DEBUG);
    % Plotting of single execution
    % main_plotting(problem,TXbitsTot,THTot,baseFlows,lastSelFlow);
end

% EXPERIMENT 2 - Chances of achieving the demanded throughput
% To-Do. It uses the whole simulator and takes the real traffic as input.

% EXPERIMENT 3 - Performance comparisson against null-forcing technique
% To-Do. The comparisson needs to be agains a more updated technique such
% as the JSDM. Waiting for reply from Kaushik to write to them and get the
% code.

% EXPERIMENT 4 - Convergency analysis
function experiment4(nIter,nUsers,nAntennasList,plotFLAG)
    % EXPERIMENT 4 -- 
    % 
    % Aim: Obtain the approximate number of generations (operational cycles)
    % that we need to obtain a certain quality of solution by comparing the
    % Genetic Algorithm convergence with the global optimum found by means
    % of an Exhaustive Search
    % 
	% Assumptions (Fixed):
    %   1. User location: Fixed, from config file.
    %   2. Sub-array geometry: 'None'.
    %   3. Antenna Array geometry: Fixed to URA.
    %   4. Algorithm: GA & ES
    % Variable:
    %   1. Antenna Array size variable: nAntennasList
    %   2. Population size: Fixed with all the rest of GA parameters, in
    %   order to have a unique dependence on #generations
    % 
    % Syntax:  [] =
    % experiment4(nIters,nUsers,nAntennasList,plotFLAG)
    % 
    % Inputs:
    %    nIter - Number of iterations to extract average values
    %    nUsers - Number of users considered
    %    nAntennaList - Number of antenas (set of)
    %    plotFLAG - True for plotting directivity and antenna allocation
    %
    % Outputs: None
    %
    %------------- BEGIN CODE EXPERIMENT 4 --------------
    %
    fprintf('Running experiment 4...\n');
    % Load basic parameters
    problem = o_read_input_problem('data/metaproblem_test.dat');
    conf = o_read_config('data/config_test.dat');
    % Override (problem) parameters
    % Override (problem) parameters
    problem.nUsers = nUsers;  % Number of users in the simulation
    problem.MinObjFIsSNR = true;  % (arbitrary)
    problem.MinObjF = 100.*ones(1,problem.nUsers);  % Same #ant per user. Random SNR (30dB)
    problem.arrayRestriction = 'None';  % Possibilities: "None", "Localized", "Interleaved", "DiagInterleaved"
    % Override (conf) parameters
    conf.verbosity = 0;
    conf.NumPhaseShifterBits = 2;  % Number of 
    conf.NbitsAmplitude = 2;
    conf.FunctionTolerance_Data = 1e-10;  % Heuristics stops when not improving solution by this much
    conf.multiPath = false;  % LoS channel (for now)
    
    % Override GA parameters
    conf.PopulationSize_Data = 40;
    conf.Maxgenerations_Data = 100;
    conf.EliteCount_Data = 10;
    conf.MaxStallgenerations_Data = 40;  % Force it to cover all the generations
    h1 = figure;
    hold on
    % For each case we execute ES and the GA
    for idxAnt = 1:length(nAntennasList)
        for idxIter = 1:nIter
            fprintf('Iteration %d with nAntenas %d\n',idxIter,nAntennasList(idxAnt));
            % Configure the simulation environment. Need to place users in new
            % locations (if not fixed) and create new channels 
            % to have statistically meaningful results (if not LoS)
            [problem,~,~] = f_configuration(conf,problem);
            % Select number of antennas
            problem.N_Antennas = nAntennasList(idxAnt);
            % Adjust parameters
            problem.NxPatch = floor(sqrt(problem.N_Antennas));
            problem.NyPatch = floor(problem.N_Antennas./problem.NxPatch);
            problem.N_Antennas = problem.NxPatch.*problem.NyPatch;
            % Call heuristics
            fprintf('\t** %d Antennas and %d Users...\n',problem.N_Antennas,problem.nUsers);
            % We will paralelize the solution computations: we need (if not already
            % created) a parallelization processes pool
            gcp;

            %% Create subarray partition
            problem = o_create_subarray_partition(problem);

            problem.NzPatch = problem.NxPatch;
            problem.dz = problem.dx;

            %% Create the antenna handler and the data structure with all possible pos.
            problem.handle_Ant = phased.CosineAntennaElement('FrequencyRange',...
                [problem.freq-(problem.Bw/2) problem.freq+(problem.Bw/2)],...
                'CosinePower',[1.5 2.5]); % [1.5 2.5] values set porque s�
            handle_ConformalArray = phased.URA([problem.NyPatch,problem.NzPatch],...
                'Lattice','Rectangular','Element',problem.handle_Ant,...
            'ElementSpacing',[problem.dy,problem.dz]);

            problem.possible_locations = handle_ConformalArray.getElementPosition;

            % Boolean flag indicating if we have already found a feasible solution
            problem = o_compute_antennas_per_user(problem,1:nUsers);
            % We will accumulate in the assignments_status var the
            % antennas / subarrays assigned as soon as we assign them
            [~,orderedIndices] = sort(problem.MinObjF,'descend');
            u = orderedIndices(1);
            problem.IDUserAssigned = u;
            
            % First we execute the Exhaustive Search
            conf.algorithm = 'ES';  % Heuristic algorithm
            fprintf('Solving... (Exhaustive Search)\n')
            [~,~,~,~,globalMin] = ...
                o_solveSingleNmaxUserInstance(conf,problem,...
                problem.NmaxArray(problem.IDUserAssigned));
            fprintf('Solved!\n')
            figure(h1)
            disp(globalMin)
            line(1:conf.Maxgenerations_Data,ones(1,conf.Maxgenerations_Data)*globalMin);
            drawnow
            
            % And secondly using Genetic Algorithm
            conf.algorithm = 'GA';  % Heuristic algorithm
            fprintf('Solving... (Genetic Algorithm)\n')
            [~,~,~,~,bestScores] = ...
                o_solveSingleNmaxUserInstance(conf,problem,...
                problem.NmaxArray(problem.IDUserAssigned));
            fprintf('Solved!\n')
            figure(h1)
            disp(bestScores)
            line(1:length(bestScores),bestScores);
            drawnow
            %save('temp/exp5-results_so_far','DirOKTot','DirNOKTot','nUsers','nAntennasList');
        end
    end
        
        conf.algorithm = 'GA';  % Heuristic algorithm
end

function [Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd] = experiment5(nIter,nUsers,nAntennasList,plotFLAG)
    % EXPERIMENT 5 -- 
    % 
    % Aim: Evaluate the average received power (Prx) at the intended users
    % and Interference (Int) generated at other users. The secuential
    % allocation policy leads to an unfair allocation policy, which leads
    % to different Prx and Int values. This experiment analyzes how the
    % size of the antenna array and the place in the priority list impact
    % on the performance of the system
    % 
	% Assumptions (Fixed):
    %   1. Number of antennas: Same across users and prop. to Array size.
    %   2. Number of users: nUsers.
    %   3. User location: From config file.
    %   4. Sub-array geometry: 'None'.
    %   5. Antenna Array geometry: Fixed to URA.
    %   6. Algorithm: GA
    % Variable:
    %   1. Antenna Array size variable: nAntennasList
    %   2. Population size: Prop. to nAntennas in Array
    % 
    % Syntax:  [CapTot,SINRTot,DirOKTot,DirOKAv,DirNOKTot,DirNOKAv] =
    % experiment5(nIter,nUsers,nAntennasList,plotFLAG)
    % 
    % Inputs:
    %    nIter - Number of iterations to extract average values
    %    nUsers - Number of users considered
    %    nAntennaList - Number of antenas
    %    plotFLAG - True for plotting directivity and antenna allocation
    %
    % Outputs: (all have dimensions [nUsers x nAntennasList])
    %    Cap - Capacity in b/Hz/s 
    %    SINR_BB - BaseBand SINR in dB
    %    SINR_PB - PassBand SINR in dB
    %    DirOK - Directivity to the intended transmitter in dB
    %    DirNOK_gntd - Directivity generated to other nodes in dB
    %    DirNOK_pcvd - Directivity perceived due to interfeering nodes in
    %                  dB (nUsers x nAntennasList)
    %
    %------------- BEGIN CODE EXPERIMENT 5 --------------
    %
    fprintf('Running experiment 5...\n');
    % Load basic parameters
    problem = o_read_input_problem('data/metaproblem_test.dat');
    conf = o_read_config('data/config_test.dat');
    % Override (problem) parameters
    problem.nUsers = nUsers;  % Number of users in the simulation
    problem.MinObjFIsSNR = true;  % (arbitrary)
    problem.MinObjF = 100.*ones(1,problem.nUsers);  % Same #ant per user. Random SNR (30dB)
    problem.arrayRestriction = 'Localized';  % Possibilities: "None", "Localized", "Interleaved", "DiagInterleaved"
    % Override (conf) parameters
    conf.verbosity = 0;
    conf.algorithm = 'GA';  % Heuristic algorithm
    conf.NumPhaseShifterBits = 60;  % Number of 
    conf.FunctionTolerance_Data = 1e-10;  % Heuristics stops when not improving solution by this much
    conf.multiPath = false;  % LoS channel (for now)
	% Configure basic parameters
    candSet = (1:1:problem.nUsers);  % Set of users to be considered
	% Create output variables
    CapTot = zeros(problem.nUsers,length(nAntennasList),nIter);
    SINRTot = zeros(problem.nUsers,length(nAntennasList),nIter);
    DirOKTot = -Inf(problem.nUsers,length(nAntennasList),nIter);
    DirNOKTot = -Inf(problem.nUsers,problem.nUsers,length(nAntennasList),nIter);
    fileName_temp = strcat('temp/exp5-results_',problem.arrayRestriction,'_',mat2str(nUsers),'_',conf.algorithm,'_so_far');
    fileName = strcat('temp/exp5-results_',problem.arrayRestriction,'_',mat2str(nUsers),'_',conf.algorithm);
    % Linearize combinations and asign Population size (To be replaced with
    % convergency analysis values)
%     totComb = log10(problem.nUsers.*factorial(ceil(nAntennasList/problem.nUsers)));
%     maxPop = 70;  % Maximum population size
%     minPop = 40;  % Minimum population size
%     slope = (maxPop - minPop) / (totComb(end)-totComb(1));
%     ordIdx = minPop - slope*totComb(1);
%     PopSizeList = ceil(slope*totComb + ordIdx);
    PopSizeList = 30*ones(length(nAntennasList),1);
    % Main execution
    for idxAnt = 1:length(nAntennasList)
        conf.PopulationSize_Data = PopSizeList(idxAnt);
        conf.Maxgenerations_Data = 150;
        conf.EliteCount_Data = ceil(conf.PopulationSize_Data/5);
        conf.MaxStallgenerations_Data = ceil(conf.Maxgenerations_Data/10);  % Force it to cover all the generations
        for idxIter = 1:nIter
            fprintf('Iteration %d with PopSize %d\n',idxIter,PopSizeList(idxAnt));
            % Configure the simulation environment. Need to place users in new
            % locations and create new channels to have statistically
            % meaningful results
            [problem,~,~] = f_configuration(conf,problem);
            % Select number of antennas
            problem.N_Antennas = nAntennasList(idxAnt);
            % Adjust parameters
            problem.NxPatch = floor(sqrt(problem.N_Antennas));
            problem.NyPatch = floor(problem.N_Antennas./problem.NxPatch);
            problem.N_Antennas = problem.NxPatch.*problem.NyPatch;
            % Call heuristics
            fprintf('\t** %d Antennas and %d Users...\n',problem.N_Antennas,problem.nUsers);
            [~,W,~,estObj] = f_heuristics(problem,conf,candSet);
            % Heuristics - Post Processing
            if conf.MinObjFIsSNR;     CapTot(:,idxAnt,idxIter)  = log2(estObj+1);  % in bps/Hz
                                      SINRTot(:,idxAnt,idxIter) = pow2db(estObj);  % in dB
            else;                     CapTot(:,idxAnt,idxIter)  = estObj;  % in bps/Hz
                                      SINRTot(:,idxAnt,idxIter) = pow2db(2.^(estTH/problem.Bw) - 1);  % in dB
            end
            % Reconstruct array
            % Create handle per user
            problem1 = o_create_subarray_partition(problem);
            problem1.NzPatch = problem1.NxPatch;
            problem1.dz = problem1.dx;
            problem1.handle_Ant = phased.CosineAntennaElement('FrequencyRange',...
                                    [problem1.freq-(problem1.Bw/2) problem1.freq+(problem1.Bw/2)],...
                                    'CosinePower',[1.5 2.5]); % [1.5 2.5] values set porque s�
            handle_ConformalArray = phased.URA([problem1.NyPatch,problem1.NzPatch],...
                                    'Lattice','Rectangular','Element',problem1.handle_Ant,...
                                    'ElementSpacing',[problem1.dy,problem1.dz]);
            problem1.possible_locations = handle_ConformalArray.getElementPosition;
            for id = 1:1:problem1.nUsers
                problem1.ant_elem = sum(W(id,:)~=0);
                relevant_positions = (W(id,:)~=0);
                Taper_user = W(id,relevant_positions);
                handle_Conf_Array = phased.ConformalArray('Element',problem1.handle_Ant,...
                                      'ElementPosition',...
                                      [zeros(1,problem1.ant_elem);...
                                      problem1.possible_locations(2,relevant_positions);...
                                      problem1.possible_locations(3,relevant_positions)],...
                                      'Taper',Taper_user);
                % Extract Rx Power (in dB)
                DirOKTot(id,idxAnt,idxIter) = patternAzimuth(handle_Conf_Array,problem.freq,problem.thetaUsers(id),'Azimuth',problem.phiUsers(id),'Type','powerdb');
                fprintf('* Directivity IDmax: %.2f (dB)\n',DirOKTot(id,idxAnt,idxIter));
                % Extract interference generated to others (in dB)
                for id1 = 1:1:problem1.nUsers
                    if id1~=id
                        DirNOKTot(id,id1,idxAnt,idxIter) = patternAzimuth(handle_Conf_Array,problem.freq,problem.thetaUsers(id1),'Azimuth',problem.phiUsers(id1),'Type','powerdb');
                        fprintf('  Directivity IDmin(%d): %.2f (dB)\n',id1,DirNOKTot(id,id1,idxAnt,idxIter));
                    end
                end
                problem1.IDUserAssigned = id;
                if plotFLAG
                    % Plot beam pattern obtained with assignation and BF configuration
                    o_plotAssignment_mod(problem1, handle_Conf_Array);
                end
            end
            if plotFLAG
                % Plot assignation
                px = problem1.possible_locations(3,:);  % Antenna allocation on x-axis
                py = problem1.possible_locations(2,:);  % Antenna allocation on y-axis
                pz = problem1.possible_locations(1,:);  % Antenna allocation on z-axispatch = o_getPatch(problem.NxPatch,problem.NyPatch,px,py);
                patch = o_getPatch(problem1.NxPatch,problem1.NyPatch,px,py);
                arrays = o_getArrays(problem1.nUsers,W,px,py,pz);
                o_plot_feasible_comb(problem1,conf,patch,arrays);
            end
            save(fileName_temp,'DirOKTot','DirNOKTot','nUsers','nAntennasList');
        end
    end
    % Convert back to Watts (from dB)
    DirOKTot_lin = db2pow(DirOKTot);
    DirNOKTot_lin = db2pow(DirNOKTot);
    % Compute average Directivities
    DirOK_lin = zeros(nUsers,length(nAntennasList));  % Directivity generated by intended user
    DirNOK_gntd_lin = zeros(nUsers,length(nAntennasList));  % Generated interference by intended user
    DirNOK_pcvd_lin = zeros(nUsers,length(nAntennasList));  % Perceived interference by intended user
    for antIdx = 1:length(nAntennasList)
        DirOK_lin(:,antIdx) = mean(DirOKTot_lin(:,antIdx,:),3);
        DirNOK_gntd_lin(:,antIdx) = sum(mean(DirNOKTot_lin(:,:,antIdx,:),4),2); % Generated interference 
        DirNOK_pcvd_lin(:,antIdx) = sum(mean(DirNOKTot_lin(:,:,antIdx,:),4),1); % Perceived interference
    end
    DirOK = pow2db(DirOK_lin);  % Directivity generated to intended user
    DirNOK_gntd = pow2db(DirNOK_gntd_lin);  % Directivity being generated by intended user
    DirNOK_pcvd = pow2db(DirNOK_pcvd_lin);  % Directivity inflicted to intended user
    % Compute SINR and Capacities
    Ptx_lin = db2pow(problem.Ptx);  % Initial transmit power
    Ptx_lin = repmat(Ptx_lin,1,length(nAntennasList));
    chLoss_lin = (((4*pi*problem.dUsers(1:nUsers)) ./ problem.lambda).^2 ).';  % Losses
    chLoss_lin = repmat(chLoss_lin,1,length(nAntennasList));
    Noise_lin = db2pow(problem.Noise);  % Noise power
    Noise_lin = repmat(Noise_lin,1,length(nAntennasList));
    SINR_PB_lin = (Ptx_lin.*DirOK_lin.*chLoss_lin) ./ (Ptx_lin.*DirNOK_pcvd_lin.*chLoss_lin + Noise_lin);  % SINR
    SINR_PB = pow2db(SINR_PB_lin);
    SINR_BB_lin = mean(db2pow(SINRTot),3);  % Compute SINR Base-Band (BB)
    SINR_BB = pow2db(SINR_BB_lin);
    Cap = mean(CapTot,3);  % Compute Average Capacities in the system
    save(fileName,'Cap','SINR_BB','SINR_PB','DirOK','DirNOK_gntd','DirNOK_pcvd','DirOKTot','DirNOKTot','nUsers','nAntennasList');
end

function experiment5_plot(nUsers,nAntennasList,Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd)
    % EXPERIMENT 5 - Plotting results
    % Get figure number
    h = findobj('type','figure');
    figNum = length(h) + 1;
    % Plot Directivities
    figure(figNum);  figNum = figNum + 1;
    leg = cell(nUsers,1);
    for id = 1:nUsers
        subplot(1,3,1); hold on;
        plot(nAntennasList,DirOK(id,:),'LineWidth',2,'Marker','s');
        subplot(1,3,2); hold on;
        plot(nAntennasList,DirNOK_gntd(id,:),'LineWidth',2,'Marker','s');
        subplot(1,3,3); hold on;
        plot(nAntennasList,DirNOK_pcvd(id,:),'LineWidth',2,'Marker','s');
        leg{id} = cell2mat(strcat('user',{' '},num2str(id)));
    end
    subplot(1,3,1);
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Power in dB','FontSize',12);
    title('Directivity to intended user','FontSize',12);
    legend(leg,'FontSize',12);
    subplot(1,3,2);
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Power in dB','FontSize',12);
    title('Interference generated to other users','FontSize',12);
    legend(leg,'FontSize',12);
    subplot(1,3,3);
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Power in dB','FontSize',12);
    title('Interference generated to intended user','FontSize',12);
    legend(leg,'FontSize',12);
    % Plot perceived SINRs
    figure(figNum);  figNum = figNum + 1;
    for id = 1:nUsers
        subplot(1,2,1); hold on;
        plot(nAntennasList,SINR_BB(id,:),'LineWidth',2,'Marker','s');
        subplot(1,2,2); hold on;
        plot(nAntennasList,SINR_PB(id,:),'LineWidth',2,'Marker','s');
    end
    subplot(1,2,1);
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Power in dB','FontSize',12);
    title('Base-Band (BB) SINR','FontSize',12);
    legend(leg,'FontSize',12);
    subplot(1,2,2);
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Power in dB','FontSize',12);
    title('Pass-Band (PB) SINR','FontSize',12);
    legend(leg,'FontSize',12);
    % Plot perceived Capacities
    figure(figNum);  figNum = figNum + 1;
    for id = 1:nUsers
        hold on;
        plot(nAntennasList,Cap(id,:),'LineWidth',2,'Marker','s');
    end
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Capacity in bits/Hz/s','FontSize',12);
    title('Capacity achieved in the system','FontSize',12);
    legend(leg,'FontSize',12);
    % Plot average Capacities
    figure(figNum);  figNum = figNum + 1;
    Cap_lin = db2pow(Cap);
    Cap_av = pow2db(mean(Cap_lin,1));
	plot(nAntennasList,Cap_av,'LineWidth',2,'Marker','s');
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('Average Capacity in bits/Hz/s','FontSize',12);
    title('Capacity achieved in the system','FontSize',12);
    % Plot average SINR (BB)
    figure(figNum);  figNum = figNum + 1;
    SINR_BB_lin = db2pow(SINR_BB);
    SINR_BB_av = pow2db(mean(SINR_BB_lin,1));
	plot(nAntennasList,SINR_BB_av,'LineWidth',2,'Marker','s');
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('SINR in dB','FontSize',12);
    title('Average BB SINR achieved in the system','FontSize',12);
    % Plot average SINR (PB)
    figure(figNum);  figNum = figNum + 1;                              %#ok
    SINR_PB_lin = db2pow(SINR_PB);
    SINR_PB_av = pow2db(mean(SINR_PB_lin,1));
	plot(nAntennasList,SINR_PB_av,'LineWidth',2,'Marker','s');
    grid minor;
    xlabel('Number of available antennas','FontSize',12);
    ylabel('SINR in dB','FontSize',12);
    title('Average PB SINR achieved in the system','FontSize',12);
end

function [Cap,SINR_BB,SINR_PB,DirOK,DirNOK_gntd,DirNOK_pcvd] = experiment6(nIter,nUsers,nAntennasList,plotFLAG)
    %
    fprintf('Running experiment 6...\n');
    % Load basic parameters
    problem = o_read_input_problem('data/metaproblem_test.dat');
    conf = o_read_config('data/config_test.dat');
    % Override (problem) parameters
    problem.nUsers = nUsers;  % Number of users in the simulation
    problem.MinObjFIsSNR = true;  % (arbitrary)
    problem.MinObjF = 100.*ones(1,problem.nUsers);  % Same #ant per user. Random SNR (30dB)
    problem.arrayRestriction = 'Localized';  % Possibilities: "None", "Localized", "Interleaved", "DiagInterleaved"
    % Override (conf) parameters
    conf.verbosity = 0;
    conf.algorithm = 'GA';  % Heuristic algorithm
    conf.NumPhaseShifterBits = 60;  % Number of 
    conf.FunctionTolerance_Data = 1e-10;  % Heuristics stops when not improving solution by this much
    conf.multiPath = false;  % LoS channel (for now)
	% Configure basic parameters
    candSet = (1:1:problem.nUsers);  % Set of users to be considered
	% Create output variables
    CapTot = zeros(problem.nUsers,length(nAntennasList),nIter);
    SINRTot = zeros(problem.nUsers,length(nAntennasList),nIter);
    DirOKTot = -Inf(problem.nUsers,length(nAntennasList),nIter);
    DirNOKTot = -Inf(problem.nUsers,problem.nUsers,length(nAntennasList),nIter);
    fileName_temp = strcat('temp/exp5-results_',problem.arrayRestriction,'_',mat2str(nUsers),'_',conf.algorithm,'_so_far');
    fileName = strcat('temp/exp5-results_',problem.arrayRestriction,'_',mat2str(nUsers),'_',conf.algorithm);
    % Linearize combinations and asign Population size (To be replaced with
    % convergency analysis values)
%     totComb = log10(problem.nUsers.*factorial(ceil(nAntennasList/problem.nUsers)));
%     maxPop = 70;  % Maximum population size
%     minPop = 40;  % Minimum population size
%     slope = (maxPop - minPop) / (totComb(end)-totComb(1));
%     ordIdx = minPop - slope*totComb(1);
%     PopSizeList = ceil(slope*totComb + ordIdx);
    PopSizeList = 150*ones(length(nAntennasList),1);
    % Main execution
    for idxAnt = 1:length(nAntennasList)
        conf.PopulationSize_Data = PopSizeList(idxAnt);
        conf.Maxgenerations_Data = 150;
        conf.EliteCount_Data = ceil(conf.PopulationSize_Data/5);
        conf.MaxStallgenerations_Data = ceil(conf.Maxgenerations_Data/10);  % Force it to cover all the generations
        for idxIter = 1:nIter
            fprintf('Iteration %d with PopSize %d\n',idxIter,PopSizeList(idxAnt));
            % Configure the simulation environment. Need to place users in new
            % locations and create new channels to have statistically
            % meaningful results
            [problem,~,~] = f_configuration(conf,problem);
            % Select number of antennas
            problem.N_Antennas = nAntennasList(idxAnt);
            % Adjust parameters
            problem.NxPatch = floor(sqrt(problem.N_Antennas));
            problem.NyPatch = floor(problem.N_Antennas./problem.NxPatch);
            problem.N_Antennas = problem.NxPatch.*problem.NyPatch;
            % Call heuristics
            fprintf('\t** %d Antennas and %d Users...\n',problem.N_Antennas,problem.nUsers);
            [~,W,~,estObj] = f_heuristics(problem,conf,candSet);
            % Heuristics - Post Processing
            if conf.MinObjFIsSNR;     CapTot(:,idxAnt,idxIter)  = log2(estObj+1);  % in bps/Hz
                                      SINRTot(:,idxAnt,idxIter) = 10*log10(estObj);  % in dB
            else;                     CapTot(:,idxAnt,idxIter)  = estObj;  % in bps/Hz
                                      SINRTot(:,idxAnt,idxIter) = 10*log10(2.^(estTH/problem.Bw) - 1);  % in dB
            end
            % Reconstruct array
            % Create handle per user
            problem1 = o_create_subarray_partition(problem);
            problem1.NzPatch = problem1.NxPatch;
            problem1.dz = problem1.dx;
            problem1.handle_Ant = phased.CosineAntennaElement('FrequencyRange',...
                                    [problem1.freq-(problem1.Bw/2) problem1.freq+(problem1.Bw/2)],...
                                    'CosinePower',[1.5 2.5]); % [1.5 2.5] values set porque s�
            handle_ConformalArray = phased.URA([problem1.NyPatch,problem1.NzPatch],...
                                    'Lattice','Rectangular','Element',problem1.handle_Ant,...
                                    'ElementSpacing',[problem1.dy,problem1.dz]);
            problem1.possible_locations = handle_ConformalArray.getElementPosition;
            for id = 1:1:problem1.nUsers
                problem1.ant_elem = sum(W(id,:)~=0);
                relevant_positions = (W(id,:)~=0);
                Taper_user = W(id,relevant_positions);
                handle_Conf_Array = phased.ConformalArray('Element',problem1.handle_Ant,...
                                      'ElementPosition',...
                                      [zeros(1,problem1.ant_elem);...
                                      problem1.possible_locations(2,relevant_positions);...
                                      problem1.possible_locations(3,relevant_positions)],...
                                      'Taper',Taper_user);
                % Extract Rx Power (in dB)
                DirOKTot(id,idxAnt,idxIter) = patternAzimuth(handle_Conf_Array,problem.freq,problem.thetaUsers(id),'Azimuth',problem.phiUsers(id),'Type','powerdb');
                fprintf('* Directivity IDmax: %.2f (dB)\n',DirOKTot(id,idxAnt,idxIter));
                % Extract interference generated to others (in dB)
                for id1 = 1:1:problem1.nUsers
                    if id1~=id
                        DirNOKTot(id,id1,idxAnt,idxIter) = patternAzimuth(handle_Conf_Array,problem.freq,problem.thetaUsers(id1),'Azimuth',problem.phiUsers(id1),'Type','powerdb');
                        fprintf('  Directivity IDmin(%d): %.2f (dB)\n',id1,DirNOKTot(id,id1,idxAnt,idxIter));
                    end
                end
                % Compare performance with other Beamforming mechanisms
                % Simulate a test signal using a simple rectangular pulse
                t = linspace(0,0.3,300)';
                testsig = zeros(size(t));
                testsig(201:205) = 1;
                % Incident signal
                angle_of_arrival = [problem.phiUsers(1);problem.thetaUsers(1)];
                x = collectPlaneWave(handle_ConformalArray,testsig,angle_of_arrival,problem.freq);
                % Add AWGN to signal
                rng default
                npower = 0.5;
                x = x + sqrt(npower/2)*(randn(size(x)) + 1i*randn(size(x)));
                % Create interference
                jammer_angle = [problem.phiUsers(2);problem.thetaUsers(2)];
                jamsig = collectPlaneWave(handle_ConformalArray,x,jammer_angle,problem.freq);
                % Add AWGN to jamming signal
                noise = sqrt(noisePwr/2)*...
                    (randn(size(jamsig)) + 1j*randn(size(jamsig)));
                jamsig = jamsig + noise;
                rxsig = x + jamsig;
                % Create conventional Beamformer
                convbeamformer = phased.PhaseShiftBeamformer('SensorArray',handle_Conf_Array,...
                                'OperatingFrequency',problem.freq,'Direction',angle_of_arrival,...
                                'WeightsOutputPort',true);
                [~,W_convent] = convbeamformer(rxsig);
                % Create LCMV Beamformer
                steeringvector = phased.SteeringVector('SensorArray',handle_Conf_Array,...
                                 'PropagationSpeed',physconst('LightSpeed'));
                LCMVbeamformer = phased.LCMVBeamformer('DesiredResponse',1,...
                                 'TrainingInputPort',true,'WeightsOutputPort',true);
                LCMVbeamformer.Constraint = steeringvector(problem.freq,angle_of_arrival);
                LCMVbeamformer.DesiredResponse = 1;
                [~,wLCMV] = LCMVbeamformer(rxsig,jamsig);
                problem1.IDUserAssigned = id;
                if plotFLAG
                    % Plot beam pattern obtained with assignation and BF configuration
                    o_plotAssignment_mod(problem1, handle_Conf_Array);
                    % Plot beam pattern obtained with LCMV Beamforming
                    figure;
                    subplot(211)
                    pattern(handle_Conf_Array,problem.freq,(-180:180),0,'PropagationSpeed',physconst('LightSpeed'),...
                                'CoordinateSystem','rectangular','Type','powerdb','Normalize',true,...
                                'Weights',W_convent)
                    title('Array Response with Conventional Beamforming Weights');
                    subplot(212)
                    pattern(handle_Conf_Array,problem.freq,(-180:180),0,'PropagationSpeed',physconst('LightSpeed'),...)
                                'CoordinateSystem','rectangular','Type','powerdb','Normalize',true,...
                                'Weights',wLCMV)
                    title('Array Response with LCMV Beamforming Weights');
                end
            end
            if plotFLAG
                % Plot assignation
                px = problem1.possible_locations(3,:);  % Antenna allocation on x-axis
                py = problem1.possible_locations(2,:);  % Antenna allocation on y-axis
                pz = problem1.possible_locations(1,:);  % Antenna allocation on z-axispatch = o_getPatch(problem.NxPatch,problem.NyPatch,px,py);
                patch = o_getPatch(problem1.NxPatch,problem1.NyPatch,px,py);
                arrays = o_getArrays(problem1.nUsers,W,px,py,pz);
                o_plot_feasible_comb(problem1,conf,patch,arrays);
            end
            save(fileName_temp,'DirOKTot','DirNOKTot','nUsers','nAntennasList');
        end
    end
    % Convert back to Watts (from dB)
    DirOKTot_lin = db2pow(DirOKTot);
    DirNOKTot_lin = db2pow(DirNOKTot);
    % Compute average Directivities
    DirOK_lin = zeros(nUsers,length(nAntennasList));  % Directivity generated by intended user
    DirNOK_gntd_lin = zeros(nUsers,length(nAntennasList));  % Generated interference by intended user
    DirNOK_pcvd_lin = zeros(nUsers,length(nAntennasList));  % Perceived interference by intended user
    for antIdx = 1:length(nAntennasList)
        DirOK_lin(:,antIdx) = mean(DirOKTot_lin(:,antIdx,:),3);
        DirNOK_gntd_lin(:,antIdx) = sum(mean(DirNOKTot_lin(:,:,antIdx,:),4),1); % Generated interference 
        DirNOK_pcvd_lin(:,antIdx) = sum(mean(DirNOKTot_lin(:,:,antIdx,:),4),2); % Perceived interference
    end
    DirOK = pow2db(DirOK_lin);  % Directivity generated to intended user
    DirNOK_gntd = pow2db(DirNOK_gntd_lin);  % Directivity being generated by intended user
    DirNOK_pcvd = pow2db(DirNOK_pcvd_lin);  % Directivity inflicted to intended user
    % Compute SINR and Capacities
    chLoss = pow2db( ((4*pi*problem.dUsers(1:nUsers)) ./ problem.lambda).^2 ).';  % Losses
    chLoss = repmat(chLoss,1,length(nAntennasList));
%     Ptx = repmat(problem.Ptx,1,length(nAntennasList));  % Initial transmit power
    Noise_lin = repmat(db2pow(problem.Noise),1,length(nAntennasList));  % Noise power
%     SINR = Ptx + DirOK - DirNOK_pcvd - chLoss - problem.Noise;  % Compute SINR Pass-Band (PB)
    SINR_PB = (DirOK_lin*db2pow(chLoss)) ./(DirNOK_gntd_lin*db2pow(chLoss) + Noise_lin);
    SINR_BB = mean(SINRTot,3);  % Compute SINR Base-Band (BB)
    Cap = mean(CapTot,3);  % Compute Average Capacities in the system
    save(fileName,'Cap','SINR_BB','SINR_PB','DirOK','DirNOK_gntd','DirNOK_pcvd','DirOKTot','DirNOKTot','nUsers','nAntennasList');
end