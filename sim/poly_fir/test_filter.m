% Script to validate filter

% First discover the location of the filter and results
here = fileparts(mfilename('fullpath'));
[status, simdir] = system(sprintf('make -s -C %s print-simdir', here));
assert(status == 0, 'Unexpected error calling make');
simdir = [simdir '/'];

% Load the stimulus, filter, and result from the simulation directory
filter = load([simdir 'filter-taps.txt']);
stimulus = load([simdir 'stimulus.txt']);
result = load([simdir 'result.txt']);

% Compute the raw expected results
clear expected;
for n = 1:size(stimulus, 2)
    expected(:, n) = conv(filter, stimulus(:, n));
end

% Now scaling factors and comparisons.
scaling = 2^-13;
expected = scaling * expected(3:4:end, :);
% Some fudging here of the test range
errors = expected(2:end, :) - result(2:end-1, :);
% We expect maximum error of half a bit at this point
assert(all(errors <= 0.5, 'all'));
