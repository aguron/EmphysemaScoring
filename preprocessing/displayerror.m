function displayerror(err, varargin)
%
% displayerror(err, ...)  
%
% Display error message
%
% INPUTS:
%
% err         - error message
%
% OPTIONAL ARGUMENTS:
%
% verbose     - if true, the error stack is display in addition to the
%               error message (default: false)
%
% @ 2016 Akinyinka Omigbodun    aomigbod@ucsd.edu

  verbose	= false;
  
  assignopts(who, varargin);

  disp(err)
  if (verbose)
    for st=1:numel(err.stack)
      disp(err.stack(st))
      disp(' ');
    end % for st=1:numel(err.stack)
  end % if (verbose)
end