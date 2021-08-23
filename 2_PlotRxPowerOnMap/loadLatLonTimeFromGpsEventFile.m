function [lat, lon, timestamp] ...
    = loadLatLonTimeFromGpsEventFile(absDirToGpsEventJson)
% LOADLATLONFROMGPSEVENTFILE Load (latitude, longitude) and the time stamp
% from the .json GPS event file published by the Odin system.
%
% Yaguang Zhang, Purdue, 08/21/2021

jsonMsg = fileread(absDirToGpsEventJson);
data = jsondecode(jsonMsg);
lat = data.latitude.component;
lon = data.longitude.component;
timestamp = data.timestamp;

end
% EOF