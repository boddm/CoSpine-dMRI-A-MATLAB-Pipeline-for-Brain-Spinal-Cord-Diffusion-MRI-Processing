function [status, result] = executeCmd(cmdline, description)
% Purpose: Execute system command and return execution result
% Inputs:
%   cmdline: Command string to be executed
%   description: Description of the command
% Outputs:
%   status: Command execution status code
%   result: Command execution result
% Example:
%   [status, result] = executeCmd('ls -la', 'List directory contents');
% History:
%   2025-07-01, boddm, Initial version

%% Execute system command
[status, result] = system(cmdline);  % Call system function to execute command

%% Check command execution status
if status ~= 0
    error('      Command execution failed: %s\n%s', description, result);
else
    fprintf('      Command executed successfully: %s\n', description);
end
end